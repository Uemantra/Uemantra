extends PanelContainer

signal dismissed

var _results_list: VBoxContainer
var _dismiss_btn: Button


func _ready() -> void:
	_results_list = $VBox/ResultsScroll/ResultsList
	_dismiss_btn = $VBox/DismissBtn
	# DismissBtn.pressed is connected in the scene file.
	_populate()


func _populate() -> void:
	var raw: Variant = GameState.get_flag("rig_overnight_results", "")
	if not (raw is String) or raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		return
	for item in parsed:
		var cache_id: String = item.get("cache_id", "")
		var results: Array = item.get("results", [])
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)

		var header := Label.new()
		header.text = cache_id
		header.add_theme_font_size_override("font_size", 15)
		block.add_child(header)

		for r in results:
			if r.has("vera_note"):
				var note_lbl := Label.new()
				note_lbl.text = r.get("vera_note", "")
				note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				block.add_child(note_lbl)

		var sep := HSeparator.new()
		_results_list.add_child(block)
		_results_list.add_child(sep)


func _on_dismiss() -> void:
	# Clear the results flag so this panel doesn't show again on next entry.
	GameState.set_flag("rig_overnight_results", "")
	dismissed.emit()
	queue_free()
