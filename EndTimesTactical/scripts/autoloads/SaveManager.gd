extends Node

signal save_completed
signal load_completed
signal load_failed(reason: String)

const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1


func save() -> void:
	var data: Dictionary = {
		"version":    SAVE_VERSION,
		"timestamp":  Time.get_datetime_string_from_system(),
		"game_state": GameState.serialize(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file — %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit()


func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		load_failed.emit("No save file found.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	GameState.deserialize(data.get("game_state", {}))
	load_completed.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
