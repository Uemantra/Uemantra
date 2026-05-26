extends PanelContainer

signal selected(echo_id: String)

@export var echo_id: String = ""
@export var is_resolved: bool = true
@export var weight_contributed: float = 0.0  # never shown to player

@onready var _name_label: Label = $VBox/NameLabel
@onready var _note_label: Label = $VBox/NoteLabel
@onready var _unresolved_tag: Label = $VBox/UnresolvedTag


func _ready() -> void:
	_refresh_display()
	gui_input.connect(_on_gui_input)


func setup(p_echo_id: String, p_is_resolved: bool, p_weight: float) -> void:
	echo_id = p_echo_id
	is_resolved = p_is_resolved
	weight_contributed = p_weight
	if is_node_ready():
		_refresh_display()


func _refresh_display() -> void:
	var echo_data := DataManager.get_echo(echo_id)
	if echo_data.is_empty():
		_name_label.text = echo_id
		_note_label.text = ""
	else:
		_name_label.text = echo_data.get("name", echo_id)
		var vera_note: String = echo_data.get("vera_note", "")
		# Show only the first sentence of vera_note — the board is crowded.
		var period_pos := vera_note.find(".")
		if period_pos != -1 and period_pos < 80:
			_note_label.text = vera_note.substr(0, period_pos + 1)
		else:
			_note_label.text = vera_note.substr(0, 80)

	if is_resolved:
		_unresolved_tag.visible = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		_name_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	else:
		_unresolved_tag.visible = true
		modulate = Color(1.0, 1.0, 1.0, 0.65)
		_name_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(echo_id)
