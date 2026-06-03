class_name IconMapper
# Item icon system. Icons resolve in this order:
#   1. a per-id PNG override under res://assets/sprites/items/[id].png (none yet)
#   2. a category sprite from the Kenney roguelike gear bank (see SpriteAtlas)
#   3. a colored category square (last-resort fallback)
# Drop modern PNGs into _ITEM_SPRITES to replace any placeholder per item.

const _ITEM_SPRITES: Dictionary = {
	# Per-item overrides, e.g.:
	# "pistol_9mm": "res://assets/sprites/items/pistol_9mm.png",
}

const _CATEGORY_COLORS: Dictionary = {
	"weapon":     Color(0.90, 0.38, 0.28),
	"armor":      Color(0.35, 0.58, 0.90),
	"consumable": Color(0.35, 0.82, 0.38),
	"misc":       Color(0.70, 0.68, 0.48),
	"__caps__":   Color(1.00, 0.82, 0.10),
}


static func get_icon(item_id: String, item_type: String = "") -> Texture2D:
	var path: String = _ITEM_SPRITES.get(item_id, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Per-item art dropped in as assets/sprites/items/<id>.svg|png (game-icons.net).
	for ext in [".svg", ".png"]:
		var p := "res://assets/sprites/items/%s%s" % [item_id, ext]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	if item_id == "__caps__":
		return SpriteAtlas.prop_tex("gold")
	var tex := SpriteAtlas.item_tex(item_type)
	if tex != null:
		return tex
	return null


static func get_category_color(item_type: String) -> Color:
	return _CATEGORY_COLORS.get(item_type, Color(0.55, 0.55, 0.55))


static func make_item_icon(item_id: String, item_type: String) -> Control:
	var tex := get_icon(item_id, item_type)
	if tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.custom_minimum_size = Vector2(24, 24)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return tex_rect
	var p := Panel.new()
	p.custom_minimum_size = Vector2(20, 20)
	var style := StyleBoxFlat.new()
	var col_key := item_id if _CATEGORY_COLORS.has(item_id) else item_type
	style.bg_color = _CATEGORY_COLORS.get(col_key, Color(0.55, 0.55, 0.55))
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	p.add_theme_stylebox_override("panel", style)
	return p
