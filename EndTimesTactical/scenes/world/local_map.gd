extends Node2D
## Unified Fallout-style local map.
##
## ONE isometric hex grid is used for BOTH free-roam exploration AND turn-based
## combat. In EXPLORE mode the player walks the map in real time (talk, loot,
## examine, leave). The instant a fight starts — the player attacks an enemy, or
## an enemy spots the player — the SAME map freezes into COMBAT mode with everyone
## where they stood (CombatManager drives the turn loop). When combat ends the map
## thaws back to EXPLORE. No separate battle arena, no grid mismatch.
##
## The scene builds all of its nodes and UI in code, so the .tscn is just a bare
## scripted root. Map content is authored as hex data in data/local_maps/*.json.

# ─── Modes ──────────────────────────────────────────────────────────────────────
enum Mode { EXPLORE, COMBAT }
enum Aim  { NONE, MOVE, QUICK, AIMED, BURST, MELEE }

var _mode: Mode = Mode.EXPLORE
var _aim:  Aim  = Aim.NONE
var _called_shot_menu: Control = null

# ─── Tunables ───────────────────────────────────────────────────────────────────
const MOVE_STEP_TIME   := 0.12   # seconds to walk one hex while exploring
const DETECT_RADIUS    := 4      # hexes — enemies this close (with LOS) start a fight
const FLEE_SAFE_RADIUS := DETECT_RADIUS  # may disengage once every enemy is farther than this
const CAMERA_ZOOM      := 1.3    # lower zoom: the larger hexes already read big, so show more map
const SEE_THROUGH_RADIUS := 2    # tall scenery this close & in front of the player turns translucent
const OCCLUDER_ALPHA   := 0.32   # how see-through a wall/structure becomes when it would hide the player

# ─── Palette (shared by explore + combat so the look is continuous) ─────────────
const COLORS := {
	"floor":         Color(0.22, 0.20, 0.16),
	"floor_alt":     Color(0.18, 0.17, 0.14),
	"obstacle":      Color(0.30, 0.27, 0.20),
	"cover_partial": Color(0.16, 0.27, 0.16),
	"cover_full":    Color(0.10, 0.22, 0.10),
	"border":        Color(0.04, 0.04, 0.035),
	"move_hi":       Color(0.12, 0.40, 0.75, 0.92),
	"attack_hi":     Color(0.75, 0.12, 0.12, 0.92),
	"range_ring":    Color(0.62, 0.30, 0.04, 0.55),
	"active_unit":   Color(0.82, 0.70, 0.08, 0.75),
}
const ACTOR_COLORS := {
	"npc":       Color(0.30, 0.58, 1.0),
	"enemy":     Color(0.82, 0.22, 0.14),
	"container": Color(0.70, 0.62, 0.27),
	"examine":   Color(0.62, 0.62, 0.55),
}

const FOG_HIDDEN   := Color(0.0, 0.0, 0.0, 1.0)      # never seen — drawn black
const FOG_EXPLORED := Color(0.45, 0.45, 0.45, 1.0)   # seen before, not in view
const FOG_VISIBLE  := Color(1.0, 1.0, 1.0, 1.0)

const BAR_W := 30.0
const BAR_H := 5.0

# Per-terrain ground styling. "tex" picks which Kenney floor swatch to clip into the
# hex ("a" open ground, "b" rust clay, "none" = solid colour only). "tint" modulates
# that swatch; "solid" is the fallback colour when the swatches aren't imported.
const TERRAIN_VIS := {
	"floor":         { "tex": "a", "tint": Color(1, 1, 1),          "solid": Color(0.22, 0.20, 0.16) },
	"road":          { "tex": "b", "tint": Color(0.74, 0.72, 0.70), "solid": Color(0.27, 0.26, 0.24) },
	"grass":         { "tex": "a", "tint": Color(0.58, 0.78, 0.46), "solid": Color(0.20, 0.32, 0.16) },
	"interior":      { "tex": "b", "tint": Color(0.82, 0.80, 0.88), "solid": Color(0.26, 0.25, 0.30) },
	"rubble":        { "tex": "b", "tint": Color(0.80, 0.76, 0.70), "solid": Color(0.30, 0.28, 0.24) },
	"cover_partial": { "tex": "b", "tint": Color(0.94, 0.92, 0.88), "solid": Color(0.16, 0.27, 0.16) },
	"cover_full":    { "tex": "b", "tint": Color(0.94, 0.92, 0.88), "solid": Color(0.10, 0.22, 0.10) },
	"obstacle":      { "tex": "b", "tint": Color(0.86, 0.84, 0.80), "solid": Color(0.30, 0.27, 0.20) },
	"wall":          { "tex": "b", "tint": Color(0.62, 0.60, 0.56), "solid": Color(0.24, 0.22, 0.19) },
	"water":         { "tex": "none", "tint": Color(0.24, 0.36, 0.48), "solid": Color(0.18, 0.30, 0.42) },
}

# ─── Layers / nodes (built in _ready) ───────────────────────────────────────────
var _cam:          Camera2D
var _hex_layer:    Node2D                       # per-hex visual containers
var _actors_layer: Node2D
var _player:       Node2D
var _ui:           CanvasLayer

# ─── Map state ──────────────────────────────────────────────────────────────────
var _map_id:    String     = ""
var _map_data:  Dictionary = {}
var _terrain:   Dictionary = {}                 # Vector2i -> terrain String (the live grid)
var _width:     int        = 0
var _height:    int        = 0
var _is_encounter: bool    = false              # random-encounter map (return to worldmap after)

var _hex_nodes:   Dictionary = {}               # Vector2i -> Node2D (floor tile + border + flat decor)
var _tile_polys:  Dictionary = {}               # Vector2i -> Polygon2D (recoloured for highlights)
var _decor_by_hex: Dictionary = {}              # Vector2i -> Array[Node2D] standing decor/props in the sort layer
var _vis:         Dictionary = {}               # Vector2i -> 0 hidden / 1 explored / 2 visible

# Actors (NPCs, enemies, containers, examine spots)
var _actor_data:  Dictionary = {}               # actor_id -> data dict (+ _atype)
var _actor_nodes: Dictionary = {}               # actor_id -> Node2D
var _actor_hex:   Dictionary = {}               # Vector2i -> actor_id

var _player_hex:  Vector2i = Vector2i(0, 0)
var _moving:      bool     = false

# ─── Combat view state ──────────────────────────────────────────────────────────
var _hp_bars:    Dictionary = {}                # unit_id -> Polygon2D (fill)
var _reachable:  Dictionary = {}                # Vector2i -> ap cost
var _targetable: Array      = []
var _combat_won: bool       = false

# ─── Overlay panels ─────────────────────────────────────────────────────────────
var _dialogue_box:    Control = null
var _loot_panel_node: Control = null
var _shop_panel_node: Control = null
var _overlay_stack: Array = []          # char/inventory/journal panels, for Escape-to-close

# Explore HUD
var _loc_label:    Label
var _time_label:   Label
var _examine_panel: PanelContainer
var _examine_title: Label
var _examine_text:  RichTextLabel
var _examine_skill_btn: Button
var _examine_skill_ctx: Dictionary = {}   # { skill_use: Dictionary } for the open object
var _daynight: CanvasModulate             # tints the world by time of day
var _explore_bar:   Control

# Combat HUD
var _combat_hud:   Control
var _status_lbl:   Label
var _ap_lbl:       Label
var _hp_lbl:       Label
var _weapon_lbl:   Label
var _turn_list:    VBoxContainer
var _log_box:      RichTextLabel
var _mode_lbl:     Label
var _move_btn:     Button
var _quick_btn:    Button
var _aimed_btn:    Button
var _burst_btn:    Button
var _reload_btn:   Button
var _item_btn:     Button
var _melee_btn:    Button
var _end_btn:      Button
var _flee_btn:     Button


# ════════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ════════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_layers()
	_load_map()
	_build_tiles()
	_spawn_props()
	_spawn_actors()
	_spawn_player()
	_setup_camera()
	_build_explore_hud()
	_build_combat_hud()
	_instantiate_overlays()
	_connect_combat_signals()
	if not GameState.leveled_up.is_connected(_on_leveled_up):
		GameState.leveled_up.connect(_on_leveled_up)
	_recompute_fog()
	_refresh_explore_hud()
	_apply_daynight()

	# Combat is in-place now; keep any legacy pending state clean.
	GameState.pending_combat = {}
	GameState.pending_combat_enemies = []

	# A random encounter map drops you straight into the fight.
	if _is_encounter:
		call_deferred("_enter_combat")


func _build_layers() -> void:
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed   = 8.0
	_cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(_cam)

	_hex_layer = Node2D.new()
	_hex_layer.z_index = 0          # flat ground only — always behind everything
	add_child(_hex_layer)

	# ONE Y-sorted layer holds every "standing" thing — walls, tall cover, props,
	# NPCs, enemies AND the player — so draw order follows depth (a unit north of a
	# wall is drawn first and the wall covers it; a unit south of it draws on top).
	# For Y to be the deciding factor, all children share the same z_index.
	_actors_layer = Node2D.new()
	_actors_layer.z_index = 1
	_actors_layer.y_sort_enabled = true
	add_child(_actors_layer)

	_player = Node2D.new()          # lives in the sort layer; no z_index override
	_actors_layer.add_child(_player)

	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)


func _load_map() -> void:
	# A pending encounter (from the world map) takes priority over the location map.
	if not GameState.pending_encounter.is_empty():
		_is_encounter = true
		_map_data = GameState.pending_encounter
		_map_id   = _map_data.get("id", "encounter")
		GameState.pending_encounter = {}
	else:
		_is_encounter = false
		var loc := DataManager.get_location(GameState.current_location)
		_map_id = loc.get("local_map", GameState.current_location + "_map")
		_map_data = DataManager.get_local_map(_map_id)

	_width  = _map_data.get("width", 16)
	_height = _map_data.get("height", 12)
	_terrain = _parse_terrain(_map_data)

	# Restore fog + dead actors from the saved exploration state.
	var state := GameState.get_exploration_state(_map_id)
	for cell in state.get("explored_tiles", []):
		_vis[cell] = 1


# Authored terrain is a list of equal-length strings, one per row (r). Each char
# is one hex at column q; the char→terrain mapping lives in TerrainDB (`.` floor,
# `#` obstacle, `o`/`O` cover, `W` wall, `r` road, `g` grass, `~` water, `_`
# interior, `+` rubble). A space ' ' means "no hex here" (void). Falls back to an
# open rectangle if no terrain is supplied.
func _parse_terrain(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var rows: Array = data.get("terrain", [])
	if rows.is_empty():
		for r in _height:
			for q in _width:
				out[Vector2i(q, r)] = "floor"
		return out
	for r in rows.size():
		var line: String = rows[r]
		for q in line.length():
			if line[q] == " ":
				continue
			out[Vector2i(q, r)] = TerrainDB.from_char(line[q])
	return out


# ════════════════════════════════════════════════════════════════════════════════
# Tile rendering  (isometric flat-top hexes, identical geometry to combat)
# ════════════════════════════════════════════════════════════════════════════════

func _build_tiles() -> void:
	for hex: Vector2i in _terrain:
		var terrain: String = _terrain[hex]
		var centre := HexGrid.hex_to_pixel(hex)
		var corners := HexGrid.hex_corners(Vector2.ZERO)

		var container := Node2D.new()
		container.position = centre

		var poly := Polygon2D.new()
		poly.polygon = corners
		var ground := _floor_texture(terrain)
		if ground:
			poly.texture = ground
			poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			poly.texture_offset = Vector2(ground.get_width() * 0.5, ground.get_height() * 0.5)
		poly.color   = _base_color(terrain, hex)
		container.add_child(poly)
		_tile_polys[hex] = poly

		var border := Line2D.new()
		for c in corners:
			border.add_point(c)
		border.add_point(corners[0])
		border.default_color = COLORS["border"]
		border.width = 0.8
		container.add_child(border)

		_add_flat_decor(container, terrain)
		_hex_layer.add_child(container)
		_hex_nodes[hex] = container

		# Standing terrain (walls, tall cover, obstacles) lives in the Y-sorted layer
		# so it can correctly occlude units that walk behind it.
		var standing := _make_standing_decor(terrain)
		if standing:
			standing.position = centre
			standing.set_meta("tall", _TERRAIN_TALL.has(terrain))
			_actors_layer.add_child(standing)
			_register_decor(hex, standing)


func _register_decor(hex: Vector2i, node: Node2D) -> void:
	if not _decor_by_hex.has(hex):
		_decor_by_hex[hex] = []
	_decor_by_hex[hex].append(node)


# Kenney Hexagon Pack ground swatches (tan hardpan + rust clay). Clipped into the
# existing hex polygons so tessellation and the highlight system are untouched.
const _FLOOR_A := "res://assets/sprites/hex_terrain/floor_a.png"   # open ground
const _FLOOR_B := "res://assets/sprites/hex_terrain/floor_b.png"   # under obstacles/cover
var _floor_a_tex: Texture2D
var _floor_b_tex: Texture2D
var _floor_loaded: bool = false


func _ensure_floor_textures() -> void:
	if _floor_loaded:
		return
	_floor_loaded = true
	if ResourceLoader.exists(_FLOOR_A):
		_floor_a_tex = load(_FLOOR_A)
	if ResourceLoader.exists(_FLOOR_B):
		_floor_b_tex = load(_FLOOR_B)


func _floor_texture(terrain: String) -> Texture2D:
	_ensure_floor_textures()
	var vis: Dictionary = TERRAIN_VIS.get(terrain, TERRAIN_VIS["floor"])
	match vis.get("tex", "a"):
		"a":  return _floor_a_tex
		"b":  return _floor_b_tex
		_:    return null   # "none" (e.g. water) — solid colour only


func _base_color(terrain: String, hex: Vector2i) -> Color:
	# With ground textures present the polygon colour is just a light modulate; a
	# subtle checker keeps big open floors from looking flat. Falls back to the solid
	# colours if the swatches aren't imported.
	var vis: Dictionary = TERRAIN_VIS.get(terrain, TERRAIN_VIS["floor"])
	var open := terrain == "floor" or terrain == "grass" or terrain == "road"
	if _floor_a_tex == null and _floor_b_tex == null:
		var solid: Color = vis["solid"]
		return (solid if (hex.x + hex.y) % 2 == 0 else solid.darkened(0.12)) if open else solid
	var tint: Color = vis["tint"]
	return (tint if (hex.x + hex.y) % 2 == 0 else tint.darkened(0.08)) if open else tint


const _DECOR_PROPS := {
	"obstacle":      "cactus",   # blocks line of sight
	"cover_partial": "barrel",
	"cover_full":    "crate",
}

# Terrain / props tall enough to hide the player — these turn translucent when the
# player would be standing behind them (see _update_occluders).
const _TERRAIN_TALL := { "wall": true, "obstacle": true, "cover_full": true }
const _PROP_TALL := {
	"shack": true, "house": true, "building": true, "hut": true,
	"wreck": true, "car": true, "vehicle": true, "tent": true,
	"tree": true, "dead_tree": true, "generator": true, "machine": true,
}


# Flat, ground-hugging decor stays in the hex container under the units.
func _add_flat_decor(container: Node2D, terrain: String) -> void:
	match terrain:
		"water":  _decor_water(container)
		"rubble": _decor_rubble(container)


# Standing decor (returned as a node placed in the Y-sorted layer), or null.
func _make_standing_decor(terrain: String) -> Node2D:
	match terrain:
		"wall":
			var n := Node2D.new(); _decor_wall(n); return n
		"obstacle", "cover_partial", "cover_full":
			var n := Node2D.new()
			var lift := 11.0 if terrain == "obstacle" else 6.0
			var size := 42.0 if terrain == "obstacle" else 34.0
			var prop := SpriteAtlas.make_sprite(SpriteAtlas.prop_tex(_DECOR_PROPS[terrain]), size, lift, 1)
			if prop:
				n.add_child(prop)
			else:
				_decor_shape_fallback(n, terrain)
			return n
	return null


# Hand-drawn polygon shapes used when the sprite sheet is unavailable.
func _decor_shape_fallback(container: Node2D, terrain: String) -> void:
	var s  := HexGrid.HEX_SIZE
	var sq := HexGrid.ISO_SQUASH
	match terrain:
		"obstacle":
			var pts := PackedVector2Array([
				Vector2(-s*0.38, -sq*s*0.08), Vector2(-s*0.20, -sq*s*0.30),
				Vector2( s*0.05, -sq*s*0.24), Vector2( s*0.24, -sq*s*0.28),
				Vector2( s*0.40, -sq*s*0.08), Vector2( s*0.34,  sq*s*0.16),
				Vector2( s*0.12,  sq*s*0.24), Vector2(-s*0.10,  sq*s*0.22),
				Vector2(-s*0.30,  sq*s*0.14), Vector2(-s*0.42,  sq*s*0.02),
			])
			var outer := Polygon2D.new()
			outer.polygon = pts
			outer.color   = Color(0.28, 0.21, 0.12, 0.96)
			container.add_child(outer)
			var inner := Polygon2D.new()
			inner.polygon = _scale_poly(pts, 0.52)
			inner.color   = Color(0.46, 0.36, 0.20, 0.82)
			container.add_child(inner)
		"cover_partial":
			var barrier := Polygon2D.new()
			barrier.polygon = PackedVector2Array([
				Vector2(-s*0.36, -sq*s*0.12), Vector2( s*0.36, -sq*s*0.12),
				Vector2( s*0.36,  sq*s*0.18), Vector2(-s*0.36,  sq*s*0.18),
			])
			barrier.color = Color(0.52, 0.46, 0.28, 0.94)
			container.add_child(barrier)
		"cover_full":
			var wall := Polygon2D.new()
			wall.polygon = PackedVector2Array([
				Vector2(-s*0.38, -sq*s*0.30), Vector2( s*0.38, -sq*s*0.30),
				Vector2( s*0.38,  sq*s*0.20), Vector2(-s*0.38,  sq*s*0.20),
			])
			wall.color = Color(0.36, 0.33, 0.26, 0.96)
			container.add_child(wall)


static func _scale_poly(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * f)
	return out


# ─── Structural / liquid terrain (drawn, not sprites) ────────────────────────────

# A raised isometric block so walls read as buildings with real height. The three
# front edges of the flat-top hex get side faces; the lifted hex outline is the roof.
func _decor_wall(container: Node2D) -> void:
	var corners := HexGrid.hex_corners(Vector2.ZERO)
	var up := Vector2(0, -HexGrid.HEX_SIZE * 0.85)
	for i in 3:   # edges (0,1),(1,2),(2,3) form the lower/front perimeter
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([a, b, b + up, a + up])
		face.color = Color(0.30, 0.28, 0.25) if i == 1 else Color(0.37, 0.34, 0.30)
		container.add_child(face)
	var roof := Polygon2D.new()
	var top := PackedVector2Array()
	for c: Vector2 in corners:
		top.append(c + up)
	roof.polygon = top
	roof.color = Color(0.52, 0.49, 0.44)
	container.add_child(roof)


func _decor_water(container: Node2D) -> void:
	var s  := HexGrid.HEX_SIZE
	var sq := HexGrid.ISO_SQUASH
	for k in 2:
		var ripple := Line2D.new()
		var y := -sq * s * 0.06 + float(k) * (s * 0.16)
		ripple.add_point(Vector2(-s * 0.30, y))
		ripple.add_point(Vector2( s * 0.30, y))
		ripple.default_color = Color(0.55, 0.70, 0.82, 0.5)
		ripple.width = 2.0
		container.add_child(ripple)


func _decor_rubble(container: Node2D) -> void:
	var s := HexGrid.HEX_SIZE
	for p: Vector2 in [Vector2(-s * 0.20, 0.0), Vector2(s * 0.16, s * 0.10), Vector2(0.0, -s * 0.08)]:
		var deb := Polygon2D.new()
		deb.polygon = PackedVector2Array([
			p + Vector2(-6, 4), p + Vector2(0, -6), p + Vector2(7, 4)])
		deb.color = Color(0.40, 0.37, 0.32)
		container.add_child(deb)


# ─── Structures / set-dressing layer ─────────────────────────────────────────────

# Authored landmarks placed on top of the terrain (cosmetic — they don't change
# movement or LOS; pair them with wall/obstacle terrain where you want collision).
# Data: "props": [ { "prop": "shack"|"wreck"|"fence"|..., "q": int, "r": int } ].
func _spawn_props() -> void:
	for p: Dictionary in _map_data.get("props", []):
		var hex := Vector2i(p.get("q", 0), p.get("r", 0))
		var kind := String(p.get("prop", ""))
		var node := _make_prop(kind)
		# Props live in the Y-sorted layer (so they occlude/are occluded by units)
		# and are fog-tinted via the per-hex registry.
		node.position = HexGrid.hex_to_pixel(hex)
		node.set_meta("tall", _PROP_TALL.has(kind))
		_actors_layer.add_child(node)
		_register_decor(hex, node)


func _make_prop(kind: String) -> Node2D:
	var root := Node2D.new()
	var s := HexGrid.HEX_SIZE
	var sq := HexGrid.ISO_SQUASH
	match kind:
		"shack", "house", "building", "hut":
			_poly(root, [Vector2(-s*0.42, sq*s*0.18), Vector2(s*0.42, sq*s*0.18),
				Vector2(s*0.42, -s*0.40), Vector2(-s*0.42, -s*0.40)], Color(0.44, 0.37, 0.28))
			_poly(root, [Vector2(-s*0.50, -s*0.36), Vector2(s*0.50, -s*0.36),
				Vector2(0, -s*0.74)], Color(0.30, 0.22, 0.16))
			_poly(root, [Vector2(-s*0.10, sq*s*0.18), Vector2(s*0.10, sq*s*0.18),
				Vector2(s*0.10, -s*0.08), Vector2(-s*0.10, -s*0.08)], Color(0.15, 0.12, 0.09))
		"wreck", "car", "vehicle":
			_poly(root, [Vector2(-s*0.46, sq*s*0.16), Vector2(s*0.46, sq*s*0.16),
				Vector2(s*0.40, -sq*s*0.12), Vector2(-s*0.40, -sq*s*0.12)], Color(0.40, 0.31, 0.25))
			_poly(root, [Vector2(-s*0.22, -sq*s*0.12), Vector2(s*0.22, -sq*s*0.12),
				Vector2(s*0.14, -sq*s*0.46), Vector2(-s*0.14, -sq*s*0.46)], Color(0.30, 0.24, 0.20))
			for wx: float in [-s*0.30, s*0.30]:
				var wheel := Polygon2D.new()
				wheel.polygon = _circle_verts(s*0.11)
				wheel.position = Vector2(wx, sq*s*0.16)
				wheel.color = Color(0.12, 0.11, 0.10)
				root.add_child(wheel)
		"fence", "barricade", "wall_low":
			_poly(root, [Vector2(-s*0.46, -sq*s*0.06), Vector2(s*0.46, -sq*s*0.06),
				Vector2(s*0.46, sq*s*0.04), Vector2(-s*0.46, sq*s*0.04)], Color(0.42, 0.35, 0.25))
			for px: float in [-s*0.36, 0.0, s*0.36]:
				_poly(root, [Vector2(px-2.5, sq*s*0.18), Vector2(px+2.5, sq*s*0.18),
					Vector2(px+2.5, -sq*s*0.20), Vector2(px-2.5, -sq*s*0.20)], Color(0.32, 0.27, 0.19))
		"campfire", "fire":
			var ring := Polygon2D.new()
			ring.polygon = _circle_verts(s*0.22)
			ring.color = Color(0.24, 0.22, 0.19)
			root.add_child(ring)
			_poly(root, [Vector2(-s*0.11, sq*s*0.02), Vector2(s*0.11, sq*s*0.02),
				Vector2(0, -s*0.30)], Color(0.90, 0.50, 0.15))
			_poly(root, [Vector2(-s*0.05, 0.0), Vector2(s*0.05, 0.0),
				Vector2(0, -s*0.17)], Color(0.98, 0.82, 0.30))
		"tent":
			_poly(root, [Vector2(-s*0.40, sq*s*0.18), Vector2(s*0.40, sq*s*0.18),
				Vector2(0, -s*0.40)], Color(0.46, 0.41, 0.30))
			_poly(root, [Vector2(-s*0.06, sq*s*0.18), Vector2(s*0.06, sq*s*0.18),
				Vector2(0, -s*0.12)], Color(0.20, 0.18, 0.14))
		"generator", "machine", "terminal", "console":
			_poly(root, [Vector2(-s*0.26, sq*s*0.14), Vector2(s*0.26, sq*s*0.14),
				Vector2(s*0.26, -s*0.24), Vector2(-s*0.26, -s*0.24)], Color(0.34, 0.36, 0.34))
			_poly(root, [Vector2(-s*0.16, -s*0.04), Vector2(s*0.16, -s*0.04),
				Vector2(s*0.16, -s*0.18), Vector2(-s*0.16, -s*0.18)], Color(0.20, 0.52, 0.56))
		"tree", "dead_tree", "cactus", "barrel", "crate", "sign", "chest":
			var sp := SpriteAtlas.make_sprite(SpriteAtlas.prop_tex(kind), 40.0, 8.0, 1)
			if sp:
				root.add_child(sp)
			else:
				_poly(root, [Vector2(-6, sq*s*0.1), Vector2(6, sq*s*0.1),
					Vector2(6, -s*0.3), Vector2(-6, -s*0.3)], Color(0.4, 0.35, 0.26))
		_:
			# Unknown kind: try the sprite sheet by name, else a small marker post.
			var spr := SpriteAtlas.make_sprite(SpriteAtlas.prop_tex(kind), 36.0, 6.0, 1)
			if spr:
				root.add_child(spr)
			else:
				_poly(root, [Vector2(-4, sq*s*0.1), Vector2(4, sq*s*0.1),
					Vector2(4, -s*0.25), Vector2(-4, -s*0.25)], Color(0.5, 0.45, 0.32))
	return root


func _poly(parent: Node2D, pts: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color = color
	parent.add_child(p)


# ════════════════════════════════════════════════════════════════════════════════
# Actors + player
# ════════════════════════════════════════════════════════════════════════════════

func _spawn_actors() -> void:
	var state := GameState.get_exploration_state(_map_id)
	var dead: Array = state.get("dead_actors", [])

	var entries: Array = []
	for a: Dictionary in _map_data.get("actors", []):
		entries.append({"atype": a.get("type", "npc"), "data": a})
	for c: Dictionary in _map_data.get("containers", []):
		entries.append({"atype": "container", "data": c})
	for e: Dictionary in _map_data.get("examine_spots", []):
		entries.append({"atype": "examine", "data": e})

	for entry: Dictionary in entries:
		var d: Dictionary = entry["data"]
		var aid: String = d.get("id", "")
		if aid == "" or aid in dead:
			continue
		# NPC schedules: an actor with active_hours is only present during those hours.
		if not _actor_active_now(d):
			continue
		var atype: String = entry["atype"]
		var rec := d.duplicate()
		rec["_atype"] = atype
		_actor_data[aid] = rec

		var hex := Vector2i(d.get("q", 0), d.get("r", 0))
		_actor_hex[hex] = aid
		var node := _make_actor_node(d, atype)
		node.position = HexGrid.hex_to_pixel(hex)
		_actors_layer.add_child(node)
		_actor_nodes[aid] = node


func _make_actor_node(d: Dictionary, atype: String) -> Node2D:
	var root := Node2D.new()
	var col_str: String = d.get("color", "")
	var color: Color = Color(col_str) if col_str != "" else ACTOR_COLORS.get(atype, Color.WHITE)

	if atype == "npc" or atype == "enemy":
		# A flat team-colored footprint keeps friend/foe instantly readable in a
		# fight; the character sprite stands on top of it.
		var disc := Polygon2D.new()
		disc.polygon = _circle_verts(HexGrid.HEX_SIZE * 0.34)
		disc.color   = Color(color.r, color.g, color.b, 0.50)
		disc.position = Vector2(0, HexGrid.HEX_SIZE * 0.10)
		root.add_child(disc)
		var sprite := _actor_sprite(d, atype)
		if sprite:
			root.add_child(sprite)
		else:
			_add_token_fallback(root, d, atype, color)
		return root

	if atype == "container":
		var chest := SpriteAtlas.make_sprite(SpriteAtlas.prop_tex("chest"), 38.0, 6.0)
		if chest:
			root.add_child(chest)
		else:
			_add_token_fallback(root, d, atype, color)
		return root

	# Examine spots: a small marker post, falling back to the "?" glyph.
	var marker := SpriteAtlas.make_sprite(SpriteAtlas.prop_tex("sign"), 32.0, 6.0)
	if marker:
		root.add_child(marker)
	else:
		_add_token_fallback(root, d, atype, color)
	return root


func _actor_sprite(d: Dictionary, atype: String) -> Sprite2D:
	# Data may pin an exact sheet cell ("sprite": "col,row") or a named role
	# ("sprite_role": "mutant"); otherwise default by actor type.
	var tex: AtlasTexture = null
	if d.has("sprite"):
		var parts: PackedStringArray = String(d["sprite"]).split(",")
		if parts.size() == 2:
			tex = SpriteAtlas.char_tex(Vector2i(int(parts[0]), int(parts[1])))
	if tex == null:
		var role: String = d.get("sprite_role", atype)
		tex = SpriteAtlas.actor_tex(role)
	if tex == null:
		tex = SpriteAtlas.actor_tex(atype)
	return SpriteAtlas.make_sprite(tex, 40.0, 8.0, 1)


# Original colored-disc + glyph token, used when the sprite sheet is unavailable.
func _add_token_fallback(root: Node2D, d: Dictionary, atype: String, color: Color) -> void:
	if atype == "npc" or atype == "enemy":
		var body := Polygon2D.new()
		body.polygon = _circle_verts(HexGrid.HEX_SIZE * 0.30)
		body.color   = color
		root.add_child(body)
	var lbl := Label.new()
	lbl.text = d.get("glyph", _default_glyph(atype))
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE if (atype == "npc" or atype == "enemy") else color)
	lbl.position = Vector2(-5, -9)
	root.add_child(lbl)


func _default_glyph(atype: String) -> String:
	match atype:
		"npc":       return "N"
		"enemy":     return "E"
		"container": return "▫"
		"examine":   return "?"
		_:           return "?"


func _spawn_player() -> void:
	var start: Dictionary = _map_data.get("player_start", {"q": 2, "r": 5})
	_player_hex = Vector2i(start.get("q", 2), start.get("r", 5))
	# Keep the saved position if we re-enter a persistent map mid-playthrough.
	var state := GameState.get_exploration_state(_map_id)
	if state.has("player_q") and not _is_encounter:
		var saved := Vector2i(state["player_q"], state["player_r"])
		if not TerrainDB.is_blocked(_terrain.get(saved, "obstacle")):
			_player_hex = saved
	_player.position = HexGrid.hex_to_pixel(_player_hex)

	# Gold footprint disc keeps the player easy to pick out at any zoom.
	var disc := Polygon2D.new()
	disc.polygon = _circle_verts(HexGrid.HEX_SIZE * 0.36)
	disc.color   = Color(0.82, 0.70, 0.12, 0.65)
	disc.position = Vector2(0, HexGrid.HEX_SIZE * 0.10)
	_player.add_child(disc)
	var sprite := SpriteAtlas.make_sprite(SpriteAtlas.actor_tex("player"), 40.0, 8.0, 1)
	if sprite:
		_player.add_child(sprite)
	else:
		var body := Polygon2D.new()
		body.polygon = _circle_verts(HexGrid.HEX_SIZE * 0.30)
		body.color   = Color(0.22, 0.58, 0.22)
		_player.add_child(body)
		var lbl := Label.new()
		lbl.text = "@"
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.position = Vector2(-5, -9)
		_player.add_child(lbl)


static func _circle_verts(radius: float, sides: int = 14) -> PackedVector2Array:
	var v := PackedVector2Array()
	for i in sides:
		var a := float(i) / float(sides) * TAU
		v.append(Vector2(cos(a) * radius, sin(a) * radius * HexGrid.ISO_SQUASH))
	return v


func _setup_camera() -> void:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for hex: Vector2i in _terrain:
		var p := HexGrid.hex_to_pixel(hex)
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var pad := HexGrid.HEX_SIZE * 2.0
	_cam.limit_left   = int(min_p.x - pad)
	_cam.limit_top    = int(min_p.y - pad)
	_cam.limit_right  = int(max_p.x + pad)
	_cam.limit_bottom = int(max_p.y + pad)
	_cam.global_position = _player.global_position


# ════════════════════════════════════════════════════════════════════════════════
# Fog of war — line-of-sight based in BOTH explore and combat. Entering a fight no
# longer reveals the whole map; you still only see what the player can actually see.
# ════════════════════════════════════════════════════════════════════════════════

func _recompute_fog() -> void:
	var radius: int = _map_data.get("vision_radius", 5)
	var opaque := _opaque_hexes()
	# Downgrade everything currently visible back to explored.
	for hex: Vector2i in _vis:
		if _vis[hex] == 2:
			_vis[hex] = 1
	var newly: Array = []
	for hex: Vector2i in _terrain:
		if HexGrid.distance(_player_hex, hex) > radius:
			continue
		if LineOfSight.has_los(_player_hex, hex, opaque):
			if _vis.get(hex, 0) != 2:
				newly.append(hex)
			_vis[hex] = 2
	_vis[_player_hex] = 2
	GameState.mark_tiles_explored(_map_id, newly + [_player_hex])
	_apply_fog()


func _reveal_all() -> void:
	for hex: Vector2i in _terrain:
		_vis[hex] = 2
	_apply_fog()


func _apply_fog() -> void:
	for hex: Vector2i in _hex_nodes:
		_hex_nodes[hex].modulate = _fog_tint(_vis.get(hex, 0))
	# Standing decor / props (in the sort layer) fade with fog and hide when unseen.
	for hex: Vector2i in _decor_by_hex:
		var tint := _fog_tint(_vis.get(hex, 0))
		var seen: bool = _vis.get(hex, 0) > 0
		for n: Node2D in _decor_by_hex[hex]:
			if is_instance_valid(n):
				n.modulate = tint
				n.visible = seen
	for aid: String in _actor_nodes:
		var hex := _actor_hex_of(aid)
		# In combat, units move through CombatManager, so their _actor_data coords
		# are stale — read the live combat hex so LOS visibility tracks movement.
		if _mode == Mode.COMBAT and CombatManager.units.has(aid):
			hex = CombatManager.units[aid].get("hex", hex)
		var v: int = _vis.get(hex, 0)
		# Containers / examine spots stay visible once discovered; living
		# creatures only show while actually in view.
		var atype: String = _actor_data.get(aid, {}).get("_atype", "examine")
		if atype == "npc" or atype == "enemy":
			_actor_nodes[aid].visible = (v == 2)
		else:
			_actor_nodes[aid].visible = (v >= 1)
	_update_occluders()


# Walls / structures that the player is standing behind become translucent so the
# player is never hidden by the scenery. Recomputes each node's tint from scratch
# (fog tint × see-through alpha) so it's safe to call after any fog refresh or move.
func _update_occluders() -> void:
	var py := HexGrid.hex_to_pixel(_player_hex).y
	for hex: Vector2i in _decor_by_hex:
		var base := _fog_tint(_vis.get(hex, 0))
		var in_front := HexGrid.hex_to_pixel(hex).y > py
		var near: bool = HexGrid.distance(hex, _player_hex) <= SEE_THROUGH_RADIUS
		var fade := in_front and near
		for n: Node2D in _decor_by_hex[hex]:
			if not is_instance_valid(n) or not bool(n.get_meta("tall", false)):
				continue
			n.modulate = Color(base.r, base.g, base.b, base.a * OCCLUDER_ALPHA) if fade else base


func _fog_tint(v: int) -> Color:
	match v:
		2: return FOG_VISIBLE
		1: return FOG_EXPLORED
		_: return FOG_HIDDEN


func _actor_hex_of(aid: String) -> Vector2i:
	var d: Dictionary = _actor_data.get(aid, {})
	return Vector2i(d.get("q", 0), d.get("r", 0))


func _opaque_hexes() -> Array:
	var out: Array = []
	for hex: Vector2i in _terrain:
		if TerrainDB.is_opaque(_terrain[hex]):
			out.append(hex)
	return out


# ════════════════════════════════════════════════════════════════════════════════
# Input router
# ════════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Universal back/exit: close whatever overlay is open, otherwise leave the map.
	# (Dialogue handles its own Escape before this, so it isn't double-processed.)
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var hex := HexGrid.pixel_to_hex(get_global_mouse_position())
	if not _terrain.has(hex):
		return
	if _mode == Mode.EXPLORE:
		_explore_click(hex)
	else:
		_combat_click(hex)


# Escape priority: examine card → stacked overlay (char/inv/journal) → cancel an
# aim mode → in explore, leave to the world map. Never bails out of an active fight.
func _on_back() -> void:
	if _examine_panel and _examine_panel.visible:
		_examine_panel.visible = false
		AudioManager.play_sfx("back")
		return
	if _close_top_overlay():
		AudioManager.play_sfx("back")
		return
	if _mode == Mode.COMBAT:
		if _aim != Aim.NONE:
			_exit_aim()
			AudioManager.play_sfx("back")
		return
	AudioManager.play_sfx("back")
	_on_leave()


func _close_top_overlay() -> bool:
	while not _overlay_stack.is_empty():
		var panel = _overlay_stack.pop_back()
		if is_instance_valid(panel):
			panel.queue_free()
			return true
	return false


# ─── Explore interactions ───────────────────────────────────────────────────────

func _explore_click(hex: Vector2i) -> void:
	if _any_panel_open() or _moving:
		return
	if _actor_hex.has(hex):
		_interact(_actor_hex[hex])
		return
	if not TerrainDB.is_blocked(_terrain.get(hex, "obstacle")):
		_walk_to(hex)


func _interact(aid: String) -> void:
	var d: Dictionary = _actor_data.get(aid, {})
	match d.get("_atype", "examine"):
		"npc":       _talk(d)
		"enemy":     _enter_combat()       # player initiates the fight
		"container": _open_container(aid, d)
		"examine":   _show_examine(d.get("title", "?"), d.get("text", ""), d.get("skill_use", {}))


func _talk(d: Dictionary) -> void:
	var npc_id: String = d.get("npc_id", "")
	var npc := DataManager.get_npc(npc_id)
	if npc_id == "" or npc.is_empty():
		_show_examine(d.get("id", "NPC"), "They have nothing to say.")
		return
	# Every conversation can be gated out by trigger conditions (e.g. already met,
	# wrong flags). If none are available, start_conversation() would silently no-op
	# and leave a blank, nameless dialogue box — so show a named card instead.
	if not DialogueManager.can_talk_to(npc_id):
		_show_examine(npc.get("name", d.get("id", "NPC")), "They have nothing more to say right now.")
		return
	if _dialogue_box:
		_dialogue_box.visible = true
	DialogueManager.start_conversation(npc_id)


func _open_container(_aid: String, d: Dictionary) -> void:
	var opened_flag: String = d.get("opened_flag", "")
	if opened_flag != "" and GameState.get_flag(opened_flag):
		_show_examine("Container", "Already looted.")
		return
	if d.get("locked", false):
		var diff: int = d.get("lockpick_difficulty", 50)
		var res := SkillCheck.resolve("lockpick", diff)
		if not res.get("passed", false):
			_show_examine("Locked", "The lock holds. (Lockpick %d vs DC %d)" % [
				GameState.skills.get("lockpick", 0), diff])
			return
	var rolled: Array = []
	for e: Dictionary in d.get("loot_table", []):
		if randf() <= e.get("chance", 1.0):
			rolled.append({"item_id": e["item_id"], "quantity": e.get("quantity", 1)})
	if opened_flag != "":
		GameState.set_flag(opened_flag, true)
	if rolled.is_empty():
		_show_examine("Container", "Empty.")
		return
	AudioManager.play_sfx("open")
	CombatManager.pending_loot = rolled
	_open_loot_panel(func() -> void: pass)


func _format_loot(loot: Array) -> String:
	var parts: Array = []
	for it: Dictionary in loot:
		parts.append("%s ×%d" % [
			DataManager.get_item(it["item_id"]).get("name", it["item_id"]), it.get("quantity", 1)])
	return ", ".join(parts)


# ─── Real-time walking ──────────────────────────────────────────────────────────

func _walk_to(goal: Vector2i) -> void:
	var blocked := _explore_blocked(goal)
	var path := HexGrid.find_path(_player_hex, goal, blocked)
	if path.is_empty():
		return
	_step_path(path)


func _explore_blocked(goal: Vector2i) -> Array:
	var blocked: Array = []
	for hex: Vector2i in _terrain:
		if TerrainDB.is_blocked(_terrain[hex]):
			blocked.append(hex)
	for hex: Vector2i in _actor_hex:
		if hex != goal:
			blocked.append(hex)
	return blocked


func _step_path(path: Array) -> void:
	if path.is_empty():
		_moving = false
		return
	_moving = true
	var nxt: Vector2i = path.pop_front()
	if TerrainDB.is_blocked(_terrain.get(nxt, "obstacle")) or _actor_hex.has(nxt):
		_moving = false
		return
	var tw := create_tween()
	tw.tween_property(_player, "position", HexGrid.hex_to_pixel(nxt), MOVE_STEP_TIME)\
		.set_trans(Tween.TRANS_LINEAR)
	tw.finished.connect(func() -> void:
		_player_hex = nxt
		_cam.global_position = _player.global_position
		_recompute_fog()
		if _check_exit():
			return
		if _check_detection():
			_moving = false
			return
		_step_path(path)
	, CONNECT_ONE_SHOT)


func _check_exit() -> bool:
	for zone: Dictionary in _map_data.get("exit_zones", []):
		var r := Rect2i(zone.get("q", 0), zone.get("r", 0), zone.get("w", 1), zone.get("h", 1))
		if r.has_point(_player_hex):
			_save_position()
			get_tree().change_scene_to_file("res://scenes/world/worldmap.tscn")
			return true
	return false


# An enemy in range with line of sight drags the player into combat.
func _check_detection() -> bool:
	if _living_enemies().is_empty():
		return false
	var opaque := _opaque_hexes()
	for aid: String in _living_enemies():
		var hex := _actor_hex_of(aid)
		if HexGrid.distance(hex, _player_hex) <= DETECT_RADIUS \
				and LineOfSight.has_los(hex, _player_hex, opaque):
			_enter_combat()
			return true
	return false


func _living_enemies() -> Array:
	var out: Array = []
	for aid: String in _actor_data:
		if _actor_data[aid].get("_atype", "") == "enemy" and _actor_nodes.has(aid):
			out.append(aid)
	return out


# ════════════════════════════════════════════════════════════════════════════════
# COMBAT — freeze the map in place and hand the turn loop to CombatManager
# ════════════════════════════════════════════════════════════════════════════════

func _enter_combat() -> void:
	if _mode == Mode.COMBAT:
		return
	var enemies: Array = []
	for aid: String in _living_enemies():
		var d: Dictionary = _actor_data[aid]
		enemies.append({
			"actor_id": aid,
			"npc_id":   d.get("npc_id", aid),
			"hex":      _actor_hex_of(aid),
		})
	if enemies.is_empty():
		return
	_mode = Mode.COMBAT
	_close_panels()
	_explore_bar.visible = false
	_combat_hud.visible  = true
	CombatManager.start_combat_in_place(_terrain, _player_hex, enemies)
	_spawn_companion_nodes()
	_attach_hp_bars()
	_sync_combat_after_start()
	# Keep the existing line-of-sight fog (no full reveal); recompute now that the
	# combat units exist so enemy visibility reflects their real starting hexes.
	_recompute_fog()


func _sync_combat_after_start() -> void:
	# Snap any units CombatManager nudged off an occupied/blocked hex, and sync
	# bars in case an enemy won initiative and already acted.
	for uid: String in CombatManager.units:
		var node := _unit_node(uid)
		if node:
			node.position = HexGrid.hex_to_pixel(CombatManager.units[uid]["hex"])
		_update_hp_bar(uid)
	_refresh_combat_hud()
	_refresh_turn_list()
	_clear_highlights()
	var cur: Dictionary = CombatManager.units.get(CombatManager.current_unit_id, {})
	_status_lbl.text = "Your Turn" if CombatManager.current_unit_id == "player" \
		else "%s's Turn" % cur.get("display_name", "")
	_ap_lbl.text = "AP: %d" % cur.get("ap", 0)


func _unit_node(uid: String) -> Node2D:
	if uid == "player":
		return _player
	return _actor_nodes.get(uid)


# Companions are combat units that aren't on the explore map, so give each a visual node
# (allied green footprint) when a fight starts. Removed again when combat ends.
func _spawn_companion_nodes() -> void:
	for uid: String in CombatManager.units:
		var u: Dictionary = CombatManager.units[uid]
		if uid == "player" or u.get("team", "") != "player" or _actor_nodes.has(uid):
			continue
		var d := {"npc_id": u.get("npc_id", ""), "color": "#55cc66", "id": uid}
		var node := _make_actor_node(d, "npc")
		node.position = HexGrid.hex_to_pixel(u["hex"])
		_actors_layer.add_child(node)
		_actor_nodes[uid] = node
		_actor_hex[u["hex"]] = uid


func _despawn_companion_nodes() -> void:
	for uid: String in _actor_nodes.keys():
		if uid.begins_with("comp_"):
			var node: Node2D = _actor_nodes[uid]
			if is_instance_valid(node):
				node.queue_free()
			_actor_nodes.erase(uid)


func _attach_hp_bars() -> void:
	for uid: String in CombatManager.units:
		var node := _unit_node(uid)
		if node == null:
			continue
		var is_player: bool = CombatManager.units[uid].get("team", "") == "player"
		var by := HexGrid.HEX_SIZE * 0.62
		var bg := Polygon2D.new()
		bg.polygon = PackedVector2Array([
			Vector2(-BAR_W*0.5, -BAR_H*0.5), Vector2(BAR_W*0.5, -BAR_H*0.5),
			Vector2(BAR_W*0.5,  BAR_H*0.5),  Vector2(-BAR_W*0.5, BAR_H*0.5)])
		bg.position = Vector2(0, by)
		bg.color = Color(0.04, 0.04, 0.04)
		bg.name = "_hpbg"
		node.add_child(bg)
		var fill := Polygon2D.new()
		fill.polygon = _bar_verts(BAR_W, BAR_H)
		fill.position = Vector2(-BAR_W*0.5, by)
		fill.color = Color(0.2, 0.8, 0.2) if is_player else Color(0.85, 0.25, 0.25)
		fill.name = "_hpfill"
		node.add_child(fill)
		_hp_bars[uid] = fill


func _bar_verts(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -h*0.5), Vector2(w, -h*0.5), Vector2(w, h*0.5), Vector2(0.0, h*0.5)])


func _update_hp_bar(uid: String) -> void:
	if not _hp_bars.has(uid):
		return
	var u: Dictionary = CombatManager.units.get(uid, {})
	var ratio := float(u.get("hp", 0)) / float(max(1, u.get("hp_max", 1)))
	var fill: Polygon2D = _hp_bars[uid]
	fill.polygon = _bar_verts(BAR_W * ratio, BAR_H)
	fill.color = Color(0.2, 0.8, 0.2) if ratio > 0.5 \
		else Color(0.9, 0.55, 0.1) if ratio > 0.25 else Color(0.9, 0.15, 0.15)


func _combat_click(hex: Vector2i) -> void:
	if not CombatManager.is_player_turn():
		return
	match _aim:
		Aim.MOVE:
			if _reachable.has(hex):
				CombatManager.try_move("player", hex)
				_exit_aim()
		Aim.QUICK:
			var tid := _unit_at(hex)
			if tid in _targetable:
				CombatManager.try_attack("player", tid, CombatManager.ShotMode.QUICK)
				_exit_aim()
		Aim.AIMED:
			var tid := _unit_at(hex)
			if tid in _targetable:
				_show_called_shot_menu(tid)
		Aim.BURST:
			var tid := _unit_at(hex)
			if tid in _targetable:
				CombatManager.try_attack("player", tid, CombatManager.ShotMode.BURST)
				_exit_aim()
		Aim.MELEE:
			var tid := _unit_at(hex)
			if tid in _targetable:
				CombatManager.try_melee_attack("player", tid)
				_exit_aim()


func _unit_at(hex: Vector2i) -> String:
	for uid: String in CombatManager.units:
		var u: Dictionary = CombatManager.units[uid]
		if u.get("hex") == hex and not u.get("dead", false):
			return uid
	return ""


# ─── Highlights ─────────────────────────────────────────────────────────────────

func _clear_highlights() -> void:
	for hex: Vector2i in _tile_polys:
		_tile_polys[hex].color = _base_color(_terrain.get(hex, "floor"), hex)
	var active: Vector2i = CombatManager.units.get(
		CombatManager.current_unit_id, {}).get("hex", Vector2i(-99, -99))
	if _tile_polys.has(active):
		_tile_polys[active].color = COLORS["active_unit"]


func _apply_highlights() -> void:
	_clear_highlights()
	match _aim:
		Aim.MOVE:
			for hex: Vector2i in _reachable:
				if _tile_polys.has(hex):
					_tile_polys[hex].color = COLORS["move_hi"]
		Aim.QUICK, Aim.AIMED:
			var pu: Dictionary = CombatManager.units.get("player", {})
			var phex: Vector2i = pu.get("hex", Vector2i(-99, -99))
			var weapon := DataManager.get_item(pu.get("equipped_weapon_id", ""))
			var wr := CombatCalc.weapon_range(weapon)
			for hex: Vector2i in _terrain:
				if _tile_polys.has(hex) and HexGrid.distance(phex, hex) <= wr:
					_tile_polys[hex].color = COLORS["range_ring"]
			for tid: String in _targetable:
				var th: Vector2i = CombatManager.units.get(tid, {}).get("hex", Vector2i(-99, -99))
				if _tile_polys.has(th):
					_tile_polys[th].color = COLORS["attack_hi"]
		Aim.MELEE:
			for tid: String in _targetable:
				var th: Vector2i = CombatManager.units.get(tid, {}).get("hex", Vector2i(-99, -99))
				if _tile_polys.has(th):
					_tile_polys[th].color = COLORS["attack_hi"]


func _exit_aim() -> void:
	_aim = Aim.NONE
	_reachable = {}
	_targetable.clear()
	_close_called_shot_menu()
	_clear_highlights()
	_update_mode_label()


func _close_called_shot_menu() -> void:
	if _called_shot_menu != null:
		_called_shot_menu.queue_free()
		_called_shot_menu = null


# Aimed-shot body-part picker. Each option fires a called shot at `target_id`.
func _show_called_shot_menu(target_id: String) -> void:
	_close_called_shot_menu()
	var nm: String = CombatManager.units.get(target_id, {}).get("display_name", target_id)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -170; panel.offset_top = -150
	panel.offset_right = 170; panel.offset_bottom = 150
	_ui.add_child(panel)
	_called_shot_menu = panel

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := _mk_label("AIMED SHOT — %s" % nm, 20)
	vb.add_child(title)

	var parts := [
		["Head  (−15 hit, +crit, stun)", CombatManager.BodyPart.HEAD],
		["Torso (+10 hit)",              CombatManager.BodyPart.TORSO],
		["Arms  (−10 hit, spoil aim)",   CombatManager.BodyPart.ARMS],
		["Legs  (−10 hit, slow them)",   CombatManager.BodyPart.LEGS],
	]
	for entry: Array in parts:
		var btn := Button.new()
		btn.text = entry[0]
		var part: int = entry[1]
		btn.pressed.connect(func() -> void:
			CombatManager.try_attack("player", target_id, CombatManager.ShotMode.AIMED, part)
			_exit_aim())
		vb.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_exit_aim)
	vb.add_child(cancel)


# ════════════════════════════════════════════════════════════════════════════════
# CombatManager signal handlers
# ════════════════════════════════════════════════════════════════════════════════

func _connect_combat_signals() -> void:
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.unit_moved.connect(_on_unit_moved)
	CombatManager.unit_attacked.connect(_on_unit_attacked)
	CombatManager.unit_died.connect(_on_unit_died)
	CombatManager.ap_changed.connect(_on_ap_changed)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.unit_reloaded.connect(_on_unit_reloaded)
	CombatManager.unit_used_item.connect(_on_unit_used_item)
	CombatManager.status_applied.connect(_on_status_applied)
	CombatManager.status_tick.connect(_on_status_tick)


func _on_turn_started(uid: String, ap: int) -> void:
	if _mode != Mode.COMBAT:
		return
	var nm: String = CombatManager.units.get(uid, {}).get("display_name", uid)
	_status_lbl.text = "Your Turn" if uid == "player" else "%s's Turn" % nm
	_ap_lbl.text = "AP: %d" % ap
	_refresh_combat_hud()
	_refresh_turn_list()
	_clear_highlights()
	_exit_aim()


func _on_unit_moved(uid: String, _from: Vector2i, to: Vector2i) -> void:
	if _mode != Mode.COMBAT:
		return
	var node := _unit_node(uid)
	if node:
		var tw := create_tween()
		tw.tween_property(node, "position", HexGrid.hex_to_pixel(to), 0.13)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if uid == "player":
		_player_hex = to
		_cam.global_position = HexGrid.hex_to_pixel(to)
		_ap_lbl.text = "AP: %d" % CombatManager.get_ap("player")
		_refresh_combat_hud()
		# Moving in combat shifts what the player can see — refresh LOS fog so
		# enemies blink in/out of view exactly as they do while exploring.
		_recompute_fog()
		_update_occluders()
	else:
		# An enemy moved: re-evaluate its visibility against the current fog so it
		# hides when it slips out of the player's line of sight.
		_apply_fog()


func _on_unit_attacked(att: String, tgt: String, hit: bool, dmg: int, wname: String) -> void:
	if _mode != Mode.COMBAT:
		return
	var a: String = CombatManager.units.get(att, {}).get("display_name", att)
	var t: String = CombatManager.units.get(tgt, {}).get("display_name", tgt)
	var thex: Vector2i = CombatManager.units.get(tgt, {}).get("hex", Vector2i())
	if hit:
		AudioManager.play_sfx("hit")
		_float(HexGrid.hex_to_pixel(thex), "-%d" % dmg, Color(0.95, 0.25, 0.25))
		_log("[color=#c8a84b]%s[/color] hits [color=#e06060]%s[/color] with %s for %d." % [a, t, wname, dmg])
	else:
		AudioManager.play_sfx("miss")
		_float(HexGrid.hex_to_pixel(thex), "MISS", Color(0.55, 0.55, 0.55))
		_log("[color=#888888]%s misses %s.[/color]" % [a, t])
	if att == "player":
		_ap_lbl.text = "AP: %d" % CombatManager.get_ap("player")
		_refresh_weapon_label()
		_refresh_combat_hud()
	if tgt == "player":
		_refresh_weapon_label()
	_update_hp_bar(tgt)
	_refresh_turn_list()


func _on_unit_died(uid: String) -> void:
	# Persist the kill so the actor stays gone after combat / on reload.
	var node := _unit_node(uid)
	AudioManager.play_sfx("death")
	if uid != "player" and node:
		node.queue_free()
		_actor_nodes.erase(uid)
		var hex := _actor_hex_of(uid)
		_actor_hex.erase(hex)
		GameState.mark_actor_dead(_map_id, uid)
		var dflag: String = _actor_data.get(uid, {}).get("dead_flag", "")
		if dflag != "":
			GameState.set_flag(dflag, true)
		# Killing certain NPCs shifts karma (e.g. murdering townsfolk = bad karma).
		var nid: String = _actor_data.get(uid, {}).get("npc_id", "")
		if nid != "":
			var k: int = int(DataManager.get_npc(nid).get("karma_on_kill", 0))
			if k != 0:
				GameState.add_karma(k)
	_hp_bars.erase(uid)
	if _mode == Mode.COMBAT:
		_log("[color=#555555]%s is down.[/color]" % CombatManager.units.get(uid, {}).get("display_name", uid))
		_refresh_turn_list()


func _on_ap_changed(uid: String, new_ap: int) -> void:
	if _mode == Mode.COMBAT and uid == "player":
		_ap_lbl.text = "AP: %d" % new_ap
		_refresh_combat_hud()


func _on_unit_reloaded(uid: String, loaded: int, reserve: int) -> void:
	if _mode != Mode.COMBAT:
		return
	AudioManager.play_sfx("reload")
	if uid == "player":
		_refresh_weapon_label()
		_refresh_combat_hud()
	var rstr: String = "∞" if reserve == 999 else str(reserve)
	_log("[color=#8888dd]%s reloads. [%d | %s][/color]" % [
		CombatManager.units.get(uid, {}).get("display_name", uid), loaded, rstr])


func _on_unit_used_item(uid: String, item_id: String) -> void:
	if _mode != Mode.COMBAT:
		return
	AudioManager.play_sfx("heal")
	_log("[color=#88cc88]%s uses %s.[/color]" % [
		CombatManager.units.get(uid, {}).get("display_name", uid),
		DataManager.get_item(item_id).get("name", item_id)])
	if uid == "player":
		_refresh_weapon_label()
		_refresh_combat_hud()
	_update_hp_bar(uid)
	_refresh_turn_list()


func _on_status_applied(uid: String, status_name: String) -> void:
	if _mode != Mode.COMBAT:
		return
	var hex: Vector2i = CombatManager.units.get(uid, {}).get("hex", Vector2i())
	var nm: String = CombatManager.units.get(uid, {}).get("display_name", uid)
	var px := HexGrid.hex_to_pixel(hex)
	match status_name:
		"bleed":         _float(px, "BLEED!", Color(0.9, 0.2, 0.2))
		"poison":        _float(px, "POISON!", Color(0.45, 0.85, 0.25))
		"radiation":     _float(px, "RADS!", Color(0.75, 0.9, 0.2))
		"stun":          _float(px, "STUN!", Color(0.5, 0.5, 0.95))
		"stun_skip":     _float(px, "STUNNED", Color(0.5, 0.5, 0.95))
		"crit":          _float(px, "CRIT!", Color(1.0, 0.85, 0.2))
		"fumble":        _float(px, "FUMBLE!", Color(0.95, 0.4, 0.2))
		"cripple_legs":  _float(px, "LEG HIT!", Color(0.95, 0.6, 0.2))
		"cripple_arms":  _float(px, "ARM HIT!", Color(0.95, 0.6, 0.2))
	if status_name == "fumble":
		_log("[color=#cc6644]%s fumbles — the shot goes wide and the turn is lost.[/color]" % nm)
	elif status_name in ["bleed", "poison", "radiation", "stun"]:
		_log("%s is afflicted: %s." % [nm, status_name])
	elif status_name == "cripple_legs":
		_log("%s's leg is crippled — slowed." % nm)
	elif status_name == "cripple_arms":
		_log("%s's arm is crippled — aim spoiled." % nm)
	_refresh_turn_list()


func _on_status_tick(uid: String, status_name: String, dmg: int) -> void:
	if _mode != Mode.COMBAT:
		return
	var hex: Vector2i = CombatManager.units.get(uid, {}).get("hex", Vector2i())
	var tag := "DOT"
	var col := Color(0.9, 0.2, 0.2)
	match status_name:
		"bleed":     tag = "BLD"; col = Color(0.9, 0.2, 0.2)
		"poison":    tag = "PSN"; col = Color(0.45, 0.85, 0.25)
		"radiation": tag = "RAD"; col = Color(0.75, 0.9, 0.2)
	_float(HexGrid.hex_to_pixel(hex), "-%d %s" % [dmg, tag], col)
	_update_hp_bar(uid)
	if uid == "player":
		_refresh_weapon_label()
	_refresh_turn_list()


func _on_combat_ended(player_won: bool) -> void:
	_combat_won = player_won
	_despawn_companion_nodes()
	if player_won:
		GameState.hp = CombatManager.units.get("player", {}).get("hp", GameState.hp)
		GameState.add_xp(CombatManager.xp_earned)
		_show_loot_then_resume()
	else:
		_game_over()


func _show_loot_then_resume() -> void:
	_open_loot_panel(_resume_explore)


# Always build a fresh loot panel so its _ready() reads the current pending_loot.
func _open_loot_panel(on_done: Callable) -> void:
	var scene := load("res://scenes/ui/loot_panel.tscn")
	if scene == null:
		for it: Dictionary in CombatManager.pending_loot:
			if it["item_id"] == "__caps__":
				GameState.caps += it["quantity"]
			else:
				GameState.add_item(it["item_id"], it.get("quantity", 1))
		CombatManager.pending_loot.clear()
		on_done.call()
		return
	var panel = scene.instantiate()
	_loot_panel_node = panel
	_ui.add_child(panel)
	panel.loot_done.connect(func() -> void:
		_loot_panel_node = null
		on_done.call())


func _resume_explore() -> void:
	if _is_encounter:
		# Cleared a random encounter — back to the wasteland.
		_save_position()
		get_tree().change_scene_to_file("res://scenes/world/worldmap.tscn")
		return
	# Thaw the map: player keeps their final combat position, fights are over.
	_mode = Mode.COMBAT  # guard so handlers ignore late signals
	_remove_hp_bars()
	_player_hex = CombatManager.units.get("player", {}).get("hex", _player_hex)
	_player.position = HexGrid.hex_to_pixel(_player_hex)
	_cam.global_position = _player.global_position
	_mode = Mode.EXPLORE
	_aim = Aim.NONE
	_combat_hud.visible = false
	_explore_bar.visible = true
	_clear_highlights()
	_recompute_fog()
	_refresh_explore_hud()


func _remove_hp_bars() -> void:
	for uid: String in _hp_bars.keys():
		var node := _unit_node(uid)
		if node:
			for child in node.get_children():
				if child.name == "_hpbg" or child.name == "_hpfill":
					child.queue_free()
	_hp_bars.clear()


func _game_over() -> void:
	_status_lbl.text = "You have died."
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ════════════════════════════════════════════════════════════════════════════════
# Combat HUD
# ════════════════════════════════════════════════════════════════════════════════

func _build_combat_hud() -> void:
	_combat_hud = Control.new()
	_combat_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combat_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_hud.visible = false
	_ui.add_child(_combat_hud)

	# Top-left status block
	var tl := VBoxContainer.new()
	tl.position = Vector2(8, 6)
	_combat_hud.add_child(tl)
	_status_lbl = _mk_label("Combat", 20, Color(0.9, 0.85, 0.6)); tl.add_child(_status_lbl)
	_hp_lbl     = _mk_label("HP: --", 17); tl.add_child(_hp_lbl)
	_weapon_lbl = _mk_label("", 17); tl.add_child(_weapon_lbl)
	_ap_lbl     = _mk_label("AP: 0", 18, Color(0.8, 0.8, 0.4)); tl.add_child(_ap_lbl)

	# Centre mode hint
	_mode_lbl = _mk_label("", 16, Color(0.72, 0.72, 0.6))
	_mode_lbl.anchor_left = 0.5; _mode_lbl.anchor_right = 0.5
	_mode_lbl.offset_left = -260; _mode_lbl.offset_right = 260; _mode_lbl.offset_top = 54
	_mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_lbl.visible = false
	_combat_hud.add_child(_mode_lbl)

	# Right turn order
	var tr_col := VBoxContainer.new()
	tr_col.anchor_left = 1.0; tr_col.anchor_right = 1.0
	tr_col.offset_left = -250; tr_col.offset_top = 6; tr_col.offset_right = -10
	_combat_hud.add_child(tr_col)
	tr_col.add_child(_mk_label("TURN ORDER", 15, Color(0.6, 0.57, 0.42)))
	_turn_list = VBoxContainer.new()
	tr_col.add_child(_turn_list)

	# Combat log
	_log_box = RichTextLabel.new()
	_log_box.bbcode_enabled = true
	_log_box.scroll_following = true
	_log_box.anchor_top = 1.0; _log_box.anchor_bottom = 1.0
	_log_box.offset_left = 10; _log_box.offset_top = -176; _log_box.offset_right = 620; _log_box.offset_bottom = -84
	_combat_hud.add_child(_log_box)

	# Action bar
	var bar := HBoxContainer.new()
	bar.anchor_top = 1.0; bar.anchor_bottom = 1.0
	bar.offset_left = 10; bar.offset_top = -68; bar.offset_bottom = -10
	_combat_hud.add_child(bar)
	_move_btn   = _mk_btn("Move",   bar, _on_move)
	_quick_btn  = _mk_btn("Quick",  bar, _on_quick)
	_aimed_btn  = _mk_btn("Aimed",  bar, _on_aimed)
	_burst_btn  = _mk_btn("Burst",  bar, _on_burst)
	_melee_btn  = _mk_btn("Melee",  bar, _on_melee)
	_reload_btn = _mk_btn("Reload", bar, _on_reload)
	_item_btn   = _mk_btn("Stim",   bar, _on_stim)
	_end_btn    = _mk_btn("End Turn", bar, CombatManager.end_player_turn)
	_flee_btn   = _mk_btn("Flee",   bar, _on_flee)


func _mk_label(text: String, size: int, color: Color = Color(0.85, 0.83, 0.75)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _mk_btn(text: String, parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, 54)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		cb.call())
	parent.add_child(b)
	return b


func _on_move() -> void:
	_aim = Aim.MOVE
	_reachable = CombatManager.get_valid_moves("player")
	_apply_highlights(); _update_mode_label()


func _on_quick() -> void:
	_aim = Aim.QUICK
	_targetable = CombatManager.get_valid_targets("player", CombatManager.ShotMode.QUICK)
	_apply_highlights(); _update_mode_label()


func _on_aimed() -> void:
	_aim = Aim.AIMED
	_targetable = CombatManager.get_valid_targets("player", CombatManager.ShotMode.AIMED)
	_apply_highlights(); _update_mode_label()


func _on_burst() -> void:
	_aim = Aim.BURST
	_targetable = CombatManager.get_valid_targets("player", CombatManager.ShotMode.BURST)
	_apply_highlights(); _update_mode_label()


func _on_melee() -> void:
	_aim = Aim.MELEE
	_targetable = CombatManager.get_melee_targets("player")
	_apply_highlights(); _update_mode_label()


func _on_reload() -> void:
	CombatManager.try_reload("player"); _exit_aim()


func _on_stim() -> void:
	CombatManager.try_use_item("player", "stimpak"); _exit_aim()


# True when the player may break off the fight: it's their turn and every living
# enemy is farther than FLEE_SAFE_RADIUS away.
func _flee_available() -> bool:
	if _mode != Mode.COMBAT or not CombatManager.is_player_turn():
		return false
	var phex: Vector2i = CombatManager.units.get("player", {}).get("hex", _player_hex)
	for uid: String in CombatManager.units:
		var u: Dictionary = CombatManager.units[uid]
		if u.get("team", "") != "enemy" or u.get("dead", false):
			continue
		if HexGrid.distance(phex, u.get("hex", phex)) <= FLEE_SAFE_RADIUS:
			return false
	return true


# Disengage from combat without winning: keep current HP, drop no loot, thaw the
# map back to exploration. Guards against soft-locks when an enemy is unreachable.
func _on_flee() -> void:
	if not _flee_available():
		return
	_exit_aim()
	GameState.hp = CombatManager.units.get("player", {}).get("hp", GameState.hp)
	CombatManager.abort_combat()
	_log("[color=#9bbcd8]You break off and slip away.[/color]")
	# _resume_explore() thaws the map (or returns to the worldmap if this was a
	# random encounter). No loot panel and no game-over — this isn't a win or loss.
	_resume_explore()


func _update_mode_label() -> void:
	match _aim:
		Aim.NONE:  _mode_lbl.visible = false
		Aim.MOVE:  _mode_lbl.text = "[ MOVE — click a highlighted hex ]"; _mode_lbl.visible = true
		Aim.QUICK: _mode_lbl.text = "[ QUICK SHOT — click an enemy ]"; _mode_lbl.visible = true
		Aim.AIMED: _mode_lbl.text = "[ AIMED SHOT — click an enemy ]"; _mode_lbl.visible = true
		Aim.BURST: _mode_lbl.text = "[ BURST — click an enemy ]"; _mode_lbl.visible = true
		Aim.MELEE: _mode_lbl.text = "[ MELEE — click an adjacent enemy ]"; _mode_lbl.visible = true


func _refresh_combat_hud() -> void:
	var active := CombatManager.is_player_turn()
	_move_btn.disabled = not active
	_end_btn.disabled  = not active
	var pu: Dictionary = CombatManager.units.get("player", {})
	var weapon := DataManager.get_item(pu.get("equipped_weapon_id", ""))
	var clip: int    = CombatCalc.weapon_clip_size(weapon)
	var needs: bool  = CombatCalc.weapon_needs_ammo(weapon)
	var loaded: int  = pu.get("ammo_loaded", 0)
	var reserve: int = pu.get("ammo_reserve", 0)
	var ap: int      = CombatManager.get_ap("player")
	var has_ammo: bool = not needs or loaded > 0
	var no_aimed: bool = bool(pu.get("mods", {}).get("no_aimed", false))
	var has_burst: bool = int(weapon.get("burst", 0)) > 0
	_quick_btn.disabled = not active or not has_ammo
	_aimed_btn.disabled = not active or not has_ammo or no_aimed
	_burst_btn.disabled = not active or not has_ammo or not has_burst
	_reload_btn.disabled = not (active and clip > 0 and loaded < clip \
		and (reserve > 0 or reserve == 999) and ap >= CombatCalc.RELOAD_AP_COST)
	_item_btn.disabled = not (active and GameState.has_item("stimpak") and ap >= CombatCalc.USE_ITEM_AP_COST)
	_melee_btn.disabled = not (active and ap >= CombatCalc.MELEE_AP_COST \
		and CombatManager.get_melee_targets("player").size() > 0)
	# Fail-safe: let the player disengage on their turn once no living enemy is
	# within FLEE_SAFE_RADIUS, so a fled/unreachable enemy can never soft-lock.
	_flee_btn.disabled = not (active and _flee_available())
	_refresh_weapon_label()


func _refresh_weapon_label() -> void:
	var pu: Dictionary = CombatManager.units.get("player", {})
	if pu.is_empty():
		return
	_hp_lbl.text = "HP: %d/%d" % [pu.get("hp", 0), pu.get("hp_max", 1)]
	var weapon := DataManager.get_item(pu.get("equipped_weapon_id", ""))
	var wname: String = weapon.get("name", "Bare Hands") if not weapon.is_empty() else "Bare Hands"
	var clip: int = CombatCalc.weapon_clip_size(weapon)
	if clip > 0:
		var loaded: int  = pu.get("ammo_loaded", 0)
		var reserve: int = pu.get("ammo_reserve", 0)
		_weapon_lbl.text = "%s  [∞]" % wname if reserve == 999 else "%s  [%d | %d]" % [wname, loaded, reserve]
	else:
		_weapon_lbl.text = wname


func _refresh_turn_list() -> void:
	for c in _turn_list.get_children():
		c.queue_free()
	for uid: String in CombatManager._initiative.get_order():
		var u: Dictionary = CombatManager.units.get(uid, {})
		if u.get("dead", false):
			continue
		var st: Dictionary = u.get("statuses", {})
		var sfx := ""
		if st.get("stun", 0) > 0: sfx += " [STN]"
		if st.get("bleed", 0) > 0: sfx += " [BLD]"
		if st.get("poison", 0) > 0: sfx += " [PSN]"
		if st.get("radiation", 0) > 0: sfx += " [RAD]"
		if u.get("legs_crippled", false): sfx += " [LEG]"
		if u.get("arms_crippled", false): sfx += " [ARM]"
		var l := _mk_label("%s  %d/%d%s" % [u.get("display_name", uid), u.get("hp", 0), u.get("hp_max", 1), sfx], 17)
		if uid == CombatManager.current_unit_id:
			l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		_turn_list.add_child(l)


func _log(msg: String) -> void:
	_log_box.append_text(msg + "\n")


func _on_leveled_up(new_level: int, rewards: Dictionary) -> void:
	var parts: Array = ["+%d skill points" % int(rewards.get("skill_points", 0))]
	if int(rewards.get("perk_picks", 0)) > 0:
		parts.append("choose a perk")
	if int(rewards.get("stat_points", 0)) > 0:
		parts.append("+1 stat to assign")
	AudioManager.play_sfx("confirm")
	_banner("LEVEL %d!  %s" % [new_level, ", ".join(parts)], Color(1.0, 0.86, 0.35))


# A center-screen banner that rises and fades. Works in explore or combat.
func _banner(text: String, color: Color) -> void:
	var l := _mk_label(text, 34, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5; l.anchor_right = 0.5
	l.anchor_top = 0.32; l.anchor_bottom = 0.32
	l.offset_left = -360; l.offset_right = 360; l.offset_top = -24; l.offset_bottom = 24
	_ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _float(world_pos: Vector2, text: String, color: Color) -> void:
	var screen := get_viewport().get_canvas_transform() * world_pos
	var l := _mk_label(text, 21, color)
	l.position = screen + Vector2(-22, -34)
	_combat_hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ════════════════════════════════════════════════════════════════════════════════
# Explore HUD + overlays
# ════════════════════════════════════════════════════════════════════════════════

func _build_explore_hud() -> void:
	_explore_bar = Control.new()
	_explore_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_explore_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_explore_bar)

	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 8; top.offset_top = 6; top.offset_right = -8
	_explore_bar.add_child(top)
	_loc_label = _mk_label("Location", 18)
	_loc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_loc_label)
	_time_label = _mk_label("Day 1  08:00", 18)
	top.add_child(_time_label)

	var btns := HBoxContainer.new()
	btns.anchor_top = 1.0; btns.anchor_bottom = 1.0
	btns.offset_left = 10; btns.offset_top = -68; btns.offset_bottom = -10
	_explore_bar.add_child(btns)
	_mk_btn("Char", btns, _open_character)
	_mk_btn("Inv",  btns, _open_inventory)
	_mk_btn("Jrnl", btns, _open_journal)
	_mk_btn("Leave", btns, _on_leave)

	# Examine panel
	_examine_panel = PanelContainer.new()
	_examine_panel.visible = false
	_examine_panel.anchor_left = 0.5; _examine_panel.anchor_top = 0.5
	_examine_panel.anchor_right = 0.5; _examine_panel.anchor_bottom = 0.5
	_examine_panel.offset_left = -200; _examine_panel.offset_top = -110
	_examine_panel.offset_right = 200; _examine_panel.offset_bottom = 110
	_ui.add_child(_examine_panel)
	var vb := VBoxContainer.new()
	_examine_panel.add_child(vb)
	_examine_title = _mk_label("Examine", 20)
	vb.add_child(_examine_title)
	_examine_text = RichTextLabel.new()
	_examine_text.fit_content = true
	_examine_text.custom_minimum_size = Vector2(360, 120)
	vb.add_child(_examine_text)
	# Optional skill-use action (Repair/Science/Medicine/etc. on a world object).
	_examine_skill_btn = Button.new()
	_examine_skill_btn.visible = false
	_examine_skill_btn.pressed.connect(_on_examine_skill)
	vb.add_child(_examine_skill_btn)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _examine_panel.visible = false)
	vb.add_child(close)


func _refresh_explore_hud() -> void:
	_loc_label.text = _map_data.get("display_name", GameState.current_location)
	var h: int = GameState.world_time_hours
	@warning_ignore("integer_division")
	_time_label.text = "Day %d  %02d:00" % [h / 24 + 1, h % 24]


func _instantiate_overlays() -> void:
	var dlg := load("res://scenes/dialogue/dialogue_box.tscn")
	if dlg:
		_dialogue_box = dlg.instantiate()
		_dialogue_box.visible = false
		_ui.add_child(_dialogue_box)
		DialogueManager.conversation_ended.connect(
			func(_npc: String, _done: bool) -> void:
				if _dialogue_box: _dialogue_box.visible = false)
	# A dialogue choice/node flagged open_shop ends the conversation and asks us to
	# open the vendor's trade screen.
	DialogueManager.shop_requested.connect(_open_shop)
	# Story content (final dialogue or main-quest completion) can roll the ending.
	if not GameState.ending_requested.is_connected(_on_ending_requested):
		GameState.ending_requested.connect(_on_ending_requested)


# Switch to the ending screen on the next idle frame (so any in-flight dialogue teardown
# finishes first). Deferred to avoid changing scenes mid-signal.
func _on_ending_requested(_ending_id: String) -> void:
	call_deferred("_go_to_ending")


func _go_to_ending() -> void:
	get_tree().change_scene_to_file("res://scenes/ending/ending_screen.tscn")


# True if an actor is present at the current world hour. An actor with no `active_hours`
# is always present; `active_hours: [start, end]` may wrap past midnight (e.g. [20, 6]).
func _actor_active_now(d: Dictionary) -> bool:
	var hours: Variant = d.get("active_hours", [])
	if not (hours is Array) or (hours as Array).size() != 2:
		return true
	var hour: int  = GameState.world_time_hours % 24
	var start: int = int(hours[0])
	var end: int   = int(hours[1])
	if start == end:
		return true
	if start < end:
		return hour >= start and hour < end
	return hour >= start or hour < end   # wraps midnight


# Tint the whole world canvas by time of day (UI lives on a separate CanvasLayer, so it
# stays at full brightness). Recomputed each time the map loads.
func _apply_daynight() -> void:
	if _daynight == null:
		_daynight = CanvasModulate.new()
		add_child(_daynight)
	_daynight.color = _time_tint(GameState.world_time_hours % 24)


func _time_tint(hour: int) -> Color:
	var day   := Color(1.0, 1.0, 1.0)
	var night := Color(0.42, 0.47, 0.66)
	if hour >= 9 and hour < 17:
		return day
	if hour >= 6 and hour < 9:               # dawn: night -> day, warmed
		var t := float(hour - 6) / 3.0
		return night.lerp(day, t).lerp(Color(0.98, 0.82, 0.66), 0.25 * (1.0 - absf(t - 0.5) * 2.0))
	if hour >= 17 and hour < 21:             # dusk: day -> night, warmed
		var t := float(hour - 17) / 4.0
		return day.lerp(night, t).lerp(Color(0.90, 0.60, 0.50), 0.25 * (1.0 - absf(t - 0.5) * 2.0))
	return night


func _show_examine(title: String, text: String, skill_use: Dictionary = {}) -> void:
	_examine_title.text = title
	_examine_text.text  = text
	_configure_skill_button(skill_use)
	_examine_panel.visible = true


# Show or hide the "[Use <skill> <dc>]" action on the examine card based on the object's
# optional skill_use block. Hidden once the object's done_flag (if any) is set.
func _configure_skill_button(skill_use: Dictionary) -> void:
	_examine_skill_ctx = {}
	if _examine_skill_btn == null:
		return
	var done_flag: String = skill_use.get("done_flag", "")
	if skill_use.is_empty() or (done_flag != "" and GameState.get_flag(done_flag)):
		_examine_skill_btn.visible = false
		return
	var skill: String = skill_use.get("skill", "tech")
	var dc: int       = int(skill_use.get("difficulty", 50))
	var prompt: String = skill_use.get("prompt", "Attempt")
	_examine_skill_btn.text = "[%s %d] %s" % [skill.capitalize(), dc, prompt]
	_examine_skill_btn.visible = true
	_examine_skill_ctx = {"skill_use": skill_use}


# Roll the world-object skill check and apply its success/fail outcome.
func _on_examine_skill() -> void:
	var skill_use: Dictionary = _examine_skill_ctx.get("skill_use", {})
	if skill_use.is_empty():
		return
	var skill: String = skill_use.get("skill", "tech")
	var dc: int       = int(skill_use.get("difficulty", 50))
	var res := SkillCheck.resolve(skill, dc)
	var passed: bool  = res.get("passed", false)
	var block: Dictionary = skill_use.get("success", {}) if passed else skill_use.get("fail", {})
	_apply_skill_outcome(block)
	if passed and skill_use.get("done_flag", "") != "":
		GameState.set_flag(skill_use["done_flag"], true)
	var skill_val: int = GameState.skills.get(skill, 0)
	var result_text: String = block.get("text", "Success." if passed else "It doesn't work.")
	_examine_text.text = "%s\n\n[%s %d vs DC %d — %s]" % [
		result_text, skill.capitalize(), skill_val, dc, "PASS" if passed else "FAIL"]
	AudioManager.play_sfx("confirm" if passed else "error")
	# Re-evaluate: a passed check with a done_flag hides the button; a fail can be retried.
	_configure_skill_button(skill_use)


# Apply the rewards/flags of a skill-use outcome block (reused success or fail shape).
func _apply_skill_outcome(block: Dictionary) -> void:
	for flag_id in block.get("flags_set", []):
		GameState.set_flag(flag_id, true)
	for reward: Dictionary in block.get("item_rewards", []):
		GameState.add_item(reward.get("item_id", ""), int(reward.get("quantity", 1)))
	if block.has("caps_reward"):
		GameState.caps += int(block["caps_reward"])
		GameState.state_changed.emit()
	if block.has("xp_reward"):
		GameState.add_xp(int(block["xp_reward"]))
	if block.has("karma_change"):
		GameState.add_karma(int(block["karma_change"]))


func _any_panel_open() -> bool:
	if _examine_panel and _examine_panel.visible: return true
	if _dialogue_box and _dialogue_box.visible: return true
	if _loot_panel_node != null: return true
	if is_instance_valid(_shop_panel_node): return true
	for p in _overlay_stack:
		if is_instance_valid(p):
			return true
	return false


func _close_panels() -> void:
	if _examine_panel: _examine_panel.visible = false
	if _dialogue_box: _dialogue_box.visible = false
	if _loot_panel_node:
		_loot_panel_node.queue_free()
		_loot_panel_node = null
	if is_instance_valid(_shop_panel_node):
		_shop_panel_node.queue_free()
	_shop_panel_node = null


# Open a vendor's buy/sell screen. Driven by DialogueManager.shop_requested, which
# fires after a conversation node flagged open_shop completes.
func _open_shop(npc_id: String) -> void:
	if is_instance_valid(_shop_panel_node):
		return
	var npc := DataManager.get_npc(npc_id)
	var vendor: Dictionary = npc.get("vendor", {})
	if vendor.is_empty():
		return
	var scene := load("res://scenes/ui/shop_panel.tscn")
	if scene == null:
		return
	var panel = scene.instantiate()
	_shop_panel_node = panel
	panel.tree_exited.connect(func() -> void: _shop_panel_node = null)
	_ui.add_child(panel)
	_overlay_stack.append(panel)          # so Escape closes it like other overlays
	panel.init(npc.get("name", npc_id), vendor)   # @onready vars need the node in-tree first
	if panel is CanvasItem:
		panel.move_to_front()


func _open_character() -> void:
	_open_overlay("res://scenes/ui/character_sheet.tscn")


func _open_inventory() -> void:
	_open_overlay("res://scenes/ui/inventory_panel.tscn")


func _open_journal() -> void:
	_open_overlay("res://scenes/ui/quest_journal.tscn")


func _open_overlay(path: String) -> void:
	var scene := load(path)
	if scene == null:
		return
	var panel = scene.instantiate()
	_ui.add_child(panel)
	_overlay_stack.append(panel)
	if panel is CanvasItem:
		panel.move_to_front()


func _on_leave() -> void:
	if _mode == Mode.COMBAT:
		return
	_save_position()
	get_tree().change_scene_to_file("res://scenes/world/worldmap.tscn")


func _save_position() -> void:
	# Persist where the player stood so re-entering the map feels continuous.
	var state := GameState.get_exploration_state(_map_id)
	state["player_q"] = _player_hex.x
	state["player_r"] = _player_hex.y
