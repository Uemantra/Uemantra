extends Control

@onready var entry_list: VBoxContainer = $ScrollContainer/EntryList

var _catalogue: Control = null


func _ready() -> void:
	refresh()


func set_catalogue(catalogue: Control) -> void:
	_catalogue = catalogue


func refresh() -> void:
	_clear_list()
	var relic_ids := _collect_relic_entry_ids()
	if relic_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nothing documented yet."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		entry_list.add_child(empty_label)
		return
	for entry_id in relic_ids:
		_add_entry_row(entry_id)


func _collect_relic_entry_ids() -> Array:
	var ids: Array = []
	for entry_id in GameState.catalogue_entries:
		var authored := DataManager.get_relic(entry_id)
		if not authored.is_empty() and authored.get("catalogue_section", "") == "relics":
			ids.append(entry_id)
	return ids


func _add_entry_row(entry_id: String) -> void:
	var relic_data := DataManager.get_relic(entry_id)
	var state_data: Dictionary = GameState.catalogue_entries.get(entry_id, {})
	var state: String = state_data.get("state", "sparse")

	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var display_name: String = relic_data.get("name", entry_id)
	var vera_note: String = relic_data.get("vera_note", "")
	var first_line: String = vera_note.split("\n")[0] if vera_note != "" else ""

	if state == "sparse":
		# Faded text and a plain tag — no progress indicator.
		btn.text = display_name + " (sparse)"
		btn.modulate = Color(0.6, 0.55, 0.5, 1.0)
	else:
		btn.text = display_name
		if first_line != "":
			btn.text += "\n" + first_line
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

	btn.pressed.connect(_on_entry_selected.bind(entry_id))
	entry_list.add_child(btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.75, 0.7, 0.6, 0.5))
	entry_list.add_child(sep)


func _on_entry_selected(entry_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(entry_id)


func _clear_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()


func select_entry(entry_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(entry_id)
