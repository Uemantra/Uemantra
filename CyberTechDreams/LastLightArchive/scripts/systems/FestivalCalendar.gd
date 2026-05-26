extends RefCounted

var _festivals: Dictionary = {}


func _init() -> void:
	_festivals = DataManager.festivals


# Returns the festival dict for the given day/season, or empty dict if none.
func get_festival_for_day(day: int, season: int) -> Dictionary:
	var season_name: String = TimeManager.SEASONS[season]
	for festival_id in _festivals:
		var f: Dictionary = _festivals[festival_id]
		if f["season"] == season_name and f["day"] == day:
			return f
	return {}
