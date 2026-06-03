extends Node

signal save_completed
signal load_completed
signal load_failed(reason: String)

# Saves are namespaced per campaign so two campaigns never clobber each other:
# user://saves/<campaign_id>.json. (Pre-frame builds used a single user://save.json;
# those orphaned saves are ignored — start a new game to migrate.)
const SAVE_DIR: String   = "user://saves/"
const SAVE_VERSION: int  = 3


# Path to the active campaign's save file.
func _save_path() -> String:
	return SAVE_DIR + DataManager.active_campaign + ".json"


func save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data: Dictionary = {
		"version":     SAVE_VERSION,
		"campaign_id": DataManager.active_campaign,
		"timestamp":   Time.get_datetime_string_from_system(),
		"game_state":  GameState.serialize(),
	}
	var path := _save_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file — %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit()


func load_save() -> bool:
	var path := _save_path()
	if not FileAccess.file_exists(path):
		load_failed.emit("No save file found.")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed.emit("Could not open save file.")
		return false
	var json_text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		load_failed.emit("Save file is corrupted.")
		return false
	var saved_version: int = data.get("version", 0)
	if saved_version != SAVE_VERSION:
		load_failed.emit("Save version mismatch: expected %d, got %d." % [SAVE_VERSION, saved_version])
		return false
	var saved_campaign: String = data.get("campaign_id", "")
	if saved_campaign != DataManager.active_campaign:
		load_failed.emit("Save belongs to a different campaign (%s)." % saved_campaign)
		return false
	GameState.deserialize(data.get("game_state", {}))
	load_completed.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(_save_path())


func delete_save() -> void:
	var path := _save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
