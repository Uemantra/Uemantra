class_name ThemeBuilder
extends RefCounted

# Builds a Godot Theme object encoding the paper visual language.
# Load this once in the main scene and let it propagate to all children.
# The terminal theme is applied only to the Rig workshop panel, not globally.


static func build_paper_theme() -> Theme:
	var theme := Theme.new()

	# --- Label ---
	theme.set_color("font_color", "Label", Palette.INK_DARK)
	theme.set_font_size("font_size", "Label", Typography.BODY)

	# --- Button ---
	theme.set_stylebox("normal",   "Button", StyleBoxFactory.button_normal())
	theme.set_stylebox("hover",    "Button", StyleBoxFactory.button_hover())
	theme.set_stylebox("pressed",  "Button", StyleBoxFactory.button_pressed())
	theme.set_stylebox("disabled", "Button", _make_disabled_button())
	theme.set_color("font_color",          "Button", Palette.INK_DARK)
	theme.set_color("font_hover_color",    "Button", Palette.INK_DARK)
	theme.set_color("font_pressed_color",  "Button", Palette.INK_MID)
	theme.set_color("font_disabled_color", "Button", Palette.INK_FAINT)
	theme.set_font_size("font_size", "Button", Typography.BODY)

	# --- PanelContainer ---
	theme.set_stylebox("panel", "PanelContainer", StyleBoxFactory.paper_panel())

	# --- RichTextLabel (paper context — Catalogue entries, field notes) ---
	theme.set_color("default_color",    "RichTextLabel", Palette.INK_DARK)
	theme.set_color("selection_color",  "RichTextLabel", Palette.HIGHLIGHT_SOFT)
	theme.set_font_size("normal_font_size", "RichTextLabel", Typography.BODY)

	# --- TabContainer ---
	theme.set_color("font_selected_color",   "TabContainer", Palette.INK_DARK)
	theme.set_color("font_unselected_color", "TabContainer", Palette.INK_MID)
	theme.set_color("font_hovered_color",    "TabContainer", Palette.INK_MID)
	theme.set_stylebox("tab_selected",   "TabContainer", _make_tab_selected())
	theme.set_stylebox("tab_unselected", "TabContainer", _make_tab_unselected())
	theme.set_stylebox("panel",          "TabContainer", StyleBoxFactory.paper_panel())

	return theme


# Applied only to the Rig workshop panel via Panel.theme.
# Keeps the terminal style isolated — it must feel foreign.
static func build_terminal_theme() -> Theme:
	var theme := Theme.new()

	# --- RichTextLabel ---
	theme.set_color("default_color",   "RichTextLabel", Palette.TERMINAL_TEXT)
	theme.set_color("selection_color", "RichTextLabel", Palette.TERMINAL_DIM)
	theme.set_font_size("normal_font_size", "RichTextLabel", Typography.TERMINAL_OUTPUT)

	# --- Label ---
	theme.set_color("font_color", "Label", Palette.TERMINAL_TEXT)
	theme.set_font_size("font_size", "Label", Typography.TERMINAL_OUTPUT)

	# --- Button (terminal command buttons) ---
	theme.set_stylebox("normal",  "Button", _make_terminal_button_normal())
	theme.set_stylebox("hover",   "Button", _make_terminal_button_hover())
	theme.set_stylebox("pressed", "Button", _make_terminal_button_normal())
	theme.set_color("font_color",       "Button", Palette.TERMINAL_TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TERMINAL_CURSOR)
	theme.set_font_size("font_size",    "Button", Typography.TERMINAL_OUTPUT)

	# --- PanelContainer ---
	theme.set_stylebox("panel", "PanelContainer", StyleBoxFactory.terminal_panel())

	return theme


# --- Internal helpers ---

static func _make_disabled_button() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_CREAM
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_all(2)
	return sb


static func _make_tab_selected() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_CREAM
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_individual(2, 2, 0, 0)
	return sb


static func _make_tab_unselected() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_TAN
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_individual(2, 2, 0, 0)
	return sb


static func _make_terminal_button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.TERMINAL_BG
	sb.set_border_width_all(1)
	sb.border_color = Palette.TERMINAL_DIM
	sb.set_corner_radius_all(0)
	return sb


static func _make_terminal_button_hover() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.TERMINAL_DIM
	sb.set_border_width_all(1)
	sb.border_color = Palette.TERMINAL_TEXT
	sb.set_corner_radius_all(0)
	return sb
