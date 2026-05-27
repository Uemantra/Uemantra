extends PanelContainer

@onready var _speaker_label: Label = $Contents/SpeakerRow/SpeakerLabel
@onready var _portrait: TextureRect = $Contents/SpeakerRow/Portrait
@onready var _dialogue_text: RichTextLabel = $Contents/DialogueText
@onready var _skill_check_result: Label = $Contents/SkillCheckResult
@onready var _choice_container: VBoxContainer = $Contents/ChoiceContainer
@onready var _continue_btn: Button = $Contents/ContinueButton

var _skill_flash_timer: float = 0.0


func _ready() -> void:
	_continue_btn.pressed.connect(DialogueManager.advance)
	DialogueManager.node_ready.connect(_on_node_ready)
	DialogueManager.choices_ready.connect(_on_choices_ready)
	DialogueManager.skill_check_resolved.connect(_on_skill_check_resolved)
	DialogueManager.conversation_ended.connect(_on_conversation_ended)


func _process(delta: float) -> void:
	if _skill_flash_timer > 0.0:
		_skill_flash_timer -= delta
		if _skill_flash_timer <= 0.0:
			_skill_check_result.visible = false


func _on_node_ready(node: Dictionary) -> void:
	visible = true
	var speaker_id: String = node.get("speaker", "")
	var npc := DataManager.get_npc(speaker_id)
	_speaker_label.text = npc.get("name", speaker_id) if not npc.is_empty() else speaker_id
	_dialogue_text.text = node.get("text", "")
	_continue_btn.visible = true
	_clear_choices()


func _on_choices_ready(choices: Array) -> void:
	visible = true
	_continue_btn.visible = false
	_clear_choices()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("text", "?")
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(DialogueManager.select_choice.bind(i))
		_choice_container.add_child(btn)


func _on_skill_check_resolved(skill: String, roll: int, difficulty: int, passed: bool) -> void:
	var result_text := "%s: %d vs %d — %s" % [
		skill.capitalize(), roll, difficulty,
		"Passed" if passed else "Failed"
	]
	_skill_check_result.text = result_text
	_skill_check_result.modulate = Color(0.5, 1.0, 0.5) if passed else Color(1.0, 0.5, 0.5)
	_skill_check_result.visible = true
	_skill_flash_timer = 2.5


func _on_conversation_ended(_npc_id: String, _completed: bool) -> void:
	visible = false
	_clear_choices()
	_continue_btn.visible = false


func _clear_choices() -> void:
	for child in _choice_container.get_children():
		child.queue_free()
