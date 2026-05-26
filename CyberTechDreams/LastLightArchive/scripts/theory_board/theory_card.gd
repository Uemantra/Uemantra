extends PanelContainer

signal selected(theory_id: String)

@export var theory_id: String = ""
@export var theory_name: String = ""
@export var theory_description: String = ""

@onready var _name_label: Label = $VBox/NameLabel
@onready var _desc_label: Label = $VBox/DescLabel
@onready var _evidence_list: VBoxContainer = $VBox/EvidenceList
@onready var _evidence_header: Label = $VBox/EvidenceHeader


func _ready() -> void:
	_name_label.text = theory_name
	_desc_label.text = theory_description
	gui_input.connect(_on_gui_input)


func refresh(evidence_echo_ids: Array[String]) -> void:
	for child in _evidence_list.get_children():
		child.queue_free()

	if evidence_echo_ids.is_empty():
		_evidence_header.visible = false
		return

	_evidence_header.visible = true
	for echo_id in evidence_echo_ids:
		var echo_data := DataManager.get_echo(echo_id)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 11)
		if echo_data.is_empty():
			label.text = "• " + echo_id
		else:
			label.text = "• " + echo_data.get("name", echo_id)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_evidence_list.add_child(label)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(theory_id)
