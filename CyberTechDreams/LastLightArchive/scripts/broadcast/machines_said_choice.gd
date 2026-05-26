extends Control

@onready var _include_all_button: Button = $VBox/IncludeAllButton
@onready var _include_verified_button: Button = $VBox/IncludeVerifiedButton
@onready var _leave_out_button: Button = $VBox/LeaveOutButton


func _ready() -> void:
	_include_all_button.pressed.connect(_on_include_all_pressed)
	_include_verified_button.pressed.connect(_on_include_verified_pressed)
	_leave_out_button.pressed.connect(_on_leave_out_pressed)


func _on_include_all_pressed() -> void:
	_proceed("full")


func _on_include_verified_pressed() -> void:
	_proceed("curated")


func _on_leave_out_pressed() -> void:
	_proceed("none")


func _proceed(choice: String) -> void:
	BroadcastManager.set_machines_said_choice(choice)
	var sequence_scene: PackedScene = load("res://scenes/broadcast/broadcast_sequence.tscn")
	get_tree().change_scene_to_packed(sequence_scene)
