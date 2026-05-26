extends RefCounted

var _companion_id: String = ""


func _init(companion_id: String) -> void:
	_companion_id = companion_id


# Evaluates all conditions in the given conditions dict against current game state.
# Returns true only if every condition is satisfied.
func check_conditions(conditions: Dictionary) -> bool:
	var relationship: int = 0
	if _companion_id in GameState.companions:
		relationship = GameState.companions[_companion_id]["relationship"]

	var rel_min: int = conditions.get("relationship_min", 0)
	var rel_max: int = conditions.get("relationship_max", 100)
	if relationship < rel_min or relationship > rel_max:
		return false

	for flag in conditions.get("flags_required", []):
		if not GameState.get_flag(flag):
			return false

	for flag in conditions.get("flags_excluded", []):
		if GameState.get_flag(flag):
			return false

	var time_condition: String = conditions.get("time", "any")
	if time_condition != "any":
		if not _check_time_condition(time_condition):
			return false

	return true


# Returns the subset of conversations from all_conversations whose trigger_conditions
# are currently met and which haven't been permanently locked by a seen-flag.
func get_unlocked_conversations(all_conversations: Array) -> Array:
	var result: Array = []
	for convo in all_conversations:
		var conditions: Dictionary = convo.get("trigger_conditions", {})
		if check_conditions(conditions):
			result.append(convo)
	return result


# --------------------------------------------------------------------------- #
# Internal
# --------------------------------------------------------------------------- #

func _check_time_condition(condition: String) -> bool:
	var hour: int = TimeManager.hour
	match condition:
		"evening":
			return hour >= 18
		"daytime":
			return hour >= 6 and hour < 18
		"morning":
			return hour >= 6 and hour < 12
		"night":
			return hour >= 21 or hour < 6
	# Unknown condition strings pass — author error, not a hard block.
	push_warning("ArcTracker: unknown time condition '%s'" % condition)
	return true
