extends Node

signal expedition_started(zone_id: String)
signal expedition_ended
signal location_entered(location_id: String)
signal artifact_found(artifact_type: String, artifact_id: String)
signal cache_discovered(cache_id: String, field_note: String)
signal carry_weight_changed(current: float, max: float)

const WEIGHT_SCRAP: float = 0.5
const WEIGHT_RELIC: float = 2.0
const WEIGHT_ECHO: float = 1.0
const WEIGHT_CACHE: float = 3.0

var is_on_expedition: bool = false
var current_zone_id: String = ""
var current_location_id: String = ""
var carry_weight_current: float = 0.0
var carry_weight_max: float = 20.0

var _current_zone_data: Dictionary = {}


func start_expedition(zone_id: String) -> void:
	var zone := DataManager.get_zone(zone_id)
	if zone.is_empty():
		push_error("ExpeditionManager: zone '%s' not found" % zone_id)
		return
	is_on_expedition = true
	current_zone_id = zone_id
	_current_zone_data = zone
	current_location_id = ""
	_recalculate_carry_weight()
	TimeManager.pause()
	GameState.mark_zone_visited(zone_id)
	expedition_started.emit(zone_id)


func end_expedition() -> void:
	is_on_expedition = false
	current_zone_id = ""
	current_location_id = ""
	_current_zone_data = {}
	TimeManager.resume()
	expedition_ended.emit()


func enter_location(location_id: String) -> void:
	if not is_on_expedition:
		push_error("ExpeditionManager: enter_location called while not on expedition")
		return
	var locations: Dictionary = _current_zone_data.get("locations", {})
	if location_id not in locations:
		push_error("ExpeditionManager: location '%s' not in zone '%s'" % [location_id, current_zone_id])
		return
	current_location_id = location_id
	GameState.mark_location_explored(current_zone_id, location_id)
	location_entered.emit(location_id)


func try_pickup_artifact(artifact_type: String, artifact_id: String, weight: float) -> bool:
	if carry_weight_current + weight > carry_weight_max:
		return false
	carry_weight_current += weight
	GameState.add_to_inventory(artifact_type, artifact_id)
	carry_weight_changed.emit(carry_weight_current, carry_weight_max)
	artifact_found.emit(artifact_type, artifact_id)
	return true


func discover_cache(cache_id: String) -> void:
	var location_data := _get_current_location_data()
	var field_note := ""
	for artifact in location_data.get("artifacts", []):
		if artifact.get("type") == "cache" and artifact.get("id") == cache_id:
			field_note = artifact.get("field_note", "")
			break
	if field_note.is_empty():
		var cache_record := DataManager.get_cache(cache_id)
		field_note = cache_record.get("vera_field_note", "")
	if carry_weight_current + WEIGHT_CACHE > carry_weight_max:
		return
	carry_weight_current += WEIGHT_CACHE
	GameState.add_to_inventory("cache", cache_id)
	carry_weight_changed.emit(carry_weight_current, carry_weight_max)
	cache_discovered.emit(cache_id, field_note)


func get_carry_percentage() -> float:
	if carry_weight_max <= 0.0:
		return 0.0
	return carry_weight_current / carry_weight_max


func get_current_location_data() -> Dictionary:
	return _get_current_location_data()


func _get_current_location_data() -> Dictionary:
	if current_location_id.is_empty():
		return {}
	var locations: Dictionary = _current_zone_data.get("locations", {})
	return locations.get(current_location_id, {})


func _recalculate_carry_weight() -> void:
	var inv := GameState.inventory
	var w := inv.get("scrap", 0) * WEIGHT_SCRAP
	w += inv.get("relics", []).size() * WEIGHT_RELIC
	w += inv.get("echoes", []).size() * WEIGHT_ECHO
	w += inv.get("caches", []).size() * WEIGHT_CACHE
	carry_weight_current = w
	carry_weight_changed.emit(carry_weight_current, carry_weight_max)
