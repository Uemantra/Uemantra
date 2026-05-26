extends Control

@onready var entry_name_label: Label = $ScrollContainer/VBox/EntryName
@onready var state_badge: Label = $ScrollContainer/VBox/StateBadge
@onready var meta_label: Label = $ScrollContainer/VBox/MetaLine
@onready var main_text: RichTextLabel = $ScrollContainer/VBox/MainText
@onready var vera_note_label: RichTextLabel = $ScrollContainer/VBox/VeraNote
@onready var annotations_container: VBoxContainer = $ScrollContainer/VBox/Annotations
@onready var back_button: Button = $BackButton

var _back_callback: Callable = Callable()


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func set_back_callback(callback: Callable) -> void:
	_back_callback = callback


func load_entry(entry_id: String) -> void:
	_clear_annotations()

	var entry_state_data: Dictionary = GameState.catalogue_entries.get(entry_id, {})
	var state: String = entry_state_data.get("state", "sparse")
	var annotations: Array = entry_state_data.get("annotations", [])

	# Companion entries are handled separately.
	if entry_id in GameState.companions:
		_load_companion_entry(entry_id, state)
		return

	# Try relic authored data.
	var relic_data := DataManager.get_relic(entry_id)
	if not relic_data.is_empty():
		_load_relic_entry(relic_data, state, annotations)
		return

	# Try cache-derived entry.
	var yield_data := _find_cache_yield(entry_id)
	if not yield_data.is_empty():
		var section_tag: String = yield_data.get("catalogue_section", "")
		if section_tag == "people_we_never_knew":
			_load_people_never_know_entry(entry_id, yield_data, state, annotations)
		elif section_tag == "what_the_machines_said":
			_load_machines_said_entry(entry_id, yield_data, state, annotations)
		else:
			_load_fragment_entry(entry_id, yield_data, state, annotations)
		return

	# Fallback: minimal display for an entry with no authored data.
	entry_name_label.text = entry_id
	state_badge.text = _state_label(state)
	meta_label.text = ""
	main_text.text = ""
	vera_note_label.text = ""


func _load_relic_entry(relic_data: Dictionary, state: String, annotations: Array) -> void:
	entry_name_label.text = relic_data.get("name", "—")
	state_badge.text = _state_label(state)
	meta_label.text = "%s — %s" % [
		relic_data.get("zone", "").capitalize(),
		relic_data.get("media_condition", "").capitalize(),
	]
	main_text.bbcode_enabled = true
	main_text.text = ""
	vera_note_label.bbcode_enabled = true
	vera_note_label.text = "[i]%s[/i]" % relic_data.get("vera_note", "")
	_populate_annotations(annotations)


func _load_fragment_entry(entry_id: String, yield_data: Dictionary, state: String, annotations: Array) -> void:
	entry_name_label.text = yield_data.get("entry_id", entry_id)
	state_badge.text = _state_label(state)
	meta_label.text = "Recovered fragment"
	main_text.bbcode_enabled = true
	var content: String = yield_data.get("content", "")
	# Mark ambiguous content plainly, no icon.
	if yield_data.get("ambiguous", false):
		content += "\n\n[Vera has marked this entry: uncertain]"
	main_text.text = content
	vera_note_label.bbcode_enabled = true
	vera_note_label.text = "[i]%s[/i]" % yield_data.get("vera_note", "")
	_populate_annotations(annotations)


func _load_people_never_know_entry(entry_id: String, yield_data: Dictionary, state: String, annotations: Array) -> void:
	var identifier: String = yield_data.get("person_identifier", yield_data.get("entry_id", entry_id))
	entry_name_label.text = identifier
	state_badge.text = _state_label(state)
	meta_label.text = "Someone who left things behind"
	main_text.bbcode_enabled = true
	var content: String = yield_data.get("content", "")
	if yield_data.get("ambiguous", false):
		content += "\n\n[Vera has marked this entry: uncertain]"
	main_text.text = content
	vera_note_label.bbcode_enabled = true
	vera_note_label.text = "[i]%s[/i]" % yield_data.get("vera_note", "")
	# Cross-reference note if present.
	if yield_data.get("cross_referenced", false):
		var xref_note := Label.new()
		xref_note.text = "Cross-referenced with other entries."
		xref_note.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		annotations_container.add_child(xref_note)
	_populate_annotations(annotations)


func _load_machines_said_entry(entry_id: String, yield_data: Dictionary, state: String, annotations: Array) -> void:
	entry_name_label.text = yield_data.get("entry_id", entry_id)
	state_badge.text = _state_label(state)
	meta_label.text = "Machine output"
	main_text.bbcode_enabled = true
	var content: String = yield_data.get("content", "")
	if yield_data.get("ambiguous", false):
		content += "\n\n[Vera has marked this entry: uncertain]"
	main_text.text = content
	vera_note_label.bbcode_enabled = true
	# Curation note is prominent for this section.
	vera_note_label.text = "[i]%s[/i]" % yield_data.get("vera_note", "")
	_populate_annotations(annotations)


func _load_companion_entry(companion_id: String, _state: String) -> void:
	var companion_data := DataManager.get_companion(companion_id)
	var gs_data: Dictionary = GameState.companions.get(companion_id, {})
	var relationship: int = gs_data.get("relationship", 0)
	var arcs_completed: Array = gs_data.get("arcs_completed", [])

	entry_name_label.text = companion_data.get("name", companion_id)
	# State badge is replaced by a relationship prose phrase — no number.
	state_badge.text = _relationship_prose(relationship)
	meta_label.text = companion_data.get("role", "")
	main_text.bbcode_enabled = false
	main_text.text = _build_companion_body(companion_id, companion_data, arcs_completed)
	vera_note_label.text = ""
	_clear_annotations()


func _relationship_prose(relationship: int) -> String:
	if relationship <= 20:
		return "Someone Vera has met"
	elif relationship <= 50:
		return "Someone Vera is learning to know"
	elif relationship <= 80:
		return "Someone Vera trusts, in their own way"
	else:
		return "Someone Vera would call a friend, if the word still fit"


func _build_companion_body(companion_id: String, companion_data: Dictionary, arcs_completed: Array) -> String:
	# Each companion has a seed line that grows as arcs complete.
	var base_lines: Dictionary = {
		"maren":  "Maren Holst. Village elder. She knows things nobody else remembers.",
		"eli":    "Eli Sato. He fixes what others can't.",
		"sable":  "Sable. Gardener. They keep the community plot.",
		"wren":   "Wren Ashby. She leads the council. She is practical about what that costs her.",
		"doss":   "Doss Okafor. Teacher. He is writing something by hand.",
		"petra":  "Petra Vance. Doctor. Self-taught, which she will tell you plainly.",
		"corvus": "Corvus. He records sound. He is careful about what he performs.",
	}
	var body: String = base_lines.get(companion_id, companion_data.get("name", companion_id) + ".")
	# Arc completions append additional prose, not stats.
	for arc_id in arcs_completed:
		var arc_line: String = _arc_prose(companion_id, arc_id)
		if arc_line != "":
			body += "\n\n" + arc_line
	return body


func _arc_prose(companion_id: String, arc_id: String) -> String:
	# Arc prose lines are keyed by companion_id:arc_id.
	# New arcs add entries here as they are written.
	var key: String = companion_id + ":" + arc_id
	var arc_lines: Dictionary = {
		"maren:memory_record_01": "Vera has begun transcribing what Maren remembers. Some of it is already gone.",
		"eli:ren_search_01":      "Eli's sister Ren left five years ago. He hasn't said where she went.",
		"sable:question_01":      "Sable asked Vera something she hasn't written down yet.",
		"wren:resistance_break":  "Wren changed her mind about one specific thing. She hasn't changed it back.",
		"doss:book_added":        "Doss finished his book. It is in the Catalogue now. The newest thing here, and the only one made without machines.",
		"corvus:performance_ok":  "Corvus will perform the piece. He asked Vera to tell him exactly what the model did. She did.",
	}
	return arc_lines.get(key, "")


func _populate_annotations(annotations: Array) -> void:
	for annotation in annotations:
		var ann_label := Label.new()
		ann_label.text = "— " + str(annotation)
		ann_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ann_label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35))
		annotations_container.add_child(ann_label)


func _state_label(state: String) -> String:
	match state:
		"sparse":    return "Sparse"
		"annotated": return "Annotated"
		"complete":  return "Complete"
	return ""


func _find_cache_yield(entry_id: String) -> Dictionary:
	for cache_id in DataManager.caches:
		var cache_data: Dictionary = DataManager.get_cache(cache_id)
		for yield_item in cache_data.get("yields", []):
			if yield_item.get("entry_id", "") == entry_id:
				return yield_item
	return {}


func _clear_annotations() -> void:
	for child in annotations_container.get_children():
		child.queue_free()


func _on_back_pressed() -> void:
	if _back_callback.is_valid():
		_back_callback.call()
