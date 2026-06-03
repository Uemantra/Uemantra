class_name TerrainDB
extends RefCounted

# Single source of truth for hex terrain. Every terrain type declares its authoring
# char (used in data/local_maps/*.json), whether units can stand on it, whether it
# blocks line of sight, and how much cover it grants in a firefight. Both the
# explore/combat map (local_map.gd) and the turn engine (CombatManager.gd) query
# this, so adding a terrain type is a ONE-place change here — no scattered
# `== "obstacle"` string checks. Pure-visual styling lives in local_map.gd, keyed
# off these same ids.
#
#   walk   — a unit may move onto / through this hex
#   opaque — this hex blocks line of sight (and therefore ranged fire / vision)
#   cover  — cover level granted to a target standing behind it: 0 none, 1 partial, 2 full

const TERRAIN := {
	"floor":         { "char": ".", "walk": true,  "opaque": false, "cover": 0 },
	"road":          { "char": "r", "walk": true,  "opaque": false, "cover": 0 },
	"grass":         { "char": "g", "walk": true,  "opaque": false, "cover": 0 },
	"interior":      { "char": "_", "walk": true,  "opaque": false, "cover": 0 },
	"cover_partial": { "char": "o", "walk": true,  "opaque": false, "cover": 1 },
	"cover_full":    { "char": "O", "walk": true,  "opaque": false, "cover": 2 },
	"rubble":        { "char": "+", "walk": true,  "opaque": false, "cover": 1 },
	"obstacle":      { "char": "#", "walk": false, "opaque": true,  "cover": 0 },
	"wall":          { "char": "W", "walk": false, "opaque": true,  "cover": 0 },
	"water":         { "char": "~", "walk": false, "opaque": false, "cover": 0 },
}

# Char ' ' (space) means "no hex here" (void) and is handled by the parser, not listed above.

static var _by_char: Dictionary = {}


static func _ensure() -> void:
	if not _by_char.is_empty():
		return
	for id: String in TERRAIN:
		_by_char[TERRAIN[id]["char"]] = id


# Map an authored char to a terrain id. Unknown chars fall back to plain floor.
static func from_char(ch: String) -> String:
	_ensure()
	return _by_char.get(ch, "floor")


static func is_walkable(id: String) -> bool:
	return TERRAIN.get(id, {}).get("walk", true)


static func is_blocked(id: String) -> bool:
	return not is_walkable(id)


static func is_opaque(id: String) -> bool:
	return TERRAIN.get(id, {}).get("opaque", false)


static func cover_level(id: String) -> int:
	return TERRAIN.get(id, {}).get("cover", 0)
