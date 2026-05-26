extends Control

@onready var entry_list: VBoxContainer = $ScrollContainer/EntryList

var _catalogue: Control = null


func _ready() -> void:
	refresh()


func set_catalogue(catalogue: Control) -> void:
	_catalogue = catalogue


func refresh() -> void:
	_clear_list()
	var entry_ids := _collect_entry_ids()
	if entry_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Vera has not yet curated anything here."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		entry_list.add_child(empty_label)
		return
	for entry_id in entry_ids:
		_add_entry_row(entry_id)


func _collect_entry_ids() -> Array:
	var ids: Array = []
	for entry_id in GameState.catalogue_entries:
		var yield_data := _find_cache_yield(entry_id)
		if yield_data.get("catalogue_section", "") == "what_the_machines_said":
			ids.append(entry_id)
	return ids


func _add_entry_row(entry_id: String) -> void:
	var yield_data := _find_cache_yield(entry_id)
	var state_data: Dictionary = GameState.catalogue_entries.get(entry_id, {})
	var state: String = state_data.get("state", "sparse")

	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var display_name: String = yield_data.get("entry_id", entry_id)
	var vera_note: String = yield_data.get("vera_note", "")
	var curation_line: String = vera_note.split("\n")[0] if vera_note != "" else ""
	if curation_line.length() > 80:
		curation_line = curation_line.substr(0, 77) + "..."

	if state == "sparse":
		btn.text = display_name + " (sparse)"
		btn.modulate = Color(0.6, 0.55, 0.5, 1.0)
	else:
		btn.text = display_name
		# Vera's curation note is prominent — shown in the list instead of content.
		if curation_line != "":
			btn.text += "\n" + curation_line
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

	btn.pressed.connect(_on_entry_selected.bind(entry_id))
	entry_list.add_child(btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.75, 0.7, 0.6, 0.5))
	entry_list.add_child(sep)


func _on_entry_selected(entry_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(entry_id)


func _find_cache_yield(entry_id: String) -> Dictionary:
	for cache_id in DataManager.caches:
		var cache_data: Dictionary = DataManager.get_cache(cache_id)
		for yield_item in cache_data.get("yields", []):
			if yield_item.get("entry_id", "") == entry_id:
				return yield_item
	return {}


func _clear_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()


func select_entry(entry_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(entry_id)
