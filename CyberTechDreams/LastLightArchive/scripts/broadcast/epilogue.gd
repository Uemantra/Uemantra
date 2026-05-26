extends Control

# Panel colors.
const COLOR_SEPIA_WARM: Color = Color(0.831, 0.769, 0.627, 1.0)       # #D4C4A0
const COLOR_SEPIA_COOL: Color = Color(0.784, 0.741, 0.659, 1.0)       # #C8BDA8
const COLOR_NEAR_BLACK: Color = Color(0.102, 0.094, 0.078, 1.0)       # #1A1814

const FADE_DURATION: float = 0.5

@onready var _panel_bg: ColorRect = $PanelBg
@onready var _narration_label: RichTextLabel = $NarrationLabel
@onready var _advance_button: Button = $AdvanceButton
@onready var _menu_button: Button = $MenuButton

var _subtitles: Dictionary = {}
var _stages: Array = []
var _current_stage: int = 0
var _tween: Tween


func _ready() -> void:
	_advance_button.pressed.connect(_on_advance_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.hide()
	_narration_label.modulate.a = 0.0

	_subtitles = _load_subtitles()
	_build_stages()
	_show_stage(_current_stage)


func _input(event: InputEvent) -> void:
	if _menu_button.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_advance_pressed()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- #
# Stage construction
# --------------------------------------------------------------------------- #

func _build_stages() -> void:
	_stages.clear()

	var theory_id: String = BroadcastManager.get_dominant_theory()
	var subtitle: String = _subtitles.get(theory_id, "")

	# Opening subtitle if present.
	if subtitle != "":
		_stages.append({
			"type": "subtitle",
			"text": "[i]%s[/i]" % subtitle,
			"bg_color": COLOR_SEPIA_WARM,
		})

	# Catalogue entry panels — Vera reads each one.
	var entry_ids: Array = BroadcastManager.get_epilogue_entries()
	for entry_id in entry_ids:
		var entry: Dictionary = CatalogueManager.get_entry(entry_id)
		var content: String = entry.get("content", "")
		var vera_note: String = entry.get("vera_note", "")
		var display_text: String
		if vera_note != "":
			display_text = "%s\n\n[i]%s[/i]" % [content, vera_note]
		else:
			display_text = content
		_stages.append({
			"type": "entry",
			"text": display_text,
			"bg_color": COLOR_SEPIA_WARM,
		})

	# Companion cards.
	var cards: Array = BroadcastManager.get_companion_cards()
	for card in cards:
		var companion_data: Dictionary = DataManager.companions_data.get(card["companion_id"], {})
		var name_str: String = companion_data.get("name", card["companion_id"])
		var card_text: String = "[b]%s[/b]\n%s" % [name_str, card["card_text"]]
		_stages.append({
			"type": "companion_card",
			"text": card_text,
			"bg_color": COLOR_SEPIA_COOL,
		})

	# Final card — always the same.
	_stages.append({
		"type": "final_card",
		"text": "[i]\"The signal traveled. We do not know who heard it. We do not know if anyone did. We do not know if 'anyone' is the right word.\"[/i]",
		"bg_color": COLOR_NEAR_BLACK,
	})

	# Machines said postscript.
	var choice: String = GameState.get_flag("machines_said_choice", "none")
	var postscript: String
	match choice:
		"full":
			postscript = "[i]\"We let them speak too. It was the least we could do.\"[/i]"
		"none":
			postscript = "[i]\"Their words remained ours. For now.\"[/i]"
		"curated":
			postscript = "[i]\"I chose what I could verify. The rest is in the notebook, for whoever comes next.\"[/i]"
		_:
			postscript = "[i]\"Their words remained ours. For now.\"[/i]"
	_stages.append({
		"type": "postscript",
		"text": postscript,
		"bg_color": COLOR_NEAR_BLACK,
	})

	# End stage — fade to black, show menu button.
	_stages.append({
		"type": "end",
		"text": "",
		"bg_color": COLOR_NEAR_BLACK,
	})


# --------------------------------------------------------------------------- #
# Stage display
# --------------------------------------------------------------------------- #

func _show_stage(index: int) -> void:
	if index >= _stages.size():
		_end_game()
		return

	var stage: Dictionary = _stages[index]
	var stage_type: String = stage.get("type", "entry")
	var text: String = stage.get("text", "")
	var bg_color: Color = stage.get("bg_color", COLOR_SEPIA_WARM)

	_panel_bg.color = bg_color

	if stage_type == "end":
		_end_game()
		return

	var is_dark: bool = (bg_color == COLOR_NEAR_BLACK)
	if is_dark:
		_narration_label.add_theme_color_override("default_color", Color(0.92, 0.88, 0.80, 1.0))
	else:
		_narration_label.add_theme_color_override("default_color", Color(0.10, 0.07, 0.04, 1.0))

	_narration_label.bbcode_enabled = true
	_narration_label.text = text

	_advance_button.show()
	_menu_button.hide()
	_fade_in_narration()


func _fade_in_narration() -> void:
	if _tween:
		_tween.kill()
	_narration_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_narration_label, "modulate:a", 1.0, FADE_DURATION)


func _end_game() -> void:
	_advance_button.hide()
	_narration_label.text = ""
	_panel_bg.color = COLOR_NEAR_BLACK

	if _tween:
		_tween.kill()
	# Fade to black, then show menu button.
	_tween = create_tween()
	_tween.tween_property(_panel_bg, "color", Color(0.0, 0.0, 0.0, 1.0), 1.5)
	_tween.tween_callback(func() -> void:
		_menu_button.show()
	)


func _on_advance_pressed() -> void:
	_current_stage += 1
	_show_stage(_current_stage)


func _on_menu_pressed() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	get_tree().change_scene_to_packed(main_scene)


# --------------------------------------------------------------------------- #
# Data loading
# --------------------------------------------------------------------------- #

func _load_subtitles() -> Dictionary:
	var path: String = "res://data/broadcast/epilogue_theory_subtitles.json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
