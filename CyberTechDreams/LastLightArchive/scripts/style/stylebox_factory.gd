class_name StyleBoxFactory
extends RefCounted

# --- Paper world panels ---

# General-purpose panel: notebook pages, sidebar, card lists.
static func paper_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_TAN
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb


# Individual cards within a panel (relic cards, catalogue entries).
static func card_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_CREAM
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb


# Theory Board background — rough, no radius, heavier border for corkboard feel.
static func corkboard_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CORKBOARD
	sb.set_border_width_all(2)
	sb.border_color = Palette.INK_DARK
	sb.set_corner_radius_all(0)
	return sb


# Rig terminal panel — the one hard-edged, dark surface in the entire game.
static func terminal_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.TERMINAL_BG
	sb.set_border_width_all(1)
	sb.border_color = Palette.TERMINAL_DIM
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(8)
	return sb


# --- Button states ---

static func button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_TAN
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_all(2)
	return sb


static func button_hover() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.HIGHLIGHT_SOFT
	sb.set_border_width_all(1)
	sb.border_color = Palette.PAPER_SHADOW
	sb.set_corner_radius_all(2)
	return sb


static func button_pressed() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_SHADOW
	sb.set_border_width_all(1)
	sb.border_color = Palette.INK_MID
	sb.set_corner_radius_all(2)
	return sb
