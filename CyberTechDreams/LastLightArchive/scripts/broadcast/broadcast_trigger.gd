extends Control

@onready var _description_label: Label = $VBox/DescriptionLabel
@onready var _begin_button: Button = $VBox/BeginButton
@onready var _not_yet_button: Button = $VBox/NotYetButton
@onready var _complete_label: Label = $VBox/CompleteLabel


func _ready() -> void:
	_begin_button.pressed.connect(_on_begin_pressed)
	_not_yet_button.pressed.connect(_on_not_yet_pressed)
	_refresh_state()


func _refresh_state() -> void:
	var broadcast_complete: bool = GameState.get_flag("broadcast_complete", false)
	var broadcast_initiated: bool = GameState.get_flag("broadcast_initiated", false)

	if broadcast_complete:
		_description_label.hide()
		_begin_button.hide()
		_not_yet_button.hide()
		_complete_label.show()
		return

	_complete_label.hide()
	_description_label.show()
	_not_yet_button.show()

	var can_begin: bool = BroadcastManager.can_initiate() and not broadcast_initiated
	_begin_button.visible = can_begin


func _on_begin_pressed() -> void:
	BroadcastManager.initiate_broadcast()
	# Transition to the machines_said_choice scene.
	var choice_scene: PackedScene = load("res://scenes/broadcast/machines_said_choice.tscn")
	get_tree().change_scene_to_packed(choice_scene)


func _on_not_yet_pressed() -> void:
	# Return to the village. The game waits.
	var village_scene: PackedScene = load("res://scenes/village/village.tscn")
	get_tree().change_scene_to_packed(village_scene)
