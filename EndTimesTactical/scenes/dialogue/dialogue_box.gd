extends Control

@onready var _portrait_texture: TextureRect = $InletPanel/InletContents/PortraitTexture
@onready var _portrait_placeholder: Label = $InletPanel/InletContents/PortraitPlaceholder
@onready var _portrait_role: Label = $InletPanel/InletContents/PortraitRole
@onready var _speaker_label: Label = $DialogueArea/Contents/SpeakerLabel
@onready var _dialogue_text: RichTextLabel = $DialogueArea/Contents/DialogueText
@onready var _skill_check_result: Label = $DialogueArea/Contents/SkillCheckResult
@onready var _choice_container: VBoxContainer = $DialogueArea/Contents/ChoiceContainer
@onready var _continue_btn: Button = $DialogueArea/Contents/ContinueButton

var _skill_flash_timer: float = 0.0


func _ready() -> void:
	_continue_btn.pressed.connect(DialogueManager.advance)
	_add_leave_hint()
	DialogueManager.node_ready.connect(_on_node_ready)
	DialogueManager.choices_ready.connect(_on_choices_ready)
	DialogueManager.skill_check_resolved.connect(_on_skill_check_resolved)
	DialogueManager.conversation_ended.connect(_on_conversation_ended)


func _process(delta: float) -> void:
	if _skill_flash_timer > 0.0:
		_skill_flash_timer -= delta
		if _skill_flash_timer <= 0.0:
			_skill_check_result.visible = false


# Universal bail-out: Escape (or right-click) always ends the conversation so the
# player can never get trapped — e.g. on a choice node whose options are all
# condition-gated and hidden.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var cancel: bool = event.is_action_pressed("ui_cancel")
	var right_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT
	if cancel or right_click:
		DialogueManager.end_conversation(false)
		get_viewport().set_input_as_handled()


func _on_node_ready(node: Dictionary) -> void:
	visible = true
	var speaker_id: String = node.get("speaker", "")
	var npc := DataManager.get_npc(speaker_id)
	var npc_name: String = npc.get("name", speaker_id) if not npc.is_empty() else speaker_id
	var npc_role: String = npc.get("role", "") if not npc.is_empty() else ""
	_portrait_placeholder.text = "[ %s ]" % npc_name.to_upper()
	_portrait_role.text = npc_role
	_speaker_label.text = npc_name
	_dialogue_text.text = node.get("text", "")
	_continue_btn.visible = true
	_clear_choices()
	var portrait := PortraitMapper.get_portrait(speaker_id, npc)
	_portrait_texture.texture = portrait
	_portrait_texture.visible = portrait != null


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
	# Safety net: a choice node with every option condition-gated would otherwise
	# leave no button to press. Always offer a way out.
	if _choice_container.get_child_count() == 0:
		var leave := Button.new()
		leave.text = "[ Leave ]"
		leave.custom_minimum_size = Vector2(0, 36)
		leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
		leave.pressed.connect(DialogueManager.end_conversation.bind(false))
		_choice_container.add_child(leave)


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


func _add_leave_hint() -> void:
	var hint := Label.new()
	hint.text = "Esc / right-click: leave"
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -220
	hint.offset_top = 6
	hint.offset_right = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
