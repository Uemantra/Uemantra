class_name SpriteAtlas
# Central sprite lookup for the two Kenney "Roguelike/RPG" CC0 sheets that ship
# in res://assets/sprites/roguelike. Both sheets are 16×16 tiles with a 1px margin
# (stride 17). Coordinates below are (column, row) on each sheet and were picked by
# eye for this game's wasteland theme — swap the numbers to re-skin without touching
# any scene code. If a sheet is missing the helpers return null so callers can fall
# back to the old colored-shape rendering.
#
#   roguelikeChar_transparent.png  — characters (cols 0-1) + gear/weapons (cols 33+)
#   roguelikeSheet_transparent.png — environment: trees, barrels, crates, chests…

const CHAR_SHEET := "res://assets/sprites/roguelike/roguelikeChar_transparent.png"
const ENV_SHEET  := "res://assets/sprites/roguelike/roguelikeSheet_transparent.png"

const TILE   := 16
const STRIDE := 17   # 16px tile + 1px margin

# ─── Character sheet cells (col, row) — full standalone figures live in cols 0-1 ──
const ROLE_CELLS := {
	"player":  Vector2i(0, 8),   # bald wastelander in an orange jumpsuit
	"npc":     Vector2i(0, 7),   # plain villager
	"elder":   Vector2i(1, 5),   # white-haired robed elder
	"woman":   Vector2i(0, 5),   # blonde villager
	"enemy":   Vector2i(1, 8),   # bare-chested raider/brawler
	"raider":  Vector2i(1, 8),
	"mutant":  Vector2i(0, 3),   # green creature
	"robed":   Vector2i(1, 11),  # white-robed figure
}

# ─── Item icons by category (char sheet gear bank) ───────────────────────────────
const ITEM_CELLS := {
	"weapon":     Vector2i(44, 6),   # steel sword
	"armor":      Vector2i(38, 2),   # metal shield
	"consumable": Vector2i(37, 4),   # red potion / stim
	"misc":       Vector2i(34, 4),   # flask / sundry
}

# ─── Environment props (env sheet) ───────────────────────────────────────────────
const ENV_CELLS := {
	"cactus":    Vector2i(22, 9),
	"dead_tree": Vector2i(27, 9),
	"barrel":    Vector2i(26, 0),
	"crate":     Vector2i(27, 1),
	"chest":     Vector2i(38, 10),
	"sign":      Vector2i(19, 0),
	"gold":      Vector2i(36, 9),
	"gem":       Vector2i(35, 9),
}

static var _char_tex: Texture2D
static var _env_tex:  Texture2D


static func _sheet(path: String, cache: int) -> Texture2D:
	# cache: 0 = char, 1 = env
	if cache == 0:
		if _char_tex == null and ResourceLoader.exists(path):
			_char_tex = load(path) as Texture2D
		return _char_tex
	if _env_tex == null and ResourceLoader.exists(path):
		_env_tex = load(path) as Texture2D
	return _env_tex


static func _atlas(sheet: Texture2D, cell: Vector2i) -> AtlasTexture:
	if sheet == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(cell.x * STRIDE, cell.y * STRIDE, TILE, TILE)
	a.filter_clip = true
	return a


static func char_tex(cell: Vector2i) -> AtlasTexture:
	return _atlas(_sheet(CHAR_SHEET, 0), cell)


static func env_tex(cell: Vector2i) -> AtlasTexture:
	return _atlas(_sheet(ENV_SHEET, 1), cell)


# ─── Named lookups (return AtlasTexture or null) ─────────────────────────────────

static func actor_tex(role: String) -> AtlasTexture:
	if not ROLE_CELLS.has(role):
		return null
	return char_tex(ROLE_CELLS[role])


static func item_tex(category: String) -> AtlasTexture:
	if not ITEM_CELLS.has(category):
		return null
	return char_tex(ITEM_CELLS[category])


static func prop_tex(name: String) -> AtlasTexture:
	if not ENV_CELLS.has(name):
		return null
	return env_tex(ENV_CELLS[name])


# Build a centered Sprite2D scaled so the 16px tile renders at `target_px` tall.
# `lift` nudges it up so figures/props stand on the hex instead of floating centred.
static func make_sprite(tex: Texture2D, target_px: float = 28.0, lift: float = 0.0,
		z: int = 1) -> Sprite2D:
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * (target_px / float(TILE))
	s.position = Vector2(0.0, -lift)
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
