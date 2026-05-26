extends RefCounted

var _companion_id: String = ""
var _schedule: Dictionary = {}


func _init(companion_id: String) -> void:
	_companion_id = companion_id
	_schedule = DataManager.get_companion_schedule(companion_id)


func get_location(hour: int, season: String) -> String:
	var blocks: Array = _schedule.get(season, [])
	for block in blocks:
		if hour >= block["hour_start"] and hour < block["hour_end"]:
			return block["location"]
	return "unknown"


func is_available(hour: int, season: String) -> bool:
	var blocks: Array = _schedule.get(season, [])
	for block in blocks:
		if hour >= block["hour_start"] and hour < block["hour_end"]:
			return block["available_for_conversation"]
	return false
