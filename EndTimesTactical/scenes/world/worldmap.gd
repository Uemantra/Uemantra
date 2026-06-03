extends Node2D
## Fallout-style wasteland travel map.
##
## A marker you steer across open terrain. Click a known settlement to travel to
## it and enter it; click open ground to wander. Time passes with distance, the
## map reveals as you approach landmarks, and travel can be interrupted by random
## encounters that drop you onto a local hex map already in combat.

const WORLD_SCALE  := Vector2(2.4, 2.4)   # data-space (world.json positions) -> map pixels
const WORLD_OFFSET := Vector2(40, 40)
const SPEED        := 130.0               # marker pixels / second
const ARRIVE_DIST  := 6.0
const TOWN_RADIUS  := 22.0                # icon size / click target
const REVEAL_DIST  := 130.0               # come this close and an unknown site appears
const ENTER_DIST   := 26.0                # arrive within this of a town to enter it
const HOURS_PER_PX := 0.012
const ENC_INTERVAL := 110.0               # check for an encounter every N px travelled
const ENC_CHANCE   := 0.28

const ENCOUNTER_POOL := ["iron_grunt", "iron_grunt_b", "iron_sentinel"]

var _cam:    Camera2D
var _marker: Node2D
var _ui:     CanvasLayer
var _info:   Label
var _time_label: Label

var _towns: Array = []        # [{ id, pos: Vector2, data: Dictionary }]
var _dest_active: bool = false
var _dest: Vector2 = Vector2.ZERO
var _target_town: String = ""
var _enc_accum: float = 0.0
var _time_accum: float = 0.0


func _ready() -> void:
	randomize()
	_build_nodes()
	_load_towns()
	_place_marker()
	_build_ui()
	_reveal_near_marker()
	queue_redraw()
	_refresh_info()


func _build_nodes() -> void:
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.0, 1.0)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	add_child(_cam)

	_marker = Node2D.new()
	_marker.z_index = 5
	add_child(_marker)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(0, -14), Vector2(11, 11), Vector2(-11, 11)])
	tri.color = Color(0.9, 0.8, 0.25)
	_marker.add_child(tri)
	var dot := Polygon2D.new()
	dot.polygon = _circle(4.5)
	dot.color = Color(0.2, 0.15, 0.05)
	_marker.add_child(dot)


func _load_towns() -> void:
	for node_data: Dictionary in DataManager.get_world().get("nodes", []):
		var p: Dictionary = node_data.get("position", {"x": 0, "y": 0})
		_towns.append({
			"id":   node_data.get("id", ""),
			"pos":  Vector2(p.get("x", 0), p.get("y", 0)) * WORLD_SCALE + WORLD_OFFSET,
			"data": node_data,
		})


func _place_marker() -> void:
	if GameState.worldmap_pos != Vector2.ZERO:
		_marker.position = GameState.worldmap_pos
	else:
		_marker.position = _town_pos(GameState.current_location)
	_cam.global_position = _marker.position


func _town_pos(town_id: String) -> Vector2:
	for t: Dictionary in _towns:
		if t["id"] == town_id:
			return t["pos"]
	return Vector2(400, 300)


# ─── UI ──────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 42
	_ui.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	_info = Label.new()
	_info.text = "The Wasteland"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 18)
	row.add_child(_info)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_time_label)

	var hint := Label.new()
	hint.text = "Click a settlement to travel there and enter it · click open ground to scout"
	hint.anchor_top = 1.0; hint.anchor_bottom = 1.0; hint.anchor_right = 1.0
	hint.offset_top = -34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.5))
	_ui.add_child(hint)


func _refresh_info() -> void:
	var h: int = GameState.world_time_hours
	@warning_ignore("integer_division")
	_time_label.text = "Day %d  %02d:00   " % [h / 24 + 1, h % 24]


# ─── Travel ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click := get_global_mouse_position()
	var town := _town_at(click)
	if town != "":
		_dest = _town_pos(town)
		_target_town = town
	else:
		_dest = click
		_target_town = ""
	_dest_active = true
	_refresh_info()
	if _target_town != "":
		_info.text = "Travelling to %s…" % _town_display(_target_town)
	else:
		_info.text = "Scouting the wasteland…"


func _town_at(world_pos: Vector2) -> String:
	for t: Dictionary in _towns:
		if not _is_visible_town(t):
			continue
		if world_pos.distance_to(t["pos"]) <= TOWN_RADIUS + 6.0:
			return t["id"]
	return ""


func _process(delta: float) -> void:
	if not _dest_active:
		return
	var to := _dest - _marker.position
	var dist := to.length()
	var step: float = min(SPEED * delta, dist)
	_marker.position += to.normalized() * step if dist > 0.001 else Vector2.ZERO
	_cam.global_position = _marker.position
	_advance_clock(step)
	_reveal_near_marker()

	if dist - step <= ARRIVE_DIST:
		_marker.position = _dest
		_dest_active = false
		_arrive()
		return

	# Encounters only while crossing open ground.
	_enc_accum += step
	if _enc_accum >= ENC_INTERVAL:
		_enc_accum = 0.0
		if _target_town == "" or _marker.position.distance_to(_dest) > ENTER_DIST * 2.0:
			if randf() < ENC_CHANCE:
				_trigger_encounter()


func _advance_clock(px: float) -> void:
	_time_accum += px * HOURS_PER_PX
	while _time_accum >= 1.0:
		_time_accum -= 1.0
		GameState.world_time_hours += 1
	_refresh_info()


func _arrive() -> void:
	if _target_town != "":
		_enter_town(_target_town)
	else:
		_info.text = "The Wasteland"


func _enter_town(town_id: String) -> void:
	GameState.discover_location(town_id)
	GameState.current_location = town_id
	GameState.worldmap_pos = _marker.position
	if town_id not in GameState.visited_locations:
		GameState.visited_locations.append(town_id)
	GameState.state_changed.emit()
	get_tree().change_scene_to_file("res://scenes/world/local_map.tscn")


func _reveal_near_marker() -> void:
	var changed := false
	for t: Dictionary in _towns:
		if GameState.is_location_discovered(t["id"]):
			continue
		if _marker.position.distance_to(t["pos"]) <= REVEAL_DIST:
			GameState.discover_location(t["id"])
			changed = true
	if changed:
		queue_redraw()


func _is_visible_town(t: Dictionary) -> bool:
	return GameState.is_location_discovered(t["id"]) \
		or _marker.position.distance_to(t["pos"]) <= REVEAL_DIST


# ─── Random encounters ────────────────────────────────────────────────────────

func _trigger_encounter() -> void:
	_dest_active = false
	GameState.worldmap_pos = _marker.position
	GameState.pending_encounter = _make_encounter()
	get_tree().change_scene_to_file("res://scenes/world/local_map.tscn")


# Random encounters drop onto a generated battlefield. Rather than a featureless
# box, each picks a scenario (roadside / ruins / raider camp / dry wash) and lays
# down themed terrain + props so it reads as a real place — using the same terrain
# chars and prop kinds the authored local maps do.
const ENCOUNTER_SCENES := [
	{"id": "roadside", "name": "Roadside Ambush"},
	{"id": "ruins",    "name": "Ruined Outpost"},
	{"id": "camp",     "name": "Raider Camp"},
	{"id": "wash",     "name": "Dry Wash"},
]


func _make_encounter() -> Dictionary:
	var w := 20
	var h := 13
	@warning_ignore("integer_division")
	var mid := h / 2
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var scene: Dictionary = ENCOUNTER_SCENES[rng.randi() % ENCOUNTER_SCENES.size()]
	var kind: String = scene["id"]
	var base := "g" if kind == "roadside" or kind == "wash" else "."

	# Start everything as open ground.
	var grid: Array = []
	for r in h:
		var row: Array = []
		for q in w:
			row.append(base)
		grid.append(row)

	# A light scatter of cover / debris everywhere for tactical texture.
	for _i in 12:
		var sx := rng.randi_range(3, w - 2)
		var sy := rng.randi_range(1, h - 2)
		grid[sy][sx] = ["o", "o", "+", "#", "g"][rng.randi() % 5]

	var props: Array = []
	match kind:
		"roadside":
			for x in w:
				grid[mid][x] = "r"
				grid[mid - 1][x] = "r"
			for wx in [6, 13]:
				grid[mid][wx] = "#"
				props.append({"prop": "wreck", "q": wx, "r": mid})
			props.append({"prop": "dead_tree", "q": 3, "r": 2})
			props.append({"prop": "dead_tree", "q": w - 3, "r": h - 2})
		"ruins":
			var bx := rng.randi_range(7, 11)
			for x in range(bx, bx + 6):
				grid[2][x] = "W"
			for y in range(2, 6):
				grid[y][bx] = "W"; grid[y][bx + 5] = "W"
			for y in range(3, 6):
				for x in range(bx + 1, bx + 5):
					grid[y][x] = "_"
			grid[2][bx + 2] = "_"            # doorway
			props.append({"prop": "shack", "q": bx + 2, "r": 2})
			for _i in 6:
				grid[rng.randi_range(2, h - 2)][rng.randi_range(2, w - 2)] = "+"
		"camp":
			var cx := int(w / 2.0)
			props.append({"prop": "campfire", "q": cx, "r": mid})
			for off in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(0, 2)]:
				props.append({"prop": "tent", "q": cx + off.x, "r": mid + off.y})
			for off in [Vector2i(-1, 1), Vector2i(1, 1)]:
				props.append({"prop": "barrel", "q": cx + off.x, "r": mid + off.y})
			grid[mid - 2][cx] = "o"; grid[mid + 2][cx] = "o"
		"wash":
			var cx := int(w / 2.0)
			for y in h:
				var x: int = clampi(cx + int(round(sin(y * 0.6) * 2.0)), 1, w - 2)
				grid[y][x] = "~"
			props.append({"prop": "dead_tree", "q": 3, "r": 3})
			props.append({"prop": "wreck", "q": w - 4, "r": h - 3})

	# Guarantee a walkable corridor across the mid row so the player can always
	# reach the enemies (and they can path back) whatever the scenario rolled.
	for x in range(1, w - 1):
		if grid[mid][x] in ["#", "W", "~"]:
			grid[mid][x] = "+"
	for x in range(1, 4):
		grid[mid][x] = base   # clear left landing pocket

	# Clear the right-side staging area so the enemy cluster is always open and
	# connected to the mid-row corridor (no enemy can spawn walled off).
	for ry in range(maxi(1, mid - 2), mini(h - 1, mid + 3)):
		for rx in range(w - 6, w - 1):
			if grid[ry][rx] in ["#", "W", "~"]:
				grid[ry][rx] = base

	# Enemies hold the right side, clustered around the mid row on open footing.
	var count := randi_range(1, 3)
	var actors: Array = []
	for i in count:
		var npc_id: String = ENCOUNTER_POOL[rng.randi() % ENCOUNTER_POOL.size()]
		var er := clampi(mid - 2 + i * 2, 1, h - 2)
		var eq := w - 4
		grid[er][eq] = base
		grid[er][eq - 1] = base
		actors.append({
			"id":      "enc_enemy_%d" % i,
			"type":    "enemy",
			"npc_id":  npc_id,
			"q":       eq,
			"r":       er,
			"glyph":   "E",
			"color":   "#cc3322",
		})

	var rows: Array = []
	for row: Array in grid:
		rows.append("".join(row))

	return {
		"id":           "wasteland_encounter",
		"display_name": scene["name"],
		"width":        w,
		"height":       h,
		"vision_radius": 7,
		"player_start": {"q": 2, "r": mid},
		"terrain":      rows,
		"actors":       actors,
		"props":        props,
	}


# ─── Drawing the wasteland ────────────────────────────────────────────────────

func _draw() -> void:
	# Bounds covering all towns plus margin.
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for t: Dictionary in _towns:
		min_p = min_p.min(t["pos"])
		max_p = max_p.max(t["pos"])
	min_p -= Vector2(220, 180)
	max_p += Vector2(220, 180)

	# Ground.
	draw_rect(Rect2(min_p, max_p - min_p), Color(0.20, 0.17, 0.12))

	# Procedural terrain speckle (deterministic).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for _i in 220:
		var p := Vector2(rng.randf_range(min_p.x, max_p.x), rng.randf_range(min_p.y, max_p.y))
		var kind := rng.randi() % 3
		match kind:
			0:  # scrub
				draw_circle(p, rng.randf_range(1.5, 3.0), Color(0.26, 0.24, 0.15))
			1:  # rocks / hills
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-6, 4), p + Vector2(0, -6), p + Vector2(6, 4)]),
					Color(0.30, 0.27, 0.21))
			2:  # crater / rad
				draw_arc(p, rng.randf_range(8, 18), 0, TAU, 18, Color(0.16, 0.20, 0.10), 1.5)

	# Roads between known, connected settlements.
	for t: Dictionary in _towns:
		if not _is_visible_town(t):
			continue
		for conn: Dictionary in t["data"].get("connections", []):
			var other := _town_pos(conn.get("to", ""))
			var other_data := _find_town(conn.get("to", ""))
			if other_data.is_empty() or not _is_visible_town(other_data):
				continue
			draw_dashed_line(t["pos"], other, Color(0.36, 0.30, 0.18), 2.0, 8.0)

	# Settlement icons + labels.
	for t: Dictionary in _towns:
		if not _is_visible_town(t):
			continue
		var p: Vector2 = t["pos"]
		var is_here: bool = t["id"] == GameState.current_location
		draw_circle(p, TOWN_RADIUS, Color(0.10, 0.09, 0.07))
		draw_arc(p, TOWN_RADIUS, 0, TAU, 24,
			Color(0.9, 0.8, 0.3) if is_here else Color(0.55, 0.48, 0.28), 2.0)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)),
			Color(0.8, 0.72, 0.4) if is_here else Color(0.5, 0.45, 0.3))
		var town_name: String = t["data"].get("display_name", t["id"])
		var font := ThemeDB.fallback_font
		draw_string(font, p + Vector2(-town_name.length() * 4.8, TOWN_RADIUS + 22),
			town_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.8, 0.65))


func _find_town(town_id: String) -> Dictionary:
	for t: Dictionary in _towns:
		if t["id"] == town_id:
			return t
	return {}


func _town_display(town_id: String) -> String:
	var t := _find_town(town_id)
	return t.get("data", {}).get("display_name", town_id) if not t.is_empty() else town_id


static func _circle(radius: float, sides: int = 12) -> PackedVector2Array:
	var v := PackedVector2Array()
	for i in sides:
		var a := float(i) / float(sides) * TAU
		v.append(Vector2(cos(a) * radius, sin(a) * radius))
	return v
