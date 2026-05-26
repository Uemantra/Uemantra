extends Control

@onready var entry_list: VBoxContainer = $ScrollContainer/EntryList

var _catalogue: Control = null

const COMPANION_ORDER: Array[String] = [
	"maren", "eli", "sable", "wren", "doss", "petra", "corvus"
]


func _ready() -> void:
	refresh()


func set_catalogue(catalogue: Control) -> void:
	_catalogue = catalogue


func refresh() -> void:
	_clear_list()
	for companion_id in COMPANION_ORDER:
		_add_companion_row(companion_id)


func _add_companion_row(companion_id: String) -> void:
	var companion_data := DataManager.get_companion(companion_id)
	if companion_data.is_empty():
		return
	var gs_data: Dictionary = GameState.companions.get(companion_id, {})
	var relationship: int = gs_data.get("relationship", 0)

	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_text: String = companion_data.get("name", companion_id)
	var role_text: String = companion_data.get("role", "")
	var prose: String = _relationship_prose(relationship)

	btn.text = name_text + "\n" + prose
	if role_text != "":
		btn.text = name_text + " — " + role_text + "\n" + prose

	btn.pressed.connect(_on_entry_selected.bind(companion_id))
	entry_list.add_child(btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.75, 0.7, 0.6, 0.5))
	entry_list.add_child(sep)


func _relationship_prose(relationship: int) -> String:
	if relationship <= 20:
		return "Someone Vera has met"
	elif relationship <= 50:
		return "Someone Vera is learning to know"
	elif relationship <= 80:
		return "Someone Vera trusts, in their own way"
	else:
		return "Someone Vera would call a friend, if the word still fit"


func _on_entry_selected(companion_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(companion_id)


func _clear_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()


func select_entry(entry_id: String) -> void:
	if _catalogue and _catalogue.has_method("show_entry"):
		_catalogue.show_entry(entry_id)
