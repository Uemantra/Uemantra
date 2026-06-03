class_name HexGrid
extends RefCounted

# Flat-top axial hex coordinate system with isometric y-squash.
# q = column axis, r = row axis (diagonal).
# ISO_SQUASH compresses vertical spacing to give the classic isometric depth illusion.

const HEX_SIZE   := 48.0
const ISO_SQUASH := 0.60

# Flat-top neighbor directions: E, NE, NW, W, SW, SE
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1,  0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0,  1),
]


static func hex_to_pixel(hex: Vector2i, size: float = HEX_SIZE) -> Vector2:
	return Vector2(
		size * 1.5 * hex.x,
		size * sqrt(3.0) * (hex.y + hex.x * 0.5) * ISO_SQUASH
	)


static func pixel_to_hex(pos: Vector2, size: float = HEX_SIZE) -> Vector2i:
	var q := pos.x / (size * 1.5)
	var r := pos.y / (size * sqrt(3.0) * ISO_SQUASH) - q * 0.5
	return _axial_round(q, r)


static func _axial_round(fq: float, fr: float) -> Vector2i:
	var fs  := -fq - fr
	var rq  := roundf(fq)
	var rr  := roundf(fr)
	var rs  := roundf(fs)
	if abs(rq - fq) > abs(rr - fr) and abs(rq - fq) > abs(rs - fs):
		rq = -rr - rs
	elif abs(rr - fr) > abs(rs - fs):
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (abs(d.x) + abs(d.x + d.y) + abs(d.y)) / 2


static func neighbors(hex: Vector2i) -> Array:
	var result: Array = []
	for d: Vector2i in DIRECTIONS:
		result.append(hex + d)
	return result


# Polygon vertices for drawing a hex centred at `centre` (flat-top, iso squash).
static func hex_corners(centre: Vector2, size: float = HEX_SIZE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 3.0 * i
		pts.append(centre + Vector2(cos(a) * size, sin(a) * size * ISO_SQUASH))
	return pts


# BFS — returns {Vector2i: ap_cost} for all hexes reachable within ap_budget.
static func get_reachable(start: Vector2i, ap_budget: int,
		cost_per_hex: int, blocked: Array) -> Dictionary:
	var visited: Dictionary = {start: 0}
	var frontier: Array     = [start]
	while not frontier.is_empty():
		var next: Array = []
		for hex: Vector2i in frontier:
			var cur: int = visited[hex]
			for nb: Vector2i in neighbors(hex):
				if nb in blocked:
					continue
				var cost: int = cur + cost_per_hex
				if cost <= ap_budget and (not visited.has(nb) or visited[nb] > cost):
					visited[nb] = cost
					next.append(nb)
		frontier = next
	visited.erase(start)
	return visited


# A* — returns path from start to goal (start excluded), or [] if unreachable.
static func find_path(start: Vector2i, goal: Vector2i, blocked: Array) -> Array:
	if goal in blocked:
		return []
	var open_set: Array    = [start]
	var came_from: Dictionary = {}
	var g: Dictionary      = {start: 0}
	var f: Dictionary      = {start: distance(start, goal)}

	while not open_set.is_empty():
		var cur: Vector2i = _min_f(open_set, f)
		if cur == goal:
			return _reconstruct(came_from, cur, start)
		open_set.erase(cur)
		for nb: Vector2i in neighbors(cur):
			if nb in blocked:
				continue
			var tg: int = g.get(cur, 9999) + 1
			if tg < g.get(nb, 9999):
				came_from[nb] = cur
				g[nb]         = tg
				f[nb]         = tg + distance(nb, goal)
				if nb not in open_set:
					open_set.append(nb)
	return []


static func _min_f(open_set: Array, f: Dictionary) -> Vector2i:
	var best: Vector2i = open_set[0]
	for h: Vector2i in open_set:
		if f.get(h, 9999) < f.get(best, 9999):
			best = h
	return best


static func _reconstruct(came_from: Dictionary,
		current: Vector2i, start: Vector2i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	if not path.is_empty() and path[0] == start:
		path.pop_front()
	return path


# Returns all hexes on the straight line from a to b (inclusive).
# Tiny nudge prevents ambiguous rounding at hex edges.
static func hex_line(a: Vector2i, b: Vector2i) -> Array:
	var n := distance(a, b)
	if n == 0:
		return [a]
	var results: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		results.append(_axial_round(
			lerpf(float(a.x) + 1e-4, float(b.x) - 1e-4, t),
			lerpf(float(a.y) + 1e-4, float(b.y) - 1e-4, t)
		))
	return results
