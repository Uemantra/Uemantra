extends Control

# Fallout-style epilogue: plays the ending slides whose conditions the player's final game
# state satisfies, one at a time, then returns to the main menu. Slides are authored in
# campaigns/<id>/endings/endings.json (see docs/SCHEMA.md). A slide with "always": true
# always shows; otherwise it shows when ConditionChecker.check_conditions passes (flags,
# karma, faction rep). This scene is a bare scripted root — all UI is built here in code.

var _slides: Array = []
var _index: int = 0

var _title_lbl: Label
var _body_lbl: RichTextLabel
var _footer_lbl: Label
var _next_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_slides = _collect_slides()
	GameState.pending_ending = ""   # consumed

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 160)
	margin.add_theme_constant_override("margin_right", 160)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var heading := Label.new()
	heading.text = "EPILOGUE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.modulate = Color(0.78, 0.66, 0.30)
	vbox.add_child(heading)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 40)
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_lbl)

	_body_lbl = RichTextLabel.new()
	_body_lbl.bbcode_enabled = true
	_body_lbl.fit_content = true
	_body_lbl.scroll_active = false
	_body_lbl.custom_minimum_size = Vector2(0, 280)
	_body_lbl.add_theme_font_size_override("normal_font_size", 22)
	vbox.add_child(_body_lbl)

	_footer_lbl = Label.new()
	_footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_lbl.add_theme_font_size_override("font_size", 18)
	_footer_lbl.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(_footer_lbl)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(280, 48)
	_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_btn.pressed.connect(_advance)
	vbox.add_child(_next_btn)

	_show_slide()


# Slides whose conditions the final game state satisfies (in authored order).
func _collect_slides() -> Array:
	var data := DataManager.get_endings()
	var out: Array = []
	for slide: Dictionary in data.get("slides", []):
		if slide.get("always", false) or ConditionChecker.check_conditions(slide.get("conditions", {})):
			out.append(slide)
	if out.is_empty():
		out.append({
			"title": "The Wasteland Endures",
			"text": "Your story here comes to a close. What happens next is for the next traveller to write.",
		})
	return out


func _show_slide() -> void:
	var slide: Dictionary = _slides[_index]
	_title_lbl.text = slide.get("title", "")
	_body_lbl.text = slide.get("text", "")
	_footer_lbl.text = "Karma: %s    (slide %d of %d)" % [GameState.get_karma_title(), _index + 1, _slides.size()]
	_next_btn.text = "Continue" if _index < _slides.size() - 1 else "Return to Main Menu"
	AudioManager.play_sfx("open")


func _advance() -> void:
	AudioManager.play_sfx("confirm")
	_index += 1
	if _index >= _slides.size():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		_show_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_advance()
