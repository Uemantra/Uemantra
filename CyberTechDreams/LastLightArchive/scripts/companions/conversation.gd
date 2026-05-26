extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _name_label: Label = $Panel/VBox/NameLabel
@onready var _text_label: RichTextLabel = $Panel/VBox/TextLabel
@onready var _advance_button: Button = $Panel/VBox/AdvanceButton

var _current_companion: String = ""
var _tween: Tween


func _ready() -> void:
	_panel.hide()
	_advance_button.pressed.connect(_on_advance_pressed)

	ConversationManager.conversation_started.connect(_on_conversation_started)
	ConversationManager.conversation_ended.connect(_on_conversation_ended)
	ConversationManager.line_delivered.connect(_on_line_delivered)
	# The dialogue panel starts transparent so the first line can fade in cleanly.
	_text_label.modulate.a = 0.0


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_advance_pressed()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- #
# Signal handlers
# --------------------------------------------------------------------------- #

func _on_conversation_started(companion_id: String) -> void:
	_current_companion = companion_id
	var companion_data: Dictionary = DataManager.get_companion(companion_id)
	_name_label.text = companion_data.get("name", companion_id)
	_text_label.text = ""
	_panel.show()


func _on_conversation_ended(_companion_id: String) -> void:
	_current_companion = ""
	if _tween:
		_tween.kill()
	_panel.hide()


func _on_line_delivered(companion_id: String, _line_id: String, speaker: String, text: String) -> void:
	_text_label.bbcode_enabled = true
	if speaker == "vera":
		_name_label.text = "Vera"
		_text_label.text = "[i]%s[/i]" % text
	else:
		var companion_data: Dictionary = DataManager.get_companion(companion_id)
		_name_label.text = companion_data.get("name", companion_id)
		_text_label.text = text

	_fade_in_text()


func _on_advance_pressed() -> void:
	ConversationManager.advance()


# --------------------------------------------------------------------------- #
# Internal
# --------------------------------------------------------------------------- #

func _fade_in_text() -> void:
	if _tween:
		_tween.kill()
	_text_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_text_label, "modulate:a", 1.0, 0.3)
