class_name AmbientZoneMap
extends RefCounted

# Maps zone_id + location_id to an ambient track ID.
# Most locations in a zone inherit the zone's ambient;
# special locations listed explicitly have their own sonic character.


static func get_ambient_for_location(zone_id: String, location_id: String) -> String:
	# Check special locations first — they override zone defaults.
	match location_id:
		"sealed_basement":
			return "location_sealed_basement"
		"archive_room":
			return "location_archive_room"
		"rig_workshop":
			return "village_workshop"

	# Fall through to zone-level ambient.
	match zone_id:
		"zone_residential":
			return "zone_residential"
		"zone_university":
			return "zone_university"
		"zone_flooded":
			return "zone_flooded"
		"village":
			return _get_village_ambient(location_id)
		_:
			# Unknown zone: return zone_id directly so new zones don't need a code change —
			# AudioManager will silently skip it if the file doesn't exist yet.
			return zone_id


static func _get_village_ambient(location_id: String) -> String:
	match location_id:
		"workshop":
			return "village_workshop"
		_:
			return "village_square"
