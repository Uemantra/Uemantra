extends Node

signal conversation_started(companion_id: String)
signal conversation_ended(companion_id: String)
signal line_delivered(companion_id: String, line_id: String, speaker: String, text: String)
signal arc_milestone_reached(companion_id: String, arc_id: String)

var _active_companion: String = ""
var _current_lines: Array = []
var _current_line_index: int = 0
var _pending_relationship_change: int = 0
var _pending_flags: Array = []

# NpcSchedule instances are kept here so we're not re-allocating every check.
var _schedules: Dictionary = {}

# Loaded conversation data per companion, cached after first load.
var _dialogue_cache: Dictionary = {}


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

func can_talk_to(companion_id: String) -> bool:
	if _active_companion != "":
		return false
	var schedule := _get_schedule(companion_id)
	var hour: int = TimeManager.hour
	var season: String = TimeManager.get_season_name()
	return schedule.is_available(hour, season)


func start_conversation(companion_id: String) -> void:
	if _active_companion != "":
		push_warning("ConversationManager: tried to start conversation while one is active")
		return
	if not can_talk_to(companion_id):
		return

	var available := get_available_conversations(companion_id)
	if available.is_empty():
		return

	# Take the first available conversation — future passes can let player pick topic.
	var convo: Dictionary = available[0]
	_active_companion = companion_id
	_current_lines = convo.get("lines", [])
	_current_line_index = 0

	var on_complete: Dictionary = convo.get("on_complete", {})
	_pending_relationship_change = on_complete.get("relationship_change", 0)
	_pending_flags = on_complete.get("flags_set", [])

	TimeManager.pause()
	conversation_started.emit(companion_id)
	_deliver_current_line()


func advance() -> void:
	if _active_companion == "":
		return
	_current_line_index += 1
	if _current_line_index >= _current_lines.size():
		end_conversation()
	else:
		_deliver_current_line()


func end_conversation() -> void:
	if _active_companion == "":
		return

	var companion_id := _active_companion
	_apply_pending_changes(companion_id)

	_active_companion = ""
	_current_lines = []
	_current_line_index = 0
	_pending_relationship_change = 0
	_pending_flags = []

	TimeManager.resume()
	conversation_ended.emit(companion_id)


func get_available_conversations(companion_id: String) -> Array:
	var all_convos: Array = _load_dialogues(companion_id)
	if all_convos.is_empty():
		return []
	var tracker := ArcTracker.new(companion_id)
	return tracker.get_unlocked_conversations(all_convos)


func trigger_arc_milestone(companion_id: String, arc_id: String) -> void:
	var flag_key := "conv_arc_" + companion_id + "_" + arc_id
	if GameState.get_flag(flag_key):
		return
	GameState.set_flag(flag_key, true)
	if companion_id not in GameState.companions:
		return
	var arcs: Array = GameState.companions[companion_id]["arcs_completed"]
	if arc_id not in arcs:
		arcs.append(arc_id)
	arc_milestone_reached.emit(companion_id, arc_id)


func check_arc_triggers() -> void:
	# Called on day_changed. Checks all MVP companions for arc conditions that may
	# now be satisfied without requiring the player to enter a conversation first.
	for companion_id in ["maren", "eli", "sable", "wren"]:
		_check_passive_arcs(companion_id)


# --------------------------------------------------------------------------- #
# Internal helpers
# --------------------------------------------------------------------------- #

func _deliver_current_line() -> void:
	var line: Dictionary = _current_lines[_current_line_index]
	var line_id: String = line.get("id", "")
	var speaker: String = line.get("speaker", _active_companion)
	var text: String = line.get("text", "")
	GameState.set_flag("conv_seen_" + line_id, true)
	line_delivered.emit(_active_companion, line_id, speaker, text)


func _apply_pending_changes(companion_id: String) -> void:
	if _pending_relationship_change != 0:
		if companion_id in GameState.companions:
			var current: int = GameState.companions[companion_id]["relationship"]
			GameState.companions[companion_id]["relationship"] = clampi(
				current + _pending_relationship_change, 0, 100
			)
			GameState.state_changed.emit()

	for flag in _pending_flags:
		GameState.set_flag(flag, true)


func _get_schedule(companion_id: String) -> NpcSchedule:
	if companion_id not in _schedules:
		_schedules[companion_id] = NpcSchedule.new(companion_id)
	return _schedules[companion_id]


func _load_dialogues(companion_id: String) -> Array:
	if companion_id in _dialogue_cache:
		return _dialogue_cache[companion_id]

	var path := "res://data/companions/dialogues/%s.json" % companion_id
	if not FileAccess.file_exists(path):
		_dialogue_cache[companion_id] = []
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ConversationManager: could not open %s" % path)
		_dialogue_cache[companion_id] = []
		return []

	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed.has("conversations"):
		push_error("ConversationManager: invalid dialogue JSON at %s" % path)
		_dialogue_cache[companion_id] = []
		return []

	_dialogue_cache[companion_id] = parsed["conversations"]
	return _dialogue_cache[companion_id]


func _check_passive_arcs(_companion_id: String) -> void:
	# Stub for arcs that trigger by world condition rather than by conversation.
	# Each companion's arc beats are wired here as the arc scripts are authored.
	pass


func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	check_arc_triggers()
