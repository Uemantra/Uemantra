class_name ConditionChecker
extends RefCounted

# General-purpose condition evaluator shared by dialogue triggers, quest gating, and
# ending slides. A conditions dict may contain any of:
#   flags_required / flags_all : Array  — ALL must be set
#   flags_any                  : Array  — at least ONE must be set
#   flags_excluded             : Array  — NONE may be set
#   karma_min / karma_max      : int    — player karma bounds (inclusive)
#   faction_rep                : { faction_id: min_rep }   — rep must be >= value
#   faction_rep_max            : { faction_id: max_rep }   — rep must be <= value
static func check_conditions(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	for flag_id in conditions.get("flags_required", []):
		if not GameState.get_flag(flag_id):
			return false
	for flag_id in conditions.get("flags_all", []):
		if not GameState.get_flag(flag_id):
			return false
	var any: Array = conditions.get("flags_any", [])
	if not any.is_empty():
		var hit := false
		for flag_id in any:
			if GameState.get_flag(flag_id):
				hit = true
				break
		if not hit:
			return false
	for flag_id in conditions.get("flags_excluded", []):
		if GameState.get_flag(flag_id):
			return false
	if conditions.has("karma_min") and GameState.get_karma() < int(conditions["karma_min"]):
		return false
	if conditions.has("karma_max") and GameState.get_karma() > int(conditions["karma_max"]):
		return false
	for faction_id in conditions.get("faction_rep", {}):
		if GameState.get_rep(faction_id) < int(conditions["faction_rep"][faction_id]):
			return false
	for faction_id in conditions.get("faction_rep_max", {}):
		if GameState.get_rep(faction_id) > int(conditions["faction_rep_max"][faction_id]):
			return false
	return true


static func check_trigger(conditions: Dictionary, _npc_id: String) -> bool:
	return check_conditions(conditions)


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
		"karma_min":
			return GameState.get_karma() >= int(condition.get("value", 0))
		"karma_max":
			return GameState.get_karma() <= int(condition.get("value", 0))
		"skill_check":
			return true  # always visible; resolved at selection time
	return true
