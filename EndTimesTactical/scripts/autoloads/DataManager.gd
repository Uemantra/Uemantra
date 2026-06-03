extends Node

# Authored content — loaded once at startup, never mutated at runtime.
# All game content lives in a *campaign* folder under res://campaigns/<id>/ as JSON
# files. Which campaign loads is named in res://campaigns/active.txt (one line). This
# keeps the engine content-agnostic: drop in a new campaign folder, point active.txt at
# it, and the same engine runs an entirely different game. See docs/AUTHORING.md.

const CAMPAIGNS_ROOT: String = "res://campaigns/"
const ACTIVE_FILE: String    = "res://campaigns/active.txt"
const DEFAULT_CAMPAIGN: String = "end_times_tactical"

var active_campaign: String = DEFAULT_CAMPAIGN
var manifest: Dictionary = {}

var npcs: Dictionary = {}
var dialogues: Dictionary = {}
var locations: Dictionary = {}
var quests: Dictionary = {}
var factions: Dictionary = {}
var items: Dictionary = {}
var world: Dictionary = {}
var local_maps: Dictionary = {}
var perks: Dictionary = {}
var traits: Dictionary = {}
var endings: Dictionary = {}


func _ready() -> void:
	active_campaign = _resolve_active_campaign()
	_load_all()


# Read the active campaign id from active.txt, falling back to the default if the file
# is missing/blank or names a campaign folder that doesn't exist.
func _resolve_active_campaign() -> String:
	var id := DEFAULT_CAMPAIGN
	if FileAccess.file_exists(ACTIVE_FILE):
		var f := FileAccess.open(ACTIVE_FILE, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text().strip_edges()
			f.close()
			if txt != "":
				id = txt
	if not DirAccess.dir_exists_absolute(CAMPAIGNS_ROOT + id):
		push_error("DataManager: campaign '%s' not found; using '%s'" % [id, DEFAULT_CAMPAIGN])
		id = DEFAULT_CAMPAIGN
	return id


# Resolve a path inside the active campaign folder (e.g. _campaign_path("npcs/")).
func _campaign_path(sub: String) -> String:
	return CAMPAIGNS_ROOT + active_campaign + "/" + sub


func _load_all() -> void:
	manifest = _load_json(_campaign_path("campaign.json"))
	world = _load_json(_campaign_path("world.json"))
	_load_directory_into(_campaign_path("npcs/"), npcs, false)
	_load_directory_into(_campaign_path("npcs/dialogues/"), dialogues, true)
	_load_directory_into(_campaign_path("locations/"), locations, false)
	_load_directory_into(_campaign_path("factions/"), factions, false)
	_load_directory_into(_campaign_path("quests/"), quests, false)
	_load_directory_into(_campaign_path("local_maps/"), local_maps, false)
	_load_list_file(_campaign_path("perks/perks.json"), "perks", perks)
	_load_list_file(_campaign_path("traits/traits.json"), "traits", traits)
	endings = _load_json(_campaign_path("endings/endings.json"))   # optional; {} if absent
	_load_items()


# Load a single file shaped like { "<list_key>": [ {id, ...}, ... ] } into a
# dictionary keyed by each entry's "id".
func _load_list_file(path: String, list_key: String, target: Dictionary) -> void:
	var data := _load_json(path)
	if data.is_empty():
		return
	for entry: Dictionary in data.get(list_key, []):
		if entry.has("id"):
			target[entry["id"]] = entry


func _load_items() -> void:
	for category in ["weapons", "armor", "consumables", "misc"]:
		var data := _load_json(_campaign_path("items/%s.json" % category))
		if data.is_empty():
			continue
		var arr: Array = data.get(category, [])
		for item in arr:
			if item.has("id"):
				items[item["id"]] = item


func get_manifest() -> Dictionary:
	return manifest


func get_endings() -> Dictionary:
	return endings


func get_npc(id: String) -> Dictionary:
	return npcs.get(id, {})


func get_dialogue(npc_id: String) -> Dictionary:
	return dialogues.get(npc_id, {})


func get_location(id: String) -> Dictionary:
	return locations.get(id, {})


func get_quest(id: String) -> Dictionary:
	return quests.get(id, {})


func get_faction(id: String) -> Dictionary:
	return factions.get(id, {})


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func get_perk(id: String) -> Dictionary:
	return perks.get(id, {})


func get_trait(id: String) -> Dictionary:
	return traits.get(id, {})


func get_all_perks() -> Array:
	return perks.values()


func get_all_traits() -> Array:
	return traits.values()


func get_world() -> Dictionary:
	return world


func get_local_map(id: String) -> Dictionary:
	return local_maps.get(id, {})


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


func _load_directory_into(dir_path: String, target: Dictionary, use_filename_as_key: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var data := _load_json(dir_path + filename)
			if use_filename_as_key:
				var key := filename.get_basename()
				target[key] = data
			elif data.has("id"):
				target[data["id"]] = data
		filename = dir.get_next()
	dir.list_dir_end()
