class_name AudioIntegrator
extends Node

# Wires AudioManager to the rest of the game's systems.
# Not an autoload — instantiate as a child of the main scene.
# All connections are made here so the signal plumbing is visible in one place.

var _last_daytime: bool = false


func _ready() -> void:
	_last_daytime = TimeManager.is_daytime()

	ExpeditionManager.location_entered.connect(_on_location_entered)

	CatalogueManager.cache_processing_started.connect(_on_cache_processing_started)
	CatalogueManager.cache_processing_complete.connect(_on_cache_processing_complete)

	TimeManager.hour_changed.connect(_on_hour_changed)

	# Set opening ambient based on village (pre-expedition default).
	AudioManager.set_ambient(AmbientZoneMap.get_ambient_for_location("village", ""))

	# When an expedition ends, return to village ambient.
	ExpeditionManager.expedition_ended.connect(_on_expedition_ended)


func _on_location_entered(location_id: String) -> void:
	var zone_id := ExpeditionManager.current_zone_id
	var track_id := AmbientZoneMap.get_ambient_for_location(zone_id, location_id)
	AudioManager.set_ambient(track_id)


func _on_expedition_ended() -> void:
	AudioManager.set_ambient(AmbientZoneMap.get_ambient_for_location("village", ""))


func _on_cache_processing_started(_cache_id: String, tool_id: String) -> void:
	AudioManager.start_tool_signature(tool_id)


func _on_cache_processing_complete(_cache_id: String, _results: Array) -> void:
	AudioManager.stop_tool_signature()


func _on_hour_changed(_hour: int) -> void:
	var daytime_now := TimeManager.is_daytime()
	if daytime_now == _last_daytime:
		return
	_last_daytime = daytime_now
	# A transition between day and night warrants a soft ambient re-cross-fade
	# to encourage the sound designer to author day/night variants per zone.
	# For now we re-trigger the same track; the file-existence check in AudioManager
	# means a missing night variant simply fades to silence without breaking anything.
	if ExpeditionManager.is_on_expedition:
		var zone_id := ExpeditionManager.current_zone_id
		var location_id := ExpeditionManager.current_location_id
		var track_id := AmbientZoneMap.get_ambient_for_location(zone_id, location_id)
		AudioManager.set_ambient(track_id)
	else:
		AudioManager.set_ambient(AmbientZoneMap.get_ambient_for_location("village", ""))
