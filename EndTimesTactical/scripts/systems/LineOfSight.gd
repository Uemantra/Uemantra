class_name LineOfSight
extends RefCounted

const COVER_NONE    := 0
const COVER_PARTIAL := 1
const COVER_FULL    := 2


# True if no opaque hex interrupts the straight line between from_hex and to_hex.
static func has_los(from_hex: Vector2i, to_hex: Vector2i,
		opaque_hexes: Array) -> bool:
	var line := HexGrid.hex_line(from_hex, to_hex)
	for i in range(1, line.size() - 1):
		if line[i] in opaque_hexes:
			return false
	return true


# Returns the highest cover level found on hexes along the LOS path.
# cover_map: Dictionary[Vector2i -> COVER_* constant]
static func get_cover(from_hex: Vector2i, to_hex: Vector2i,
		cover_map: Dictionary) -> int:
	var line := HexGrid.hex_line(from_hex, to_hex)
	var best := COVER_NONE
	for i in range(1, line.size() - 1):
		var c: int = cover_map.get(line[i], COVER_NONE)
		if c > best:
			best = c
	return best
