extends Control

@onready var _name_label: Label = $LocationNameLabel
@onready var _desc_label: Label = $DescriptionLabel
@onready var _npc_container: VBoxContainer = $NpcContainer
@onready var _interactable_container: VBoxContainer = $InteractableContainer
@onready var _leave_btn: Button = $BottomBar/LeaveButton
@onready var _combat_btn: Button = $BottomBar/CombatButton
@onready var _inventory_btn: Button = $BottomBar/InventoryButton
@onready var _journal_btn: Button = $BottomBar/JournalButton
@onready var _save_btn: Button = $BottomBar/SaveButton
@onready var _examine_panel: PanelContainer = $ExaminePanel
@onready var _examine_title: Label = $ExaminePanel/ExamineContents/ExamineTitleLabel
@onready var _examine_text: RichTextLabel = $ExaminePanel/ExamineContents/ExamineTextLabel
@onready var _examine_close: Button = $ExaminePanel/ExamineContents/ExamineCloseBtn

var _dialogue_box: Control = null
var _location_data: Dictionary = {}


func _ready() -> void:
	_location_data = DataManager.get_location(GameState.current_location)
	_populate_location()
	_connect_buttons()
	_check_first_visit()
	_spawn_dialogue_box()


func _populate_location() -> void:
	_name_label.text = _location_data.get("name", "Unknown")
	_desc_label.text = _location_data.get("description", "")

	# NPC buttons
	for child in _npc_container.get_children():
		if child is Button:
			child.queue_free()
	for npc_id in _location_data.get("npcs_present", []):
		var npc := DataManager.get_npc(npc_id)
		if npc.is_empty():
			continue
		var btn := Button.new()
		btn.text = npc.get("name", npc_id)
		btn.custom_minimum_size = Vector2(200, 40)
		btn.tooltip_text = npc.get("role", "")
		btn.pressed.connect(_on_npc_clicked.bind(npc_id))
		_npc_container.add_child(btn)

	# Interactable buttons
	for child in _interactable_container.get_children():
		if child is Button:
			child.queue_free()
	for interactable in _location_data.get("interactables", []):
		var flags_required: Array = interactable.get("flags_required", [])
		var passes := true
		for flag_id in flags_required:
			if not GameState.get_flag(flag_id):
				passes = false
				break
		if not passes:
			continue
		var btn := Button.new()
		btn.text = interactable.get("label", "?")
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_interactable_clicked.bind(interactable))
		_interactable_container.add_child(btn)

	# Combat button
	var combat_data: Variant = _location_data.get("combat_arena", null)
	var trigger_data: Dictionary = _location_data.get("combat_trigger", {})
	if combat_data != null:
		var once_flag: String = trigger_data.get("trigger_once_flag", "")
		var already_cleared := once_flag != "" and GameState.get_flag(once_flag)
		var auto_trigger: bool = trigger_data.get("auto_trigger", false)
		if not already_cleared:
			if auto_trigger:
				_trigger_combat()
			else:
				_combat_btn.visible = true
				_combat_btn.text = "ENTER ZONE"
				_combat_btn.pressed.connect(_trigger_combat)


func _connect_buttons() -> void:
	_leave_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/overworld/overworld.tscn"))
	_inventory_btn.pressed.connect(_open_inventory)
	_journal_btn.pressed.connect(_open_journal)
	_save_btn.pressed.connect(func(): SaveManager.save())
	_examine_close.pressed.connect(func(): _examine_panel.visible = false)


func _check_first_visit() -> void:
	var on_first_visit: Dictionary = _location_data.get("on_first_visit", {})
	if on_first_visit.is_empty():
		return
	var loc_id := GameState.current_location
	var visit_flag := "visited_%s" % loc_id
	if not GameState.get_flag(visit_flag):
		for flag_id in on_first_visit.get("flags_set", []):
			GameState.set_flag(flag_id)
		GameState.set_flag(visit_flag)


func _spawn_dialogue_box() -> void:
	var db_scene := load("res://scenes/dialogue/dialogue_box.tscn")
	if db_scene == null:
		return
	_dialogue_box = db_scene.instantiate()
	add_child(_dialogue_box)
	_dialogue_box.visible = false


func _on_npc_clicked(npc_id: String) -> void:
	if not DialogueManager.can_talk_to(npc_id):
		_show_examine("(No dialogue)", "%s has nothing to say right now." % DataManager.get_npc(npc_id).get("name", npc_id))
		return
	if _dialogue_box != null:
		_dialogue_box.visible = true
	DialogueManager.start_conversation(npc_id)


func _on_interactable_clicked(interactable: Dictionary) -> void:
	_show_examine(interactable.get("label", ""), interactable.get("text", ""))


func _show_examine(title: String, text: String) -> void:
	_examine_title.text = title
	_examine_text.text = text
	_examine_panel.visible = true
	_examine_panel.move_to_front()


func _trigger_combat() -> void:
	var trigger_data: Dictionary = _location_data.get("combat_trigger", {})
	var enemy_ids: Array = trigger_data.get("enemy_ids", [])
	var arena_id: String = _location_data.get("combat_arena", "generic_arena")
	CombatManager.start_combat(arena_id, enemy_ids)
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")


func _open_inventory() -> void:
	var inv_scene := load("res://scenes/ui/inventory_panel.tscn")
	if inv_scene == null:
		return
	var panel = inv_scene.instantiate()
	add_child(panel)
	panel.move_to_front()


func _open_journal() -> void:
	var journal_scene := load("res://scenes/ui/quest_journal.tscn")
	if journal_scene == null:
		return
	var panel = journal_scene.instantiate()
	add_child(panel)
	panel.move_to_front()
