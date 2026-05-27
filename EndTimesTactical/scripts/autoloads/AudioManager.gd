extends Node

@onready var _bgm: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _sfx: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(_bgm)
	add_child(_sfx)


func play_bgm(track_name: String) -> void:
	pass  # Wire up when audio assets are added


func play_sfx(sound_name: String) -> void:
	pass  # Wire up when audio assets are added


func stop_bgm() -> void:
	_bgm.stop()
