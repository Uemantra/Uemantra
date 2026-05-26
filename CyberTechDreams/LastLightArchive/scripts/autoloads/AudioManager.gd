extends Node

signal ambient_changed(location_id: String)
signal tool_signature_started(tool_id: String)
signal tool_signature_stopped

const AMBIENT_PATH:  String = "res://assets/audio/ambient/"
const MUSIC_PATH:    String = "res://assets/audio/music/"
const TOOLS_PATH:    String = "res://assets/audio/tools/"

const FADE_STEP:     float = 0.05   # volume step per tick during cross-fade
const FADE_TICK:     float = 0.05   # seconds between fade steps

var _ambient_player: AudioStreamPlayer
var _tool_player:    AudioStreamPlayer
var _music_player:   AudioStreamPlayer

# Tracks whether we're currently running a tool signature loop.
var _active_tool_id: String = ""

# Lattice: irregular relay tick timer.
var _lattice_timer:  Timer

# Echo: long-silence-then-fragment timer.
var _echo_timer:     Timer

# For cross-fade: the player we are fading out.
var _ambient_fading: AudioStreamPlayer


func _ready() -> void:
	_ambient_player = _make_player("Ambient")
	_tool_player    = _make_player("Tool")
	_music_player   = _make_player("Music")
	_ambient_fading = _make_player("AmbientFade")

	_lattice_timer = Timer.new()
	_lattice_timer.one_shot = true
	_lattice_timer.timeout.connect(_on_lattice_tick)
	add_child(_lattice_timer)

	_echo_timer = Timer.new()
	_echo_timer.one_shot = true
	_echo_timer.timeout.connect(_on_echo_fragment)
	add_child(_echo_timer)


# ---------------------------------------------------------------------------
# Ambient
# ---------------------------------------------------------------------------

func set_ambient(location_id: String) -> void:
	var path := AMBIENT_PATH + location_id + ".ogg"
	if not FileAccess.file_exists(path):
		# Gracefully fade out current ambient; no replacement available yet.
		_fade_out(_ambient_player)
		ambient_changed.emit(location_id)
		return

	var stream := load(path) as AudioStream
	if stream == null:
		_fade_out(_ambient_player)
		ambient_changed.emit(location_id)
		return

	# Cross-fade: start fading out the current player, start new stream at 0 vol.
	_ambient_fading.stream = _ambient_player.stream
	_ambient_fading.volume_db = _ambient_player.volume_db
	_ambient_fading.play()
	_fade_out(_ambient_fading)

	_ambient_player.stream = stream
	_ambient_player.volume_db = -80.0
	_ambient_player.play()
	_fade_in(_ambient_player)

	ambient_changed.emit(location_id)


# ---------------------------------------------------------------------------
# Tool signatures
# ---------------------------------------------------------------------------

func start_tool_signature(tool_id: String) -> void:
	stop_tool_signature()
	_active_tool_id = tool_id
	match tool_id:
		"glean":
			_run_glean_signature()
		"lattice":
			_run_lattice_signature()
		"echo":
			_run_echo_signature()
	tool_signature_started.emit(tool_id)


func stop_tool_signature() -> void:
	_active_tool_id = ""
	_lattice_timer.stop()
	_echo_timer.stop()
	_tool_player.stop()
	tool_signature_stopped.emit()


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

func play_music(track_id: String) -> void:
	var path := MUSIC_PATH + track_id + ".ogg"
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	_music_player.play()


func stop_music(fade_seconds: float = 2.0) -> void:
	if not _music_player.playing:
		return
	_fade_out(_music_player, fade_seconds)


# ---------------------------------------------------------------------------
# Master volume
# ---------------------------------------------------------------------------

func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(clampf(linear, 0.0, 1.0))
	)


# ---------------------------------------------------------------------------
# Tool signature helpers
# ---------------------------------------------------------------------------

func _run_glean_signature() -> void:
	var path := TOOLS_PATH + "glean_hum.ogg"
	if not FileAccess.file_exists(path):
		return  # Silence is fine — asset lands here without code changes.
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_tool_player.stream = stream
	# Glean hums constantly, so we loop the player itself.
	# AudioStreamOGGVorbis has a loop property; if unavailable we just replay on finish.
	if stream.has_method("set_loop"):
		stream.set_loop(true)
	_tool_player.volume_db = 0.0
	_tool_player.play()


func _run_lattice_signature() -> void:
	# Schedule the first tick; subsequent ticks are re-scheduled in _on_lattice_tick.
	_lattice_timer.wait_time = randf_range(0.8, 1.4)
	_lattice_timer.start()


func _on_lattice_tick() -> void:
	if _active_tool_id != "lattice":
		return
	var path := TOOLS_PATH + "lattice_tick.ogg"
	if FileAccess.file_exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			_tool_player.stream = stream
			_tool_player.play()
	# Re-arm with a new random interval regardless of whether the file exists —
	# the irregular rhythm is the texture, not just the click sound.
	_lattice_timer.wait_time = randf_range(0.8, 1.4)
	_lattice_timer.start()


func _run_echo_signature() -> void:
	# Schedule the first long silence.
	_echo_timer.wait_time = randf_range(5.0, 15.0)
	_echo_timer.start()


func _on_echo_fragment() -> void:
	if _active_tool_id != "echo":
		return
	# Pick a random fragment (1–5). Play it if the file exists.
	# If no fragment files exist the timer still fires — the silence IS the texture.
	var n := randi_range(1, 5)
	var path := TOOLS_PATH + "echo_fragment_%d.ogg" % n
	if FileAccess.file_exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			_tool_player.stream = stream
			_tool_player.play()
	# Re-arm for the next silence interval.
	_echo_timer.wait_time = randf_range(5.0, 15.0)
	_echo_timer.start()


# ---------------------------------------------------------------------------
# Fade helpers
# ---------------------------------------------------------------------------

func _fade_out(player: AudioStreamPlayer, duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, duration)
	tween.tween_callback(player.stop)


func _fade_in(player: AudioStreamPlayer, duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, duration)


func _make_player(player_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	add_child(p)
	return p
