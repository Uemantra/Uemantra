extends Node

# Authored content — loaded once at startup, never mutated at runtime.
# All game content lives in res://data/ as JSON files.

var relics: Dictionary = {}
var echoes: Dictionary = {}
var caches: Dictionary = {}
var tools_config: Dictionary = {}
var companions_data: Dictionary = {}
var companion_schedules: Dictionary = {}
var zones_data: Dictionary = {}
var crops: Dictionary = {}
var festivals: Dictionary = {}
var tech_tree: Dictionary = {}
var theories: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	tools_config        = _load_json("res://data/tools/tools.json")
	companions_data     = _load_json("res://data/companions/companions.json")
	companion_schedules = _load_json("res://data/companions/schedules.json")
	crops               = _load_json("res://data/crops/crops.json")
	festivals           = _load_json("res://data/festivals.json")
	tech_tree           = _load_json("res://data/tech_tree.json")
	theories            = _load_json("res://data/theory_board/theories.json")
	_load_directory_into("res://data/catalogue/relics/", relics)
	_load_directory_into("res://data/catalogue/echoes/", echoes)
	_load_directory_into("res://data/catalogue/caches/", caches)
	_load_directory_into("res://data/zones/", zones_data)


func get_relic(id: String) -> Dictionary:
	return relics.get(id, {})


func get_echo(id: String) -> Dictionary:
	return echoes.get(id, {})


func get_cache(id: String) -> Dictionary:
	return caches.get(id, {})


func get_tool(id: String) -> Dictionary:
	return tools_config.get(id, {})


func get_companion(id: String) -> Dictionary:
	return companions_data.get(id, {})


func get_zone(id: String) -> Dictionary:
	return zones_data.get(id, {})


func get_crop(id: String) -> Dictionary:
	return crops.get(id, {})


func get_festival(id: String) -> Dictionary:
	return festivals.get(id, {})


func get_companion_schedule(id: String) -> Dictionary:
	return companion_schedules.get(id, {})


func get_tech_item(id: String) -> Dictionary:
	return tech_tree.get(id, {})


func get_theory(id: String) -> Dictionary:
	return theories.get(id, {})


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: could not open %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("DataManager: invalid JSON at %s" % path)
		return {}
	return parsed


func _load_directory_into(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var data := _load_json(dir_path + filename)
			if data.has("id"):
				target[data["id"]] = data
		filename = dir.get_next()
	dir.list_dir_end()
