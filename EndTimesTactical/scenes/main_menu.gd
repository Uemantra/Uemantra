extends Control

@onready var _new_game_btn: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var _continue_btn: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var _quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	_continue_btn.disabled = not SaveManager.has_save()
	_new_game_btn.pressed.connect(_on_new_game)
	_continue_btn.pressed.connect(_on_continue)
	_quit_btn.pressed.connect(get_tree().quit)


func _on_new_game() -> void:
	AudioManager.play_sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/character_creator/character_creator.tscn")


func _on_continue() -> void:
	AudioManager.play_sfx("confirm")
	if SaveManager.load_save():
		get_tree().change_scene_to_file("res://scenes/world/worldmap.tscn")
