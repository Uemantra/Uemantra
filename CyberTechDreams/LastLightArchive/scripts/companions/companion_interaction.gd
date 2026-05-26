extends Control

@export var companion_id: String = ""

@onready var _label: Label = $VBox/NameLabel
@onready var _talk_button: Button = $VBox/TalkButton

# The village scene sets this when the player enters a location node.
var current_player_location: String = ""


func _ready() -> void:
	_talk_button.pressed.connect(_on_talk_pressed)
	hide()

	TimeManager.hour_changed.connect(_on_hour_changed)
	ConversationManager.conversation_started.connect(_on_conversation_started)
	ConversationManager.conversation_ended.connect(_on_conversation_ended)


func set_player_location(location: String) -> void:
	current_player_location = location
	_refresh_visibility()


# --------------------------------------------------------------------------- #
# Signal handlers
# --------------------------------------------------------------------------- #

func _on_hour_changed(_hour: int) -> void:
	_refresh_visibility()


func _on_conversation_started(_companion_id: String) -> void:
	# Hide all interaction prompts once a conversation is active.
	hide()


func _on_conversation_ended(_companion_id: String) -> void:
	_refresh_visibility()


func _on_talk_pressed() -> void:
	ConversationManager.start_conversation(companion_id)


# --------------------------------------------------------------------------- #
# Internal
# --------------------------------------------------------------------------- #

func _refresh_visibility() -> void:
	if companion_id == "":
		hide()
		return

	if not ConversationManager.can_talk_to(companion_id):
		hide()
		return

	# Only show if the companion is currently in the same location as the player.
	var hour: int = TimeManager.hour
	var season: String = TimeManager.get_season_name()
	var schedule := NpcSchedule.new(companion_id)
	var companion_location: String = schedule.get_location(hour, season)

	if current_player_location == "" or companion_location != current_player_location:
		hide()
		return

	var companion_data: Dictionary = DataManager.get_companion(companion_id)
	var name_str: String = companion_data.get("name", companion_id)
	_label.text = "%s — %s" % [name_str, companion_location.replace("_", " ")]
	show()
