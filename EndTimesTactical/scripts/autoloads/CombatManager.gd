extends Node

signal combat_started(arena_id: String)
signal combat_ended(victory: bool)
signal turn_started(combatant_id: String, ap_remaining: int)
signal turn_ended(combatant_id: String)
signal combatant_moved(combatant_id: String, from: Vector2i, to: Vector2i)
signal combatant_attacked(attacker_id: String, target_id: String, damage: int, hit: bool)
signal combatant_died(combatant_id: String)
signal status_effect_applied(combatant_id: String, effect_type: String)
signal ap_spent(combatant_id: String, ap_remaining: int)

const GRID_W: int = 10
const GRID_H: int = 10
const MOVE_AP_COST: int = 1
const ITEM_AP_COST: int = 2

var _active: bool = false
var _arena_id: String = ""
var _combatants: Dictionary = {}   # id -> CombatantData dict
var _grid: Dictionary = {}         # Vector2i -> { passable, cover_bonus, occupant_id }
var _initiative_order: Array = []  # ordered list of combatant ids
var _turn_index: int = 0
var _pending_combat_scene_change: bool = false


func start_combat(arena_id: String, enemy_ids: Array) -> void:
	_arena_id = arena_id
	_combatants = {}
	_grid = {}
	_initiative_order = []
	_turn_index = 0
	_active = true

	_add_player_combatant()
	for npc_id in enemy_ids:
		_add_npc_combatant(npc_id)

	_build_initiative_order()
	combat_started.emit(arena_id)
	_start_next_turn()


func end_combat(victory: bool) -> void:
	_active = false
	combat_ended.emit(victory)


func is_active() -> bool:
	return _active


func is_player_turn() -> bool:
	if _initiative_order.is_empty():
		return false
	return _initiative_order[_turn_index % _initiative_order.size()] == "player"


func get_current_combatant() -> String:
	if _initiative_order.is_empty():
		return ""
	return _initiative_order[_turn_index % _initiative_order.size()]


func get_combatant(id: String) -> Dictionary:
	return _combatants.get(id, {})


func get_all_combatants() -> Dictionary:
	return _combatants


func get_ap(combatant_id: String) -> int:
	return _combatants.get(combatant_id, {}).get("ap_current", 0)


func try_move(combatant_id: String, target_cell: Vector2i) -> bool:
	if not _active or not _combatants.has(combatant_id):
		return false
	var cdata: Dictionary = _combatants[combatant_id]
	var from_cell: Vector2i = cdata.get("cell", Vector2i(-1, -1))
	var path := _bfs_path(from_cell, target_cell)
	if path.is_empty():
		return false
	var cost := path.size() * MOVE_AP_COST
	if cdata.get("ap_current", 0) < cost:
		return false
	cdata["ap_current"] -= cost
	_grid[from_cell]["occupant_id"] = ""
	cdata["cell"] = target_cell
	if _grid.has(target_cell):
		_grid[target_cell]["occupant_id"] = combatant_id
	combatant_moved.emit(combatant_id, from_cell, target_cell)
	ap_spent.emit(combatant_id, cdata["ap_current"])
	return true


func try_attack(attacker_id: String, target_id: String) -> Dictionary:
	if not _active:
		return {}
	var attacker: Dictionary = _combatants.get(attacker_id, {})
	var defender: Dictionary = _combatants.get(target_id, {})
	if attacker.is_empty() or defender.is_empty():
		return {}

	var weapon_id: String = attacker.get("weapon_id", "")
	var weapon := DataManager.get_item(weapon_id)
	var ap_cost: int = weapon.get("ap_cost", 2)
	if attacker.get("ap_current", 0) < ap_cost:
		return {"error": "not_enough_ap"}

	attacker["ap_current"] -= ap_cost
	ap_spent.emit(attacker_id, attacker["ap_current"])

	var result := _resolve_attack(attacker_id, target_id, weapon)
	if result.get("hit", false):
		var dmg: int = result.get("damage", 0)
		defender["hp"] = max(0, defender.get("hp", 0) - dmg)
		combatant_attacked.emit(attacker_id, target_id, dmg, true)
		_apply_weapon_effects(target_id, weapon.get("effects", []))
		if defender["hp"] <= 0:
			_on_combatant_died(target_id)
	else:
		combatant_attacked.emit(attacker_id, target_id, 0, false)

	_check_combat_over()
	return result


func end_player_turn() -> void:
	if not is_player_turn():
		return
	turn_ended.emit("player")
	_advance_turn()


func get_valid_moves(combatant_id: String) -> Array:
	var cdata: Dictionary = _combatants.get(combatant_id, {})
	var from_cell: Vector2i = cdata.get("cell", Vector2i(-1, -1))
	var ap: int = cdata.get("ap_current", 0)
	var reachable: Array = []
	for x in GRID_W:
		for y in GRID_H:
			var cell := Vector2i(x, y)
			if cell == from_cell:
				continue
			var tile := _grid.get(cell, {})
			if not tile.get("passable", true):
				continue
			if tile.get("occupant_id", "") != "":
				continue
			var path := _bfs_path(from_cell, cell)
			if not path.is_empty() and path.size() <= ap:
				reachable.append(cell)
	return reachable


func get_valid_targets(attacker_id: String) -> Array:
	var attacker: Dictionary = _combatants.get(attacker_id, {})
	var weapon := DataManager.get_item(attacker.get("weapon_id", ""))
	var range_tiles: int = weapon.get("range_tiles", 1)
	var from_cell: Vector2i = attacker.get("cell", Vector2i(-1, -1))
	var targets: Array = []
	var attacker_team: String = attacker.get("team", "enemy")
	for cid in _combatants:
		if cid == attacker_id:
			continue
		var other: Dictionary = _combatants[cid]
		if other.get("team", "enemy") == attacker_team:
			continue
		if other.get("hp", 0) <= 0:
			continue
		var other_cell: Vector2i = other.get("cell", Vector2i(-1, -1))
		var dist := abs(other_cell.x - from_cell.x) + abs(other_cell.y - from_cell.y)
		if dist <= range_tiles:
			targets.append(cid)
	return targets


func _start_next_turn() -> void:
	if _initiative_order.is_empty():
		return
	var current_id := get_current_combatant()
	var cdata: Dictionary = _combatants.get(current_id, {})
	cdata["ap_current"] = cdata.get("ap_max", 5)
	_tick_status_effects(current_id)
	if cdata.get("skip_turn", false):
		cdata["skip_turn"] = false
		turn_started.emit(current_id, 0)
		_advance_turn()
		return
	turn_started.emit(current_id, cdata["ap_current"])
	if not is_player_turn():
		_run_enemy_turn(current_id)


func _advance_turn() -> void:
	_turn_index = (_turn_index + 1) % _initiative_order.size()
	_start_next_turn()


func _run_enemy_turn(enemy_id: String) -> void:
	var targets := get_valid_targets(enemy_id)
	if not targets.is_empty():
		try_attack(enemy_id, targets[0])
	else:
		_move_toward_nearest_player(enemy_id)
	await get_tree().create_timer(0.5).timeout
	turn_ended.emit(enemy_id)
	_advance_turn()


func _move_toward_nearest_player(enemy_id: String) -> void:
	var enemy: Dictionary = _combatants.get(enemy_id, {})
	var from_cell: Vector2i = enemy.get("cell", Vector2i(-1, -1))
	var best_cell := from_cell
	var best_dist := 999
	for cid in _combatants:
		if _combatants[cid].get("team", "enemy") == "player":
			var pcell: Vector2i = _combatants[cid].get("cell", Vector2i(-1, -1))
			var dist := abs(pcell.x - from_cell.x) + abs(pcell.y - from_cell.y)
			if dist < best_dist:
				best_dist = dist
				best_cell = pcell
	if best_cell == from_cell:
		return
	var dir_x := sign(best_cell.x - from_cell.x)
	var dir_y := sign(best_cell.y - from_cell.y)
	var candidates: Array[Vector2i] = []
	if dir_x != 0:
		candidates.append(Vector2i(from_cell.x + dir_x, from_cell.y))
	if dir_y != 0:
		candidates.append(Vector2i(from_cell.x, from_cell.y + dir_y))
	for candidate in candidates:
		if not _grid.has(candidate):
			continue
		if not _grid[candidate].get("passable", true):
			continue
		if _grid[candidate].get("occupant_id", "") != "":
			continue
		try_move(enemy_id, candidate)
		return


func _resolve_attack(attacker_id: String, target_id: String, weapon: Dictionary) -> Dictionary:
	var attacker: Dictionary = _combatants[attacker_id]
	var defender: Dictionary = _combatants[target_id]
	var skill_name: String = weapon.get("skill_used", "guns")
	var attacker_skill: int
	if attacker_id == "player":
		attacker_skill = GameState.skills.get(skill_name, 50)
	else:
		attacker_skill = attacker.get("skill_value", 45)
	var cover_bonus := _get_cover_bonus(defender.get("cell", Vector2i()), attacker.get("cell", Vector2i()))
	var evasion: int = defender.get("evasion", 10)
	var hit_chance := attacker_skill - evasion - cover_bonus
	hit_chance = clamp(hit_chance, 5, 95)
	var roll := randi_range(1, 100)
	if roll > hit_chance:
		return {"hit": false, "roll": roll, "hit_chance": hit_chance}
	var dmg := _roll_dice(weapon.get("damage_dice", "1d4"))
	if attacker_id == "player":
		var subtype: String = weapon.get("subtype", "")
		if subtype == "melee":
			dmg += GameState.derived.get("melee_dmg_bonus", 0)
	var armor_defense: int = defender.get("armor_defense", 0)
	dmg = max(1, dmg - armor_defense)
	return {"hit": true, "damage": dmg, "roll": roll, "hit_chance": hit_chance}


func _get_cover_bonus(defender_cell: Vector2i, attacker_cell: Vector2i) -> int:
	var diff := defender_cell - attacker_cell
	var dir_x := sign(diff.x)
	var dir_y := sign(diff.y)
	var cover_cell := Vector2i(defender_cell.x - dir_x, defender_cell.y - dir_y)
	if _grid.has(cover_cell):
		return _grid[cover_cell].get("cover_bonus", 0)
	return 0


func _tick_status_effects(combatant_id: String) -> void:
	var cdata: Dictionary = _combatants.get(combatant_id, {})
	var effects: Array = cdata.get("active_effects", [])
	var kept: Array = []
	for effect in effects:
		match effect.get("type", ""):
			"bleeding", "poisoned":
				cdata["hp"] = max(0, cdata.get("hp", 0) - effect.get("value", 1))
				if cdata["hp"] <= 0:
					_on_combatant_died(combatant_id)
					return
			"stunned":
				cdata["skip_turn"] = true
		effect["duration_turns"] -= 1
		if effect["duration_turns"] > 0:
			kept.append(effect)
	cdata["active_effects"] = kept


func _apply_weapon_effects(target_id: String, effects: Array) -> void:
	var cdata: Dictionary = _combatants.get(target_id, {})
	for effect in effects:
		var effect_type: String = effect.get("type", "")
		match effect_type:
			"stun_chance":
				if randf() < effect.get("value", 0.0):
					cdata.get("active_effects", []).append({"type":"stunned","duration_turns":1,"value":0})
					status_effect_applied.emit(target_id, "stunned")
			"bleed_chance":
				if randf() < effect.get("value", 0.0):
					cdata.get("active_effects", []).append({"type":"bleeding","duration_turns":3,"value":2})
					status_effect_applied.emit(target_id, "bleeding")


func _on_combatant_died(combatant_id: String) -> void:
	_combatants[combatant_id]["hp"] = 0
	_combatants[combatant_id]["dead"] = true
	var cell: Vector2i = _combatants[combatant_id].get("cell", Vector2i(-1, -1))
	if _grid.has(cell):
		_grid[cell]["occupant_id"] = ""
	_initiative_order.erase(combatant_id)
	combatant_died.emit(combatant_id)
	_check_combat_over()


func _check_combat_over() -> void:
	var enemies_alive := false
	var player_alive := true
	for cid in _combatants:
		var cdata: Dictionary = _combatants[cid]
		if cdata.get("dead", false):
			continue
		if cdata.get("team", "enemy") == "enemy":
			enemies_alive = true
		if cid == "player" and cdata.get("hp", 0) <= 0:
			player_alive = false
	if not player_alive:
		end_combat(false)
	elif not enemies_alive:
		end_combat(true)


func _build_initiative_order() -> void:
	_initiative_order = _combatants.keys()
	_initiative_order.sort_custom(func(a, b):
		return _combatants[a].get("initiative", 0) > _combatants[b].get("initiative", 0)
	)


func _add_player_combatant() -> void:
	var equipped_weapon := _get_equipped_weapon_id()
	_combatants["player"] = {
		"id":            "player",
		"team":          "player",
		"hp":            GameState.hp,
		"hp_max":        GameState.derived.get("max_hp", 20),
		"ap_max":        GameState.derived.get("max_ap", 6),
		"ap_current":    GameState.derived.get("max_ap", 6),
		"evasion":       GameState.derived.get("evasion_base", 10),
		"armor_defense": _get_player_armor_defense(),
		"weapon_id":     equipped_weapon,
		"initiative":    GameState.stats.get("reflex", 5) + GameState.stats.get("mind", 5) / 2,
		"cell":          Vector2i(1, 5),
		"active_effects": [],
		"skip_turn":     false,
		"dead":          false,
	}
	_grid[Vector2i(1, 5)] = {"passable": true, "cover_bonus": 0, "occupant_id": "player"}


func _add_npc_combatant(npc_id: String) -> void:
	var npc := DataManager.get_npc(npc_id)
	if npc.is_empty():
		push_error("CombatManager: NPC '%s' not found" % npc_id)
		return
	var profile: Dictionary = npc.get("combat_profile", {})
	if profile.is_empty():
		return
	var npc_stats: Dictionary = npc.get("stats", {})
	var spawn_x := GRID_W - 2 - _get_enemy_count()
	var spawn_cell := Vector2i(clamp(spawn_x, 5, GRID_W - 1), 5)
	_combatants[npc_id] = {
		"id":            npc_id,
		"team":          "enemy",
		"hp":            profile.get("max_hp", 20),
		"hp_max":        profile.get("max_hp", 20),
		"ap_max":        profile.get("ap_per_turn", 5),
		"ap_current":    profile.get("ap_per_turn", 5),
		"evasion":       npc_stats.get("reflex", 5) * 2,
		"armor_defense": _get_item_defense(profile.get("armor_id", "")),
		"weapon_id":     profile.get("weapon_id", ""),
		"skill_value":   45,
		"initiative":    npc_stats.get("reflex", 5) + npc_stats.get("mind", 5) / 2,
		"cell":          spawn_cell,
		"active_effects": [],
		"skip_turn":     false,
		"dead":          false,
	}
	_grid[spawn_cell] = {"passable": true, "cover_bonus": 0, "occupant_id": npc_id}


func _get_enemy_count() -> int:
	var count := 0
	for cid in _combatants:
		if _combatants[cid].get("team", "") == "enemy":
			count += 1
	return count


func _get_equipped_weapon_id() -> String:
	for entry in GameState.inventory:
		if entry.get("equipped", false):
			var item := DataManager.get_item(entry.get("item_id", ""))
			if item.get("type", "") == "weapon":
				return item.get("id", "")
	return "bare_hands"


func _get_player_armor_defense() -> int:
	for entry in GameState.inventory:
		if entry.get("equipped", false):
			var item := DataManager.get_item(entry.get("item_id", ""))
			if item.get("type", "") == "armor":
				return item.get("defense_bonus", 0)
	return 0


func _get_item_defense(armor_id: String) -> int:
	if armor_id == "":
		return 0
	return DataManager.get_item(armor_id).get("defense_bonus", 0)


func _roll_dice(dice_str: String) -> int:
	var parts := dice_str.split("d")
	if parts.size() != 2:
		return 1
	var count := int(parts[0])
	var sides := int(parts[1])
	var total := 0
	for i in count:
		total += randi_range(1, sides)
	return total


func _bfs_path(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return []
	var queue: Array = [[from]]
	var visited: Dictionary = {from: true}
	while not queue.is_empty():
		var path: Array = queue.pop_front()
		var current: Vector2i = path[-1]
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.x >= GRID_W or next.y < 0 or next.y >= GRID_H:
				continue
			if visited.has(next):
				continue
			var tile := _grid.get(next, {})
			if not tile.get("passable", true):
				continue
			if tile.get("occupant_id", "") != "" and next != to:
				continue
			var new_path := path.duplicate()
			new_path.append(next)
			if next == to:
				new_path.pop_front()  # remove start cell, return only steps
				return new_path
			visited[next] = true
			queue.append(new_path)
	return []
