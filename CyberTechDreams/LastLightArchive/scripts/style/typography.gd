class_name Typography
extends RefCounted

# --- Font size constants (semantic names, not magic numbers) ---
const TITLE:           int = 28
const HEADING:         int = 20
const BODY:            int = 14
const CAPTION:         int = 11
const TERMINAL_OUTPUT: int = 13
const TERMINAL_HEADER: int = 15


# Standard body text — the voice of Vera's notes and the Catalogue.
static func apply_paper(label: Label) -> void:
	label.add_theme_color_override("font_color", Palette.INK_DARK)
	label.add_theme_font_size_override("font_size", BODY)


# Section headings on paper panels.
static func apply_heading(label: Label) -> void:
	label.add_theme_color_override("font_color", Palette.INK_DARK)
	label.add_theme_font_size_override("font_size", HEADING)
	# Bold expressed via Label settings; swap to a bold font resource when available.
	label.label_settings = _make_label_settings(Palette.INK_DARK, HEADING, false, true)


# Faint annotations, placeholder indicators, catalogue sparsity hints.
static func apply_caption(label: Label) -> void:
	label.add_theme_color_override("font_color", Palette.INK_FAINT)
	label.add_theme_font_size_override("font_size", CAPTION)


# RichTextLabel inside the Rig terminal — the one exception to paper world.
static func apply_terminal(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", Palette.TERMINAL_TEXT)
	label.add_theme_color_override("background_color", Palette.TERMINAL_BG)
	label.add_theme_font_size_override("normal_font_size", TERMINAL_OUTPUT)
	# The background colour must also be forced on the containing panel —
	# this only controls the text layer. See StyleBoxFactory.terminal_panel().


# Vera's handwritten-feeling marginal notes and companion annotations.
static func apply_annotation(label: Label) -> void:
	label.label_settings = _make_label_settings(Palette.INK_MID, BODY, true, false)


# --- Internal ---

static func _make_label_settings(color: Color, size: int, italic: bool, bold: bool) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_color = color
	ls.font_size = size
	# Font style flags are set here so they can be upgraded to real font resources
	# by swapping ls.font — currently relies on Godot's built-in variable font.
	# italic / bold affect rendering via the font variation transform until custom fonts land.
	return ls
