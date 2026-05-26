extends Control

const Typewriter = preload("res://scripts/workshop/typewriter.gd")

# Tool IDs in display order.
const TOOL_ORDER: Array[String] = ["glean", "lattice", "echo"]

var _selected_cache_id: String = ""
var _selected_tool_id: String = ""
var _active_typewriter: Typewriter = null
var _current_results: Array = []
var _awaiting_decision: bool = false
# Stores the first tool's output when cross-referencing so both can be shown.
var _cross_ref_primary_tool: String = ""

# UI node references — populated in _ready.
var _cache_list: VBoxContainer
var _terminal_output: RichTextLabel
var _tool_buttons: Dictionary = {}
var _process_now_btn: Button
var _queue_btn: Button
var _queue_list: VBoxContainer
var _accept_btn: Button
var _verify_btn: Button
var _cross_ref_btn: Button
var _inconclusive_btn: Button
var _decision_row: HBoxContainer
var _status_label: Label


func _ready() -> void:
	_bind_nodes()
	_connect_signals()
	_refresh_cache_list()
	_refresh_queue_list()
	_refresh_tool_buttons()
	_hide_decision_buttons()


func _bind_nodes() -> void:
	_cache_list = $HBox/LeftPanel/CacheScroll/CacheList
	_terminal_output = $HBox/CenterPanel/Terminal/Output
	_tool_buttons["glean"] = $HBox/RightPanel/ToolButtons/GleanBtn
	_tool_buttons["lattice"] = $HBox/RightPanel/ToolButtons/LatticeBtn
	_tool_buttons["echo"] = $HBox/RightPanel/ToolButtons/EchoBtn
	_process_now_btn = $HBox/RightPanel/ActionButtons/ProcessNowBtn
	_queue_btn = $HBox/RightPanel/ActionButtons/QueueBtn
	_queue_list = $HBox/RightPanel/QueueSection/QueueList
	_accept_btn = $Bottom/DecisionRow/AcceptBtn
	_verify_btn = $Bottom/DecisionRow/VerifyBtn
	_cross_ref_btn = $Bottom/DecisionRow/CrossRefBtn
	_inconclusive_btn = $Bottom/DecisionRow/InconclusiveBtn
	_decision_row = $Bottom/DecisionRow
	_status_label = $Bottom/StatusLabel


func _connect_signals() -> void:
	# Button signals are wired in the scene file via [connection] sections.
	CatalogueManager.cache_processing_complete.connect(_on_processing_complete)
	GameState.state_changed.connect(_on_state_changed)


# --- Cache list ---

func _refresh_cache_list() -> void:
	for child in _cache_list.get_children():
		child.queue_free()
	for cache_id in GameState.inventory.get("caches", []):
		if CatalogueManager.is_processed(cache_id):
			continue
		var cache_data := DataManager.get_cache(cache_id)
		var btn := Button.new()
		var label: String = cache_data.get("media_type", cache_id)
		btn.text = "[%s]  %s" % [cache_id, label]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_cache_selected.bind(cache_id))
		_cache_list.add_child(btn)


func _on_cache_selected(cache_id: String) -> void:
	_selected_cache_id = cache_id
	_selected_tool_id = ""
	_refresh_tool_buttons()
	_clear_terminal()
	var cache_data := DataManager.get_cache(cache_id)
	var note: String = cache_data.get("vera_field_note", "")
	_set_status(note)
	_update_action_buttons()


# --- Tool buttons ---

func _refresh_tool_buttons() -> void:
	var tier: int = GameState.tool_infrastructure_tier
	for tool_id in TOOL_ORDER:
		var btn: Button = _tool_buttons[tool_id]
		var tool_data := DataManager.get_tool(tool_id)
		var min_tier: int = tool_data.get("available_from_infrastructure_tier", 1)
		btn.disabled = tier < min_tier
		btn.button_pressed = (tool_id == _selected_tool_id)


func _on_tool_selected(tool_id: String) -> void:
	_selected_tool_id = tool_id
	for t_id in _tool_buttons:
		_tool_buttons[t_id].button_pressed = (t_id == tool_id)
	_update_action_buttons()


func _update_action_buttons() -> void:
	var has_cache := not _selected_cache_id.is_empty()
	var has_tool := not _selected_tool_id.is_empty()
	_process_now_btn.disabled = not (has_cache and has_tool)
	_queue_btn.disabled = not (has_cache and has_tool)


# --- Processing ---

func _on_process_now() -> void:
	if _selected_cache_id.is_empty() or _selected_tool_id.is_empty():
		return
	if _active_typewriter != null:
		return
	_hide_decision_buttons()
	_cross_ref_primary_tool = ""
	_begin_typewriter_output(_selected_cache_id, _selected_tool_id)
	CatalogueManager.process_cache_now(_selected_cache_id, _selected_tool_id)


func _begin_typewriter_output(cache_id: String, tool_id: String) -> void:
	var output_text := _build_output_text(cache_id, tool_id)
	_clear_terminal()
	_active_typewriter = Typewriter.new(_terminal_output, output_text, 2)
	_active_typewriter.complete.connect(_on_typewriter_complete.bind(cache_id))
	_active_typewriter.start()
	_process_now_btn.disabled = true
	_queue_btn.disabled = true


func _build_output_text(cache_id: String, tool_id: String) -> String:
	var tool_data := DataManager.get_tool(tool_id)
	var tool_name: String = tool_data.get("name", tool_id.to_upper())
	var tool_type: String = tool_data.get("type", "").replace("_", " ").to_upper()
	var cache_data := DataManager.get_cache(cache_id)
	var echo_data := DataManager.get_echo(cache_id)
	var source := cache_data if not cache_data.is_empty() else echo_data

	var lines: PackedStringArray = []
	lines.append("%s — %s" % [tool_name.to_upper(), tool_type])
	lines.append("—".repeat(40))
	lines.append("Media:      %s" % source.get("media_type", "unknown"))
	lines.append("Condition:  %s" % source.get("media_condition", "unknown"))
	lines.append("")

	var tool_outputs: Dictionary = source.get("tool_outputs", {})
	if tool_id in tool_outputs:
		var tool_out: Dictionary = tool_outputs[tool_id]
		var output_text: String = tool_out.get("confident_output", tool_out.get("interpretation", ""))
		lines.append(output_text)
		var confidence: float = tool_out.get("confidence", -1.0)
		if confidence >= 0.0:
			lines.append("")
			lines.append("Confidence: %.2f" % confidence)
	else:
		lines.append("[No output available for this tool on this media.]")

	lines.append("")
	lines.append("— end of output —")
	return "\n".join(lines)


func _on_typewriter_complete(cache_id: String) -> void:
	_active_typewriter = null
	_awaiting_decision = true
	_show_decision_buttons(cache_id)
	_update_action_buttons()


# --- Decision buttons ---

func _show_decision_buttons(cache_id: String) -> void:
	_decision_row.visible = true
	_cross_ref_btn.disabled = GameState.tool_infrastructure_tier < 3
	# Store the cache being decided on in a consistent way.
	_set_status("Output complete. Interpret:")


func _hide_decision_buttons() -> void:
	_decision_row.visible = false
	_awaiting_decision = false


func _on_accept() -> void:
	if _selected_cache_id.is_empty():
		return
	var cache_data := DataManager.get_cache(_selected_cache_id)
	var yields: Array = cache_data.get("yields", [])
	if not yields.is_empty():
		var entry_id: String = yields[0].get("entry_id", "")
		if not entry_id.is_empty():
			CatalogueManager.accept_interpretation(_selected_cache_id, entry_id)
	else:
		# Echo — accept directly.
		CatalogueManager.accept_interpretation(_selected_cache_id, _selected_cache_id)
	_hide_decision_buttons()
	_append_terminal_line("\n— Logged to Catalogue. —")
	_set_status("Entry recorded.")
	_refresh_cache_list()


func _on_verify() -> void:
	if _selected_cache_id.is_empty() or _selected_tool_id.is_empty():
		return
	var result := CatalogueManager.verify_interpretation(_selected_cache_id, _selected_tool_id)
	if result.is_empty():
		return
	var lines: PackedStringArray = []
	lines.append("")
	lines.append("— MANUAL VERIFICATION —")
	lines.append(result.get("actual_output", ""))
	if result.get("is_wrong", false):
		lines.append("")
		lines.append("Note: output differed from field record.")
		var vr: String = result.get("verification_result", "")
		if not vr.is_empty():
			lines.append(vr)
	_append_terminal_line("\n".join(lines))
	_hide_decision_buttons()
	_set_status("Verified. Partial weight applied.")
	_refresh_cache_list()


func _on_cross_reference() -> void:
	if _selected_cache_id.is_empty() or _selected_tool_id.is_empty():
		return
	# Pick a second tool that isn't the currently selected one and is available.
	var second_tool := _pick_cross_ref_tool()
	if second_tool.is_empty():
		_set_status("No second tool available for cross-reference.")
		return
	var result := CatalogueManager.cross_reference(_selected_cache_id, second_tool)
	if result.get("available", false):
		var second_tool_data := DataManager.get_tool(second_tool)
		var second_name: String = second_tool_data.get("name", second_tool.to_upper())
		var lines: PackedStringArray = []
		lines.append("")
		lines.append("— CROSS-REFERENCE: %s —" % second_name.to_upper())
		lines.append(result.get("output", ""))
		var conf: float = result.get("confidence", -1.0)
		if conf >= 0.0:
			lines.append("Confidence: %.2f" % conf)
		_append_terminal_line("\n".join(lines))
		_set_status("Cross-reference complete. Two readings on record.")
	else:
		_set_status("Second tool has no output for this media.")


func _on_mark_inconclusive() -> void:
	if _selected_cache_id.is_empty():
		return
	CatalogueManager.mark_inconclusive(_selected_cache_id, _selected_cache_id)
	_hide_decision_buttons()
	_append_terminal_line("\n— Marked inconclusive. No weight assigned. —")
	_set_status("Unresolved.")
	_refresh_cache_list()


func _pick_cross_ref_tool() -> String:
	var tier: int = GameState.tool_infrastructure_tier
	for tool_id in TOOL_ORDER:
		if tool_id == _selected_tool_id:
			continue
		var tool_data := DataManager.get_tool(tool_id)
		var min_tier: int = tool_data.get("available_from_infrastructure_tier", 1)
		if tier >= min_tier:
			return tool_id
	return ""


# --- Queue ---

func _on_queue() -> void:
	if _selected_cache_id.is_empty() or _selected_tool_id.is_empty():
		return
	CatalogueManager.queue_cache(_selected_cache_id, _selected_tool_id)
	_set_status("Added to overnight queue.")
	_refresh_queue_list()


func _refresh_queue_list() -> void:
	for child in _queue_list.get_children():
		child.queue_free()
	var queue := CatalogueManager.get_queue()
	if queue.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_queue_list.add_child(empty_label)
		return
	for item in queue:
		var cache_id: String = item.get("cache_id", "")
		var tool_id: String = item.get("tool_id", "")
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s  ←  %s" % [cache_id, tool_id.to_upper()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var remove_btn := Button.new()
		remove_btn.text = "✕"
		remove_btn.pressed.connect(_on_dequeue.bind(cache_id, tool_id))
		row.add_child(remove_btn)
		_queue_list.add_child(row)


func _on_dequeue(cache_id: String, tool_id: String) -> void:
	CatalogueManager.dequeue_cache(cache_id, tool_id)
	_refresh_queue_list()


# --- Overnight results callback ---

func _on_processing_complete(_cache_id: String, _results: Array) -> void:
	_refresh_cache_list()
	_refresh_queue_list()


# --- Terminal helpers ---

func _clear_terminal() -> void:
	_terminal_output.text = ""


func _append_terminal_line(line: String) -> void:
	_terminal_output.text += line


func _set_status(text: String) -> void:
	_status_label.text = text


func _on_state_changed() -> void:
	_refresh_tool_buttons()


# --- Tool button connections (wired through scene) ---

func _on_glean_btn_pressed() -> void:
	_on_tool_selected("glean")


func _on_lattice_btn_pressed() -> void:
	_on_tool_selected("lattice")


func _on_echo_btn_pressed() -> void:
	_on_tool_selected("echo")
