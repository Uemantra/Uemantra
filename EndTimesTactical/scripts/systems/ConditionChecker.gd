class_name ConditionChecker
extends RefCounted

static func check_trigger(conditions: Dictionary, _npc_id: String) -> bool:
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


static func check_choice(condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
	match condition.get("type", ""):
		"flag_required":
			return GameState.get_flag(condition.get("flag", ""))
		"flag_excluded":
			return not GameState.get_flag(condition.get("flag", ""))
		"faction_rep_min":
			return GameState.get_rep(condition.get("faction", "")) >= condition.get("value", 0)
		"skill_check":
			return true  # always visible; resolved at selection time
	return true
