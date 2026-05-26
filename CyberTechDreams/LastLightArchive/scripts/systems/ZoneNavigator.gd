extends RefCounted

var _zone_data: Dictionary = {}
var _current_location_id: String = ""


func _init(zone_data: Dictionary) -> void:
	_zone_data = zone_data


func set_current_location(location_id: String) -> void:
	_current_location_id = location_id


func get_current_location_id() -> String:
	return _current_location_id


func get_available_locations() -> Array:
	if _current_location_id.is_empty():
		return _zone_data.get("locations", {}).keys()
	var loc := get_location_data(_current_location_id)
	return loc.get("connections", [])


func can_travel_to(location_id: String) -> bool:
	if _current_location_id.is_empty():
		return _zone_data.get("locations", {}).has(location_id)
	var loc := get_location_data(_current_location_id)
	return location_id in loc.get("connections", [])


func get_location_data(location_id: String) -> Dictionary:
	var locations: Dictionary = _zone_data.get("locations", {})
	return locations.get(location_id, {})


func get_zone_name() -> String:
	return _zone_data.get("name", "")


func get_zone_description() -> String:
	return _zone_data.get("description", "")
