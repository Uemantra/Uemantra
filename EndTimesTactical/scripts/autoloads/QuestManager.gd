extends Node

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, stage_id: String)
@warning_ignore("unused_signal")
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)


func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)


func start_quest(quest_id: String) -> void:
	if GameState.quest_states.has(quest_id):
		return
	var quest := DataManager.get_quest(quest_id)
	if quest.is_empty():
		push_error("QuestManager: quest '%s' not found" % quest_id)
		return
	GameState.quest_states[quest_id] = {
		"state": "active",
		"active_stage_index": 0,
	}
	quest_started.emit(quest_id)
	GameState.state_changed.emit()


func check_all_quests() -> void:
	for quest_id in GameState.quest_states:
		var qs: Dictionary = GameState.quest_states[quest_id]
		if qs.get("state", "") != "active":
			continue
		var quest := DataManager.get_quest(quest_id)
		if quest.is_empty():
			continue
		var stages: Array = quest.get("stages", [])
		var stage_index: int = qs.get("active_stage_index", 0)
		if stage_index >= stages.size():
			continue
		var stage: Dictionary = stages[stage_index]
		if _stage_complete(stage):
			_advance_stage(quest_id, quest, stage_index)


func get_active_quests() -> Array:
	var result: Array = []
	for quest_id in GameState.quest_states:
		if GameState.quest_states[quest_id].get("state", "") == "active":
			result.append(quest_id)
	return result


func get_quest_display(quest_id: String) -> Dictionary:
	var quest := DataManager.get_quest(quest_id)
	if quest.is_empty():
		return {}
	var qs: Dictionary = GameState.quest_states.get(quest_id, {})
	var stage_index: int = qs.get("active_stage_index", 0)
	var stages: Array = quest.get("stages", [])
	if stage_index >= stages.size():
		return {"title": quest.get("title", ""), "objectives": [], "complete": true}
	var stage: Dictionary = stages[stage_index]
	var objectives: Array = []
	for obj in stage.get("objectives", []):
		objectives.append({
			"text":     obj.get("text", ""),
			"complete": GameState.get_flag(obj.get("flag_complete", "")),
			"optional": obj.get("optional", false),
		})
	return {
		"title":      quest.get("title", ""),
		"stage":      stage.get("title", ""),
		"summary":    quest.get("summary", ""),
		"objectives": objectives,
		"complete":   false,
	}


func _stage_complete(stage: Dictionary) -> bool:
	var flags_all: Array = stage.get("completion_condition", {}).get("flags_all", [])
	for flag_id in flags_all:
		if not GameState.get_flag(flag_id):
			return false
	return not flags_all.is_empty()


func _advance_stage(quest_id: String, quest: Dictionary, current_index: int) -> void:
	var stages: Array = quest.get("stages", [])
	var stage: Dictionary = stages[current_index]
	var on_complete: Dictionary = stage.get("on_complete", {})

	for flag_id in on_complete.get("flags_set", []):
		GameState.flags[flag_id] = true
	_grant_rewards(on_complete)

	var next_stage_raw: Variant = on_complete.get("next_stage", "")
	var next_stage_id: String = next_stage_raw if next_stage_raw is String else ""
	var next_index := current_index + 1

	if next_stage_id != "":
		for i in stages.size():
			if stages[i].get("id", "") == next_stage_id:
				next_index = i
				break

	if next_index >= stages.size():
		GameState.quest_states[quest_id]["state"] = "complete"
		_grant_rewards(quest)  # quest-level rewards on full completion
		quest_completed.emit(quest_id)
		# A quest can end the game (e.g. the main quest): "ends_game": true.
		if quest.get("ends_game", false) or on_complete.get("end_game", false):
			GameState.request_ending(str(quest.get("ending_id", "default")))
	else:
		GameState.quest_states[quest_id]["active_stage_index"] = next_index
		quest_updated.emit(quest_id, stages[next_index].get("id", ""))

	GameState.state_changed.emit()


# Grant xp / caps / item rewards declared on a stage's on_complete or on a quest.
func _grant_rewards(block: Dictionary) -> void:
	for reward: Dictionary in block.get("item_rewards", []):
		GameState.add_item(reward.get("item_id", ""), int(reward.get("quantity", 1)))
	if block.has("caps_reward"):
		GameState.caps += int(block["caps_reward"])
	if block.has("xp_reward"):
		GameState.add_xp(int(block["xp_reward"]))
	if block.has("karma_reward"):
		GameState.add_karma(int(block["karma_reward"]))


func _on_state_changed() -> void:
	check_all_quests()
