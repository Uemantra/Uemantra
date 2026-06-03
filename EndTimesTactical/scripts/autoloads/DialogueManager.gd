extends Node

signal conversation_started(npc_id: String)
signal conversation_ended(npc_id: String, completed: bool)
signal node_ready(node: Dictionary)
signal choices_ready(choices: Array)
signal skill_check_resolved(skill: String, roll: int, difficulty: int, passed: bool)
signal shop_requested(npc_id: String)

enum State { IDLE, SHOWING_NPC_LINE, WAITING_FOR_CHOICE }

var _state: State = State.IDLE
var _active_npc: String = ""
var _active_conversation: Dictionary = {}
var _current_node_id: String = ""


func can_talk_to(npc_id: String) -> bool:
	var convos := _get_available_conversations(npc_id)
	return not convos.is_empty()


func start_conversation(npc_id: String) -> void:
	var convos := _get_available_conversations(npc_id)
	if convos.is_empty():
		return
	_active_npc = npc_id
	_active_conversation = convos[0]
	_state = State.IDLE
	conversation_started.emit(npc_id)
	_resolve_node(_active_conversation.get("entry_node", ""))


func advance() -> void:
	if _state != State.SHOWING_NPC_LINE:
		return
	var node: Dictionary = _active_conversation["nodes"].get(_current_node_id, {})
	# A node flagged open_shop hands off to the trade UI: the conversation completes
	# (applying its on_complete effects) and then the listener opens the vendor's shop.
	if node.get("open_shop", false):
		var npc := _active_npc
		end_conversation(true)
		shop_requested.emit(npc)
		return
	var next = node.get("next", null)
	if next == null or next == "":
		end_conversation(true)
	else:
		_resolve_node(next)


func select_choice(choice_index: int) -> void:
	if _state != State.WAITING_FOR_CHOICE:
		return
	var node: Dictionary = _active_conversation["nodes"].get(_current_node_id, {})
	var choices: Array = _filter_visible_choices(node.get("choices", []))
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	var condition = choice.get("condition", null)
	if condition != null and condition.get("type", "") == "skill_check":
		var passed := _resolve_skill_check(condition)
		if not passed and condition.has("on_fail"):
			_resolve_node(condition["on_fail"])
			return
	var next = choice.get("next", null)
	if next == null or next == "":
		end_conversation(true)
	else:
		_resolve_node(next)


func end_conversation(completed: bool = true) -> void:
	if completed and not _active_conversation.is_empty():
		_apply_completion_effects(_active_conversation)
	var npc := _active_npc
	_active_npc = ""
	_active_conversation = {}
	_current_node_id = ""
	_state = State.IDLE
	conversation_ended.emit(npc, completed)


func _get_available_conversations(npc_id: String) -> Array:
	var dialogue_data := DataManager.get_dialogue(npc_id)
	if dialogue_data.is_empty():
		return []
	var result: Array = []
	for convo in dialogue_data.get("conversations", []):
		if _check_trigger_conditions(convo.get("trigger_conditions", {}), npc_id):
			result.append(convo)
	return result


func _check_trigger_conditions(conditions: Dictionary, _npc_id: String) -> bool:
	for flag_id in conditions.get("flags_required", []):
		if not GameState.get_flag(flag_id):
			return false
	for flag_id in conditions.get("flags_excluded", []):
		if GameState.get_flag(flag_id):
			return false
	for faction_id in conditions.get("faction_rep", {}):
		var min_rep: int = conditions["faction_rep"][faction_id]
		if GameState.get_rep(faction_id) < min_rep:
			return false
	return true


func _resolve_node(node_id: String) -> void:
	if node_id == null or node_id == "":
		end_conversation(true)
		return
	var nodes: Dictionary = _active_conversation.get("nodes", {})
	if not nodes.has(node_id):
		push_error("DialogueManager: node '%s' not found in conversation '%s'" % [node_id, _active_conversation.get("id", "?")])
		end_conversation(false)
		return
	var node: Dictionary = nodes[node_id]
	_current_node_id = node_id
	_apply_node_effects(node)
	match node.get("type", ""):
		"npc_line":
			_state = State.SHOWING_NPC_LINE
			node_ready.emit(node)
		"player_choice":
			_state = State.WAITING_FOR_CHOICE
			choices_ready.emit(_filter_visible_choices(node.get("choices", [])))
		_:
			push_error("DialogueManager: unknown node type '%s'" % node.get("type", ""))
			end_conversation(false)


func _filter_visible_choices(choices: Array) -> Array:
	var visible: Array = []
	for choice in choices:
		var condition = choice.get("condition", null)
		if condition == null:
			visible.append(choice)
			continue
		match condition.get("type", ""):
			"flag_required":
				if GameState.get_flag(condition.get("flag", "")):
					visible.append(choice)
			"flag_excluded":
				if not GameState.get_flag(condition.get("flag", "")):
					visible.append(choice)
			"faction_rep_min":
				var faction: String = condition.get("faction", "")
				var min_rep: int = condition.get("value", 0)
				if GameState.get_rep(faction) >= min_rep:
					visible.append(choice)
			"skill_check":
				visible.append(choice)
			_:
				visible.append(choice)
	return visible


func _resolve_skill_check(condition: Dictionary) -> bool:
	var skill: String = condition.get("skill", "")
	var difficulty: int = condition.get("difficulty", 50)
	var player_skill: int = GameState.skills.get(skill, 0)
	var roll := player_skill + randi_range(-5, 10)
	var passed := roll >= difficulty
	skill_check_resolved.emit(skill, roll, difficulty, passed)
	return passed


func _apply_node_effects(node: Dictionary) -> void:
	for flag_id in node.get("flags_set", []):
		GameState.set_flag(flag_id)
	var rel_change: int = node.get("relationship_change", 0)
	if rel_change != 0 and _active_npc != "":
		GameState.change_npc_relationship(_active_npc, rel_change)
	_apply_rewards(node)


func _apply_completion_effects(convo: Dictionary) -> void:
	var on_complete: Dictionary = convo.get("on_complete", {})
	for flag_id in on_complete.get("flags_set", []):
		GameState.set_flag(flag_id)
	var rel_change: int = on_complete.get("relationship_change", 0)
	if rel_change != 0 and _active_npc != "":
		GameState.change_npc_relationship(_active_npc, rel_change)
	for faction_id in on_complete.get("faction_rep_change", {}):
		GameState.add_rep(faction_id, on_complete["faction_rep_change"][faction_id])
	_apply_rewards(on_complete)


# Shared reward/quest hooks usable on any node or on_complete block.
func _apply_rewards(block: Dictionary) -> void:
	for quest_id in block.get("quests_started", []):
		QuestManager.start_quest(quest_id)
	for reward: Dictionary in block.get("item_rewards", []):
		GameState.add_item(reward.get("item_id", ""), int(reward.get("quantity", 1)))
	if block.has("caps_reward"):
		GameState.caps += int(block["caps_reward"])
		GameState.state_changed.emit()
	if block.has("xp_reward"):
		GameState.add_xp(int(block["xp_reward"]))
