extends Node

signal hour_changed(hour: int)
signal day_changed(day: int, season: int, year: int)
signal season_changed(season: int, year: int)
signal year_changed(year: int)

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const DAYS_PER_SEASON: int = 28
const HOURS_PER_DAY: int = 24

# Real seconds per in-game hour. 60s = one day takes ~24 minutes of play.
# SEG-01 can tune this; it's intentionally exposed for iteration.
@export var seconds_per_hour: float = 60.0

var hour: int = 6
var day: int = 1
var season: int = 0
var year: int = 1

var _elapsed: float = 0.0
var _paused: bool = false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += delta
	if _elapsed >= seconds_per_hour:
		_elapsed -= seconds_per_hour
		_advance_hour()


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func is_daytime() -> bool:
	return hour >= 6 and hour < 20


func get_season_name() -> String:
	return SEASONS[season]


func get_display_string() -> String:
	var period := "am" if hour < 12 else "pm"
	var display_hour := hour if hour <= 12 else hour - 12
	if display_hour == 0:
		display_hour = 12
	return "Day %d, %s — %d%s" % [day, get_season_name().capitalize(), display_hour, period]


func _advance_hour() -> void:
	hour = (hour + 1) % HOURS_PER_DAY
	hour_changed.emit(hour)
	if hour == 0:
		_advance_day()


func _advance_day() -> void:
	day += 1
	day_changed.emit(day, season, year)
	if day > DAYS_PER_SEASON:
		day = 1
		_advance_season()


func _advance_season() -> void:
	season = (season + 1) % SEASONS.size()
	if season == 0:
		year += 1
		year_changed.emit(year)
	season_changed.emit(season, year)


func serialize() -> Dictionary:
	return {
		"hour":   hour,
		"day":    day,
		"season": season,
		"year":   year,
	}


func deserialize(data: Dictionary) -> void:
	hour    = data.get("hour",   6)
	day     = data.get("day",    1)
	season  = data.get("season", 0)
	year    = data.get("year",   1)
	_elapsed = 0.0
