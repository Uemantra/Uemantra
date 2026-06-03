extends Node
## Lightweight SFX/BGM player. SFX use a small pool of AudioStreamPlayers so
## overlapping sounds (e.g. two hits in quick succession) don't cut each other off.
## Sounds are the Kenney "Interface" + "Impact" CC0 packs under assets/audio/sfx —
## swap the files (same names) to re-skin the audio. Missing files are silently
## ignored so the game still runs before assets are imported.

const SFX := {
	"click":   "res://assets/audio/sfx/ui_click.ogg",
	"confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	"back":    "res://assets/audio/sfx/ui_back.ogg",
	"error":   "res://assets/audio/sfx/ui_error.ogg",
	"open":    "res://assets/audio/sfx/ui_open.ogg",
	"hit":     "res://assets/audio/sfx/hit.ogg",
	"hit_soft":"res://assets/audio/sfx/hit_soft.ogg",
	"miss":    "res://assets/audio/sfx/miss.ogg",
	"reload":  "res://assets/audio/sfx/reload.ogg",
	"death":   "res://assets/audio/sfx/death.ogg",
	"heal":    "res://assets/audio/sfx/heal.ogg",
	"step":    "res://assets/audio/sfx/step.ogg",
}

# Per-sound volume trim (dB) so loud impacts don't dominate soft UI ticks.
const SFX_DB := {
	"click": -8.0, "confirm": -6.0, "back": -8.0, "open": -8.0,
	"step": -14.0, "miss": -6.0,
}

const POOL_SIZE := 8

var _bgm: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play_sfx(sound_name: String) -> void:
	var path: String = SFX.get(sound_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path)
		_cache[path] = stream
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = SFX_DB.get(sound_name, 0.0)
	p.play()


func play_bgm(_track_name: String) -> void:
	pass  # No music tracks shipped yet; drop an .ogg here and load it when added.


func stop_bgm() -> void:
	if _bgm:
		_bgm.stop()
