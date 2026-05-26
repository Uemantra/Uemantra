extends Node2D

var _festival_calendar: FestivalCalendar
var _npc_schedules: Dictionary = {}

const MVP_COMPANIONS: Array[String] = ["maren", "eli", "sable", "wren"]


func _ready() -> void:
	_festival_calendar = FestivalCalendar.new()

	for companion_id in MVP_COMPANIONS:
		_npc_schedules[companion_id] = NpcSchedule.new(companion_id)

	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.day_changed.connect(_on_day_changed)

	# Sync state immediately to current time on scene load.
	_on_hour_changed(TimeManager.hour)


func _on_hour_changed(hour: int) -> void:
	var season_name: String = TimeManager.get_season_name()
	for companion_id in _npc_schedules:
		var schedule: NpcSchedule = _npc_schedules[companion_id]
		var location: String = schedule.get_location(hour, season_name)
		var available: bool = schedule.is_available(hour, season_name)
		# Village scene children can listen for this signal or be queried directly.
		# Kept as a print for now — NPC node placement is a later visual pass.
		print("[Village] %s @ hour %d: %s (available: %s)" % [companion_id, hour, location, available])


func _on_day_changed(day: int, season: int, _year: int) -> void:
	var festival: Dictionary = _festival_calendar.get_festival_for_day(day, season)
	if not festival.is_empty():
		_trigger_festival(festival)


func _trigger_festival(festival: Dictionary) -> void:
	# Festivals happen whether or not the player is present.
	# This marks the flag and prints — dialogue/cutscene hookup is a later pass.
	var flag_key: String = "festival_occurred_%s_y%d" % [festival["id"], TimeManager.year]
	GameState.set_flag(flag_key, true)
	print("[Village] Festival: %s — %s" % [festival["name"], festival["description"]])


func enter_location(location_name: String) -> void:
	# Stub — will load sub-scenes once location scenes exist.
	print("[Village] Entering: %s" % location_name)
