extends Node

# ─── Signals ─────────────────────────────────────────────────────────────────
signal combat_started()
signal turn_started(unit_id: String, ap: int)
signal unit_moved(unit_id: String, from_hex: Vector2i, to_hex: Vector2i)
signal unit_attacked(attacker_id: String, target_id: String, hit: bool, damage: int, weapon_name: String)
signal unit_died(unit_id: String)
signal ap_changed(unit_id: String, new_ap: int)
signal combat_ended(player_won: bool)
signal unit_reloaded(unit_id: String, ammo_loaded: int, ammo_reserve: int)
signal unit_used_item(unit_id: String, item_id: String)
signal status_applied(unit_id: String, status_name: String)
signal bleed_tick(unit_id: String, damage: int)
# Generic damage-over-time tick for any status (bleed/poison/radiation).
signal status_tick(unit_id: String, status_name: String, damage: int)

# ─── Arena dimensions ────────────────────────────────────────────────────────
const ARENA_COLS    := 14
const ARENA_ROWS    := 10
const ARENA_MID_ROW := 5

# ─── Shot modes & called shots ─────────────────────────────────────────────────
enum ShotMode { NORMAL, QUICK, AIMED, BURST }
enum BodyPart { TORSO, HEAD, ARMS, LEGS }

# Damage-over-time statuses: per-tick damage and default duration when applied.
const DOT_DAMAGE   := { "bleed": 2, "poison": 3, "radiation": 1 }
const DOT_DURATION := { "bleed": 3, "poison": 4, "radiation": 6 }

# ─── State ────────────────────────────────────────────────────────────────────
enum Phase { INACTIVE, PLAYER_TURN, ENEMY_TURN, ENDED }
var phase: Phase = Phase.INACTIVE

# unit_id → { id, display_name, team, hex, hp, hp_max, ap, ap_max,
#              sequence, stats, skills, equipped_weapon_id, dr, dead,
#              ammo_loaded, ammo_reserve, statuses: {bleed, stun} }
var units: Dictionary     = {}
var hex_grid: Dictionary  = {}    # Vector2i → terrain String
var _occupied: Dictionary = {}    # Vector2i → unit_id
var _initiative           := InitiativeQueue.new()
var current_unit_id: String = ""
var _arena_id: String       = ""
var xp_earned: int          = 0
var pending_loot: Array     = []  # Array of { item_id, quantity }; "__caps__" is special

# When true, combat is running ON the live local map (Fallout "freeze in place"):
# the local_map scene owns the grid + visuals and drives input/rendering through
# CombatManager's signals. No scene change happens. When false (legacy / random
# encounter), CombatManager builds its own arena.
var external_mode: bool     = false


# ─── Public API ──────────────────────────────────────────────────────────────

func start_combat(enemy_unit_ids: Array, arena_id: String = "") -> void:
	external_mode = false
	_arena_id = arena_id
	xp_earned = 0
	pending_loot.clear()
	units.clear()
	hex_grid.clear()
	_occupied.clear()
	_initiative = InitiativeQueue.new()
	phase = Phase.INACTIVE

	_build_arena()
	_build_player_unit()
	_build_companion_units(units["player"]["hex"])
	_build_enemy_units(enemy_unit_ids)
	_roll_initiative()
	combat_started.emit()
	_begin_turn(current_unit_id)


# Fallout-style in-place combat: the local map freezes and turn-based combat runs
# on the SAME hex grid the player was exploring. `grid` is the live terrain dict
# (Vector2i -> terrain String). `player_hex` is where the player is standing.
# `enemy_list` is [{ "actor_id": String, "npc_id": String, "hex": Vector2i }, ...].
# Units are keyed by the unique actor_id so duplicate npc_ids never collide.
func start_combat_in_place(grid: Dictionary, player_hex: Vector2i, enemy_list: Array) -> void:
	external_mode = true
	_arena_id = ""
	xp_earned = 0
	pending_loot.clear()
	units.clear()
	hex_grid = grid.duplicate(true)
	_occupied.clear()
	_initiative = InitiativeQueue.new()
	phase = Phase.INACTIVE

	_build_player_unit(player_hex)
	_build_companion_units(player_hex)
	_build_enemy_units_at(enemy_list)
	_roll_initiative()
	combat_started.emit()
	_begin_turn(current_unit_id)


func try_move(unit_id: String, target_hex: Vector2i) -> bool:
	if not _can_act(unit_id):
		return false
	var reachable := get_valid_moves(unit_id)
	if not reachable.has(target_hex):
		return false
	var unit: Dictionary   = units[unit_id]
	var from_hex: Vector2i = unit["hex"]
	_spend_ap(unit_id, reachable[target_hex])
	_occupied.erase(from_hex)
	unit["hex"]           = target_hex
	_occupied[target_hex] = unit_id
	unit_moved.emit(unit_id, from_hex, target_hex)
	return true


func try_attack(attacker_id: String, target_id: String,
		shot_mode: ShotMode = ShotMode.NORMAL,
		body_part: BodyPart = BodyPart.TORSO) -> bool:
	if not _can_act(attacker_id):
		return false
	if not units.has(target_id) or units[target_id].get("dead", false):
		return false

	var attacker: Dictionary = units[attacker_id]
	var target: Dictionary   = units[target_id]
	var weapon: Dictionary   = DataManager.get_item(attacker.get("equipped_weapon_id", ""))
	var amods: Dictionary    = attacker.get("mods", {})
	var w_range: int         = CombatCalc.weapon_range(weapon)
	var is_ranged: bool      = w_range > 1

	# Fast Shot and similar traits forbid aimed/called shots.
	if shot_mode == ShotMode.AIMED and bool(amods.get("no_aimed", false)):
		return false
	# Burst is only available on weapons that declare a burst size.
	if shot_mode == ShotMode.BURST and int(weapon.get("burst", 0)) <= 0:
		return false

	# Determine AP cost (ranged attacks get any AP reduction from perks/traits).
	var ap_cost: int
	match shot_mode:
		ShotMode.QUICK: ap_cost = CombatCalc.QUICK_SHOT_AP_COST
		ShotMode.AIMED: ap_cost = CombatCalc.AIMED_SHOT_AP_COST
		ShotMode.BURST: ap_cost = int(weapon.get("burst_ap_cost", CombatCalc.weapon_ap_cost(weapon) + CombatCalc.BURST_AP_EXTRA))
		_:              ap_cost = CombatCalc.weapon_ap_cost(weapon)
	if is_ranged:
		ap_cost = max(1, ap_cost - int(amods.get("ranged_ap_reduction", 0)))

	if attacker["ap"] < ap_cost:
		return false

	# Range + LOS checks
	var dist: int = HexGrid.distance(attacker["hex"], target["hex"])
	if dist > w_range:
		return false
	if not LineOfSight.has_los(attacker["hex"], target["hex"], _opaque_hexes()):
		return false

	# Ammo: how many rounds actually fire (a burst sprays several; ammo can cap it).
	var rounds := 1
	if shot_mode == ShotMode.BURST:
		rounds = max(1, int(weapon.get("burst", 3)))
	if CombatCalc.weapon_needs_ammo(weapon):
		var loaded: int = attacker.get("ammo_loaded", 999)
		if loaded <= 0:
			return false
		if loaded != 999:
			rounds = min(rounds, loaded)
			attacker["ammo_loaded"] = loaded - rounds

	# Ammo type can modify armor penetration (AP rounds) and damage (JHP rounds).
	var am: Dictionary       = _ammo_mods(weapon)
	var ammo_dr_mod: int     = am["dr_mod"]
	var ammo_dmg_mult: float = am["dmg_mult"]

	# ── Hit chance (shared by every round of the shot) ──
	var wsub: String     = weapon.get("subtype", CombatCalc.weapon_skill_id(weapon))
	var hit_adjust: int  = _attacker_hit_bonus(amods, wsub) - int(attacker.get("accuracy_debuff", 0))
	match shot_mode:
		ShotMode.QUICK: hit_adjust -= CombatCalc.QUICK_SHOT_PEN
		ShotMode.AIMED: hit_adjust += int(_body_part_mods(body_part).get("hit", 0))
		ShotMode.BURST: hit_adjust -= CombatCalc.BURST_HIT_PEN
		_:              pass
	var cover_pen: int   = _cover_to_penalty(
		LineOfSight.get_cover(attacker["hex"], target["hex"], _cover_map()))
	var skill_id: String = CombatCalc.weapon_skill_id(weapon)
	var skill_val: int   = attacker["skills"].get(skill_id, 20)
	var chance: int      = CombatCalc.hit_chance(
		skill_val, dist, w_range, -hit_adjust, cover_pen)

	# ── Fire rounds ──
	var total_damage := 0
	var any_hit := false
	for _i in rounds:
		if target.get("hp", 0) <= 0:
			break
		if CombatCalc.roll_hit(chance):
			any_hit = true
			total_damage += _deal_one_hit(
				attacker, target, target_id, weapon, amods, wsub,
				shot_mode, body_part, ammo_dr_mod, ammo_dmg_mult)
	if any_hit:
		_apply_weapon_effects(weapon, target_id, target)
		if shot_mode == ShotMode.AIMED:
			_apply_called_shot(body_part, target_id, target)

	_spend_ap(attacker_id, ap_cost)

	# Critical failure: a fully-missed single shot can jam / waste the rest of the turn.
	if not any_hit and shot_mode != ShotMode.BURST and CombatCalc.is_fumble():
		_apply_fumble(attacker_id, attacker, is_ranged)

	var wname: String = weapon.get("name", "weapon") if not weapon.is_empty() else "Bare Hands"
	unit_attacked.emit(attacker_id, target_id, any_hit, total_damage, wname)

	if target["hp"] <= 0:
		_kill_unit(target_id)

	return true


# Resolve a single round of fire against a target: crit + damage roll + ammo/DR + crit DR
# halving. Applies the damage and returns how much was dealt. Weapon status effects and
# called-shot consequences are applied once by the caller after all rounds resolve.
func _deal_one_hit(attacker: Dictionary, target: Dictionary, target_id: String,
		weapon: Dictionary, amods: Dictionary, wsub: String,
		shot_mode: ShotMode, body_part: BodyPart,
		ammo_dr_mod: int, ammo_dmg_mult: float) -> int:
	var crit_chance: int = _base_crit(attacker) + int(amods.get("crit_chance", 0))
	if shot_mode == ShotMode.AIMED:
		crit_chance += int(_body_part_mods(body_part).get("crit", 0))
	var crit: bool = CombatCalc.is_critical(crit_chance)

	var raw: int = CombatCalc.roll_damage(weapon, attacker["stats"].get("body", 5))
	raw += int(amods.get("dmg_all", 0)) + int(amods.get("dmg_" + wsub, 0))
	raw = int(round(raw * ammo_dmg_mult))
	raw = max(1, raw)
	var dr: int = max(0, int(target.get("dr", 0)) + ammo_dr_mod)
	if crit:
		var mult: float = 2.0 + float(amods.get("crit_damage_pct", 0)) / 100.0
		@warning_ignore("integer_division")
		var half_dr: int = dr / 2
		raw = int(round(raw * mult))
		dr = half_dr
	var damage: int = CombatCalc.apply_dr(raw, dr)
	target["hp"] = max(0, int(target["hp"]) - damage)
	if crit:
		status_applied.emit(target_id, "crit")
	return damage


# Damage/armor modifiers contributed by the loaded ammunition type (looked up from the
# weapon's ammo_type item). dr_mod < 0 = armor-piercing; dmg_mult > 1 = hollow-point.
func _ammo_mods(weapon: Dictionary) -> Dictionary:
	var at_raw: Variant = weapon.get("ammo_type", "")
	if not (at_raw is String) or at_raw == "":
		return {"dr_mod": 0, "dmg_mult": 1.0}
	var ammo: Dictionary = DataManager.get_item(at_raw)
	return {"dr_mod": int(ammo.get("dr_mod", 0)), "dmg_mult": float(ammo.get("dmg_mult", 1.0))}


# A critical failure ends the rest of the unit's turn; a ranged fumble also dumps the
# magazine (a jam the unit must reload to clear).
func _apply_fumble(unit_id: String, unit: Dictionary, is_ranged: bool) -> void:
	unit["ap"] = 0
	ap_changed.emit(unit_id, 0)
	if is_ranged and unit.get("ammo_loaded", 999) != 999:
		unit["ammo_loaded"] = 0
	status_applied.emit(unit_id, "fumble")


func try_melee_attack(attacker_id: String, target_id: String) -> bool:
	if not _can_act(attacker_id):
		return false
	if not units.has(target_id) or units[target_id].get("dead", false):
		return false
	var attacker: Dictionary = units[attacker_id]
	var target: Dictionary   = units[target_id]
	if HexGrid.distance(attacker["hex"], target["hex"]) > 1:
		return false
	if not LineOfSight.has_los(attacker["hex"], target["hex"], _opaque_hexes()):
		return false
	if attacker["ap"] < CombatCalc.MELEE_AP_COST:
		return false

	var amods: Dictionary = attacker.get("mods", {})
	var hit_adjust: int   = amods.get("hit_all", 0) + amods.get("hit_melee", 0) \
		- int(attacker.get("accuracy_debuff", 0))
	var skill_val: int = attacker["skills"].get("melee", 20)
	var chance: int    = CombatCalc.hit_chance(skill_val, 1, 1, -hit_adjust, 0)
	var hit: bool      = CombatCalc.roll_hit(chance)
	var damage: int    = 0

	if hit:
		var crit: bool = CombatCalc.is_critical(_base_crit(attacker) + int(amods.get("crit_chance", 0)))
		var raw: int = CombatCalc.roll_damage({}, attacker["stats"].get("body", 5))
		raw += amods.get("dmg_all", 0) + amods.get("dmg_melee", 0)
		raw = max(1, raw)
		var dr: int = target.get("dr", 0)
		if crit:
			var mult: float = 2.0 + float(amods.get("crit_damage_pct", 0)) / 100.0
			@warning_ignore("integer_division")
			var half_dr: int = dr / 2
			raw = int(round(raw * mult))
			dr = half_dr
		damage       = CombatCalc.apply_dr(raw, dr)
		target["hp"] = max(0, target["hp"] - damage)
		if crit:
			status_applied.emit(target_id, "crit")

	_spend_ap(attacker_id, CombatCalc.MELEE_AP_COST)
	if not hit and CombatCalc.is_fumble():
		_apply_fumble(attacker_id, attacker, false)
	unit_attacked.emit(attacker_id, target_id, hit, damage, "Bare Hands")

	if target["hp"] <= 0:
		_kill_unit(target_id)

	return true


func get_melee_targets(attacker_id: String) -> Array:
	if not units.has(attacker_id):
		return []
	var attacker: Dictionary = units[attacker_id]
	if attacker["ap"] < CombatCalc.MELEE_AP_COST:
		return []
	var opaque    := _opaque_hexes()
	var targets: Array = []
	for uid in units:
		var t: Dictionary = units[uid]
		if t.get("dead", false) or t["team"] == attacker["team"]:
			continue
		if HexGrid.distance(attacker["hex"], t["hex"]) > 1:
			continue
		if not LineOfSight.has_los(attacker["hex"], t["hex"], opaque):
			continue
		targets.append(uid)
	return targets


func try_reload(unit_id: String) -> bool:
	if not _can_act(unit_id):
		return false
	var unit: Dictionary   = units[unit_id]
	if unit["ap"] < CombatCalc.RELOAD_AP_COST:
		return false
	var weapon: Dictionary = DataManager.get_item(unit.get("equipped_weapon_id", ""))
	var clip: int          = CombatCalc.weapon_clip_size(weapon)
	if clip <= 0:
		return false  # melee — no reload
	var loaded: int  = unit.get("ammo_loaded", 0)
	var reserve: int = unit.get("ammo_reserve", 0)
	if loaded >= clip and reserve == 999:
		return false  # already full (enemies always full)
	if loaded >= clip and reserve <= 0:
		return false  # full clip, no reserve

	var needed: int = clip - loaded
	var amount: int = needed if reserve == 999 else min(needed, reserve)
	if amount <= 0:
		return false

	_spend_ap(unit_id, CombatCalc.RELOAD_AP_COST)
	unit["ammo_loaded"] = loaded + amount
	if reserve != 999:
		unit["ammo_reserve"] = max(0, reserve - amount)
	unit_reloaded.emit(unit_id, unit["ammo_loaded"], unit.get("ammo_reserve", 0))
	return true


func try_use_item(unit_id: String, item_id: String) -> bool:
	if not _can_act(unit_id):
		return false
	var unit: Dictionary = units[unit_id]
	if unit["ap"] < CombatCalc.USE_ITEM_AP_COST:
		return false
	if not GameState.has_item(item_id):
		return false
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		return false

	_spend_ap(unit_id, CombatCalc.USE_ITEM_AP_COST)
	GameState.remove_item(item_id, 1)

	var heal_pct: int = int(unit.get("mods", {}).get("heal_pct", 0))
	for effect: Dictionary in item.get("effects", []):
		match effect.get("type", ""):
			"heal_hp":
				var amount: int = int(effect["value"])
				amount += int(round(amount * heal_pct / 100.0))
				unit["hp"] = min(unit["hp_max"], unit["hp"] + amount)
			"boost_ap_temp":
				unit["ap"] += int(effect["value"])
			"remove_status":
				var st: String = effect.get("status", "")
				if unit["statuses"].has(st):
					unit["statuses"][st] = 0

	ap_changed.emit(unit_id, unit["ap"])
	unit_used_item.emit(unit_id, item_id)
	return true


func end_player_turn() -> void:
	if phase == Phase.PLAYER_TURN:
		_end_turn()


# Disengage / flee: tear down the turn loop without declaring a winner. Marks the
# fight ENDED so any deferred AI/turn callbacks bail out. Does NOT emit
# combat_ended — the caller handles thawing the map (no loot, no game-over).
func abort_combat() -> void:
	phase = Phase.ENDED
	current_unit_id = ""


func get_valid_moves(unit_id: String) -> Dictionary:
	if not units.has(unit_id):
		return {}
	var unit: Dictionary = units[unit_id]
	return HexGrid.get_reachable(
		unit["hex"], unit["ap"], CombatCalc.AP_MOVE, _blocked_for(unit_id))


func get_valid_targets(attacker_id: String, shot_mode: ShotMode = ShotMode.NORMAL) -> Array:
	if not units.has(attacker_id):
		return []
	var attacker: Dictionary = units[attacker_id]
	var weapon: Dictionary   = DataManager.get_item(attacker.get("equipped_weapon_id", ""))
	var w_range: int         = CombatCalc.weapon_range(weapon)
	var ap_cost: int
	match shot_mode:
		ShotMode.QUICK: ap_cost = CombatCalc.QUICK_SHOT_AP_COST
		ShotMode.AIMED: ap_cost = CombatCalc.AIMED_SHOT_AP_COST
		ShotMode.BURST: ap_cost = int(weapon.get("burst_ap_cost", CombatCalc.weapon_ap_cost(weapon) + CombatCalc.BURST_AP_EXTRA))
		_:              ap_cost = CombatCalc.weapon_ap_cost(weapon)
	var opaque               := _opaque_hexes()
	var targets: Array       = []

	for uid in units:
		var t: Dictionary = units[uid]
		if t.get("dead", false) or t["team"] == attacker["team"]:
			continue
		if HexGrid.distance(attacker["hex"], t["hex"]) > w_range:
			continue
		if attacker["ap"] < ap_cost:
			continue
		if not LineOfSight.has_los(attacker["hex"], t["hex"], opaque):
			continue
		targets.append(uid)
	return targets


func is_player_turn() -> bool:
	return phase == Phase.PLAYER_TURN


func get_ap(unit_id: String) -> int:
	return units.get(unit_id, {}).get("ap", 0)


# ─── Arena + unit construction ────────────────────────────────────────────────

func _build_arena() -> void:
	for q in ARENA_COLS:
		for r in ARENA_ROWS:
			hex_grid[Vector2i(q, r)] = "floor"

	for q in ARENA_COLS:
		hex_grid[Vector2i(q, 0)]              = "obstacle"
		hex_grid[Vector2i(q, ARENA_ROWS - 1)] = "obstacle"
	for r in ARENA_ROWS:
		hex_grid[Vector2i(0, r)]              = "obstacle"
		hex_grid[Vector2i(ARENA_COLS - 1, r)] = "obstacle"

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in 6:
		var h := Vector2i(rng.randi_range(2, ARENA_COLS - 3),
						  rng.randi_range(2, ARENA_ROWS - 3))
		hex_grid[h] = "obstacle"
	for _i in 5:
		var h := Vector2i(rng.randi_range(2, ARENA_COLS - 3),
						  rng.randi_range(2, ARENA_ROWS - 3))
		if hex_grid.get(h) == "floor":
			hex_grid[h] = "cover_partial"


func _build_player_unit(at_hex: Vector2i = Vector2i(-999, -999)) -> void:
	GameState.recalculate_derived()
	var hex := at_hex if at_hex != Vector2i(-999, -999) else _free_hex(2, ARENA_MID_ROW)
	var weapon_id: String  = _player_weapon_id()
	var weapon: Dictionary = DataManager.get_item(weapon_id)
	var clip: int          = CombatCalc.weapon_clip_size(weapon)
	var ammo_type_raw: Variant = weapon.get("ammo_type", "") if not weapon.is_empty() else ""
	var ammo_type: String  = ammo_type_raw if ammo_type_raw is String else ""
	var inv_ammo: int      = GameState.get_item_quantity(ammo_type) if ammo_type != "" else 0
	var ammo_loaded: int   = clip
	var ammo_reserve: int  = max(0, inv_ammo - clip)
	var mods: Dictionary   = GameState.combat_mods()
	var eff_stats: Dictionary = GameState.get_effective_stats()

	units["player"] = {
		"id":                 "player",
		"display_name":       GameState.player_name,
		"team":               "player",
		"hex":                hex,
		"hp":                 GameState.hp,
		"hp_max":             GameState.derived.get("max_hp", 20),
		"ap":                 0,
		"ap_max":             GameState.derived.get("max_ap", 8),
		"sequence":           CombatCalc.roll_initiative(eff_stats),
		"stats":              eff_stats,
		"skills":             GameState.skills.duplicate(),
		"equipped_weapon_id": weapon_id,
		"dr":                 _player_dr() + int(mods.get("dr", 0)),
		"dead":               false,
		"ammo_loaded":        ammo_loaded,
		"ammo_reserve":       ammo_reserve,
		"statuses":           _new_statuses(),
		"mods":               mods,
		"accuracy_debuff":    0,
	}
	_occupied[hex] = "player"


func _build_enemy_units(enemy_ids: Array) -> void:
	var start_q := ARENA_COLS - 3
	var start_r := ARENA_MID_ROW - (enemy_ids.size() - 1)

	for npc_id: String in enemy_ids:
		var npc: Dictionary     = DataManager.get_npc(npc_id)
		var profile: Dictionary = npc.get("combat_profile", {})
		var npc_stats: Dictionary = npc.get("stats",
			{"grit":4,"reflex":4,"mind":2,"body":5,"nerve":4,"presence":2})
		var weapon_id: String = profile.get("weapon_id", "bare_hands")
		var armor: Dictionary = DataManager.get_item(profile.get("armor_id", ""))
		var hp_max: int       = profile.get("max_hp", 20)

		var hex := _free_hex(start_q, start_r)
		units[npc_id] = {
			"id":                 npc_id,
			"npc_id":             npc_id,
			"display_name":       npc.get("name", npc_id),
			"team":               "enemy",
			"hex":                hex,
			"hp":                 hp_max,
			"hp_max":             hp_max,
			"ap":                 0,
			"ap_max":             profile.get("ap_per_turn", 5),
			"sequence":           CombatCalc.roll_initiative(npc_stats),
			"stats":              npc_stats,
			"skills":             _calc_skills(npc_stats, npc.get("skills_override", {})),
			"equipped_weapon_id": weapon_id,
			"dr":                 armor.get("defense_bonus", 0),
			"dead":               false,
			"ammo_loaded":        999,   # enemies have infinite ammo
			"ammo_reserve":       999,
			"statuses":           _new_statuses(),
			"mods":               {},
			"accuracy_debuff":    0,
		}
		_occupied[hex] = npc_id
		start_r += 2


# Build a unit for each companion in GameState.party, on the player's team, placed near
# the player. Keyed "comp_<npc_id>" so a companion never collides with an enemy unit that
# happens to share the npc_id. AI-controlled (see _run_ai). A recruitable NPC must have a
# combat_profile; one without is skipped.
func _build_companion_units(near_hex: Vector2i) -> void:
	for npc_id: String in GameState.get_party():
		var npc: Dictionary = DataManager.get_npc(npc_id)
		var profile: Dictionary = npc.get("combat_profile", {})
		if npc.is_empty() or profile.is_empty():
			continue
		var npc_stats: Dictionary = npc.get("stats",
			{"grit":5,"reflex":5,"mind":4,"body":5,"nerve":5,"presence":4})
		var weapon_id: String = profile.get("weapon_id", "bare_hands")
		var armor: Dictionary = DataManager.get_item(profile.get("armor_id", ""))
		var hp_max: int       = profile.get("max_hp", 25)
		var uid: String       = "comp_" + npc_id
		var hex: Vector2i     = _nearest_free_hex(near_hex)
		units[uid] = {
			"id":                 uid,
			"npc_id":             npc_id,
			"display_name":       npc.get("name", npc_id),
			"team":               "player",
			"hex":                hex,
			"hp":                 hp_max,
			"hp_max":             hp_max,
			"ap":                 0,
			"ap_max":             profile.get("ap_per_turn", 6),
			"sequence":           CombatCalc.roll_initiative(npc_stats),
			"stats":              npc_stats,
			"skills":             _calc_skills(npc_stats, npc.get("skills_override", {})),
			"equipped_weapon_id": weapon_id,
			"dr":                 armor.get("defense_bonus", 0),
			"dead":               false,
			"ammo_loaded":        999,   # companions don't track ammo
			"ammo_reserve":       999,
			"statuses":           _new_statuses(),
			"mods":               {},
			"accuracy_debuff":    0,
		}
		_occupied[hex] = uid


# Build enemy units at explicit hexes for in-place combat. Each entry:
# { "actor_id": String (unique unit key), "npc_id": String, "hex": Vector2i }.
func _build_enemy_units_at(enemy_list: Array) -> void:
	for entry: Dictionary in enemy_list:
		var actor_id: String = entry.get("actor_id", "")
		var npc_id: String   = entry.get("npc_id", "")
		if actor_id == "" or npc_id == "":
			continue
		var npc: Dictionary     = DataManager.get_npc(npc_id)
		var profile: Dictionary = npc.get("combat_profile", {})
		var npc_stats: Dictionary = npc.get("stats",
			{"grit":4,"reflex":4,"mind":2,"body":5,"nerve":4,"presence":2})
		var weapon_id: String = profile.get("weapon_id", "bare_hands")
		var armor: Dictionary = DataManager.get_item(profile.get("armor_id", ""))
		var hp_max: int       = profile.get("max_hp", 20)

		var hex: Vector2i = entry.get("hex", Vector2i.ZERO)
		if _occupied.has(hex) or TerrainDB.is_blocked(hex_grid.get(hex, "obstacle")):
			hex = _nearest_free_hex(hex)

		units[actor_id] = {
			"id":                 actor_id,
			"npc_id":             npc_id,
			"display_name":       npc.get("name", npc_id),
			"team":               "enemy",
			"hex":                hex,
			"hp":                 hp_max,
			"hp_max":             hp_max,
			"ap":                 0,
			"ap_max":             profile.get("ap_per_turn", 5),
			"sequence":           CombatCalc.roll_initiative(npc_stats),
			"stats":              npc_stats,
			"skills":             _calc_skills(npc_stats, npc.get("skills_override", {})),
			"equipped_weapon_id": weapon_id,
			"dr":                 armor.get("defense_bonus", 0),
			"dead":               false,
			"ammo_loaded":        999,
			"ammo_reserve":       999,
			"statuses":           _new_statuses(),
			"mods":               {},
			"accuracy_debuff":    0,
		}
		_occupied[hex] = actor_id


# Spiral outward from a hex to find the closest walkable, unoccupied hex.
func _nearest_free_hex(origin: Vector2i) -> Vector2i:
	if not TerrainDB.is_blocked(hex_grid.get(origin, "obstacle")) and not _occupied.has(origin):
		return origin
	var frontier: Array = [origin]
	var seen: Dictionary = {origin: true}
	while not frontier.is_empty():
		var nxt: Array = []
		for h: Vector2i in frontier:
			for nb: Vector2i in HexGrid.neighbors(h):
				if seen.has(nb):
					continue
				seen[nb] = true
				if not TerrainDB.is_blocked(hex_grid.get(nb, "obstacle")) and not _occupied.has(nb):
					return nb
				nxt.append(nb)
		frontier = nxt
	return origin


func _free_hex(preferred_q: int, preferred_r: int) -> Vector2i:
	var r := clampi(preferred_r, 1, ARENA_ROWS - 2)
	for _attempt in 20:
		var hex := Vector2i(preferred_q, r)
		if not TerrainDB.is_blocked(hex_grid.get(hex, "obstacle")) and not _occupied.has(hex):
			return hex
		r += 1
		if r >= ARENA_ROWS - 1:
			r = 1
	return Vector2i(preferred_q, clampi(preferred_r, 1, ARENA_ROWS - 2))


func _calc_skills(stats: Dictionary, overrides: Dictionary) -> Dictionary:
	var skills: Dictionary = {}
	for skill_id in GameState.SKILL_BASE:
		var bases: Dictionary = GameState.SKILL_BASE[skill_id]
		skills[skill_id] = (
			stats.get(bases["primary"],   5) * 8 +
			stats.get(bases["secondary"], 5) * 4 + 5
		)
	for k in overrides:
		skills[k] = overrides[k]
	return skills


func _new_statuses() -> Dictionary:
	return {"bleed": 0, "stun": 0, "poison": 0, "radiation": 0}


# Base critical-hit chance for a unit, before perk/trait/called-shot bonuses.
func _base_crit(unit: Dictionary) -> int:
	@warning_ignore("integer_division")
	var from_nerve: int = unit.get("stats", {}).get("nerve", 5) / 2
	return 5 + from_nerve


# Aggregate hit bonus from perk/trait mods for a weapon of the given subtype.
func _attacker_hit_bonus(amods: Dictionary, wsub: String) -> int:
	return int(amods.get("hit_all", 0)) + int(amods.get("hit_" + wsub, 0))


# Called-shot modifiers, applied only in AIMED mode. `hit` adjusts to-hit (a
# negative number is a penalty), `crit` adds to crit chance, and the optional
# effect fires on a successful hit (see _apply_called_shot).
func _body_part_mods(part: BodyPart) -> Dictionary:
	match part:
		BodyPart.HEAD: return {"hit": -15, "crit": 25}
		BodyPart.ARMS: return {"hit": -10, "crit": 0}
		BodyPart.LEGS: return {"hit": -10, "crit": 0}
		_:             return {"hit": 10,  "crit": 0}  # TORSO — careful aim


func _apply_weapon_effects(weapon: Dictionary, target_id: String, target: Dictionary) -> void:
	for effect: Dictionary in weapon.get("effects", []):
		var etype: String = effect.get("type", "")
		var chance: float = float(effect.get("value", 0.0))
		match etype:
			"bleed_chance":     _maybe_apply_dot("bleed", chance, target_id, target)
			"poison_chance":    _maybe_apply_dot("poison", chance, target_id, target)
			"radiation_chance": _maybe_apply_dot("radiation", chance, target_id, target)
			"stun_chance":
				if CombatCalc.roll_effect(chance):
					target["statuses"]["stun"] = max(target["statuses"].get("stun", 0), 1)
					status_applied.emit(target_id, "stun")


func _maybe_apply_dot(status: String, chance: float, target_id: String, target: Dictionary) -> void:
	if CombatCalc.roll_effect(chance):
		var dur: int = DOT_DURATION.get(status, 3)
		target["statuses"][status] = max(target["statuses"].get(status, 0), dur)
		status_applied.emit(target_id, status)


# On a successful aimed shot, body parts can cripple the target.
func _apply_called_shot(part: BodyPart, target_id: String, target: Dictionary) -> void:
	match part:
		BodyPart.HEAD:
			if CombatCalc.roll_effect(0.4):
				target["statuses"]["stun"] = max(target["statuses"].get("stun", 0), 1)
				status_applied.emit(target_id, "stun")
		BodyPart.LEGS:
			if CombatCalc.roll_effect(0.5) and not target.get("legs_crippled", false):
				target["legs_crippled"] = true
				target["ap_max"] = max(2, int(target.get("ap_max", 5)) - 2)
				status_applied.emit(target_id, "cripple_legs")
		BodyPart.ARMS:
			if CombatCalc.roll_effect(0.5) and not target.get("arms_crippled", false):
				target["arms_crippled"] = true
				target["accuracy_debuff"] = int(target.get("accuracy_debuff", 0)) + 20
				status_applied.emit(target_id, "cripple_arms")


# ─── Turn flow ────────────────────────────────────────────────────────────────

func _roll_initiative() -> void:
	var init_map: Dictionary = {}
	for uid in units:
		init_map[uid] = {"initiative": units[uid]["sequence"]}
	_initiative.build(init_map)
	current_unit_id = _initiative.current()


func _begin_turn(unit_id: String) -> void:
	current_unit_id      = unit_id
	var unit: Dictionary = units[unit_id]

	# Apply damage-over-time statuses (bleed/poison/radiation) at turn start.
	var statuses: Dictionary = unit.get("statuses", _new_statuses())
	for dot: String in DOT_DAMAGE:
		if statuses.get(dot, 0) > 0:
			var dmg: int = DOT_DAMAGE[dot]
			unit["hp"] = max(0, unit["hp"] - dmg)
			statuses[dot] -= 1
			status_tick.emit(unit_id, dot, dmg)
			if dot == "bleed":
				bleed_tick.emit(unit_id, dmg)  # back-compat
			if unit["hp"] <= 0:
				_kill_unit(unit_id)
				if phase != Phase.ENDED:
					call_deferred("_end_turn")
				return

	# Stun skips the turn
	if statuses.get("stun", 0) > 0:
		statuses["stun"] -= 1
		unit["ap"] = 0
		turn_started.emit(unit_id, 0)
		status_applied.emit(unit_id, "stun_skip")
		call_deferred("_end_turn")
		return

	unit["ap"] = unit["ap_max"]
	# Only the human "player" unit waits for input; everyone else (enemies AND allied
	# companions) is AI-driven.
	if unit_id == "player":
		phase = Phase.PLAYER_TURN
		turn_started.emit(unit_id, unit["ap"])
	else:
		phase = Phase.ENEMY_TURN
		turn_started.emit(unit_id, unit["ap"])
		_run_ai(unit_id)


func _end_turn() -> void:
	_initiative.advance()
	var next_id: String = _initiative.current()
	while units.has(next_id) and units[next_id].get("dead", false):
		_initiative.remove(next_id)
		if _initiative.is_empty():
			return
		next_id = _initiative.current()
	if next_id != "":
		_begin_turn(next_id)


# ─── Enemy AI ─────────────────────────────────────────────────────────────────

func _run_ai(unit_id: String) -> void:
	var unit: Dictionary = units[unit_id]
	# Companions (player team) hunt enemies; enemies hunt the player + companions.
	var target_id: String = _nearest_enemy_of(unit_id)
	if target_id == "":
		call_deferred("_ai_done")
		return
	var target: Dictionary = units[target_id]

	var weapon: Dictionary = DataManager.get_item(unit.get("equipped_weapon_id", ""))
	var w_range: int       = CombatCalc.weapon_range(weapon)
	var ap_atk: int        = CombatCalc.weapon_ap_cost(weapon)
	var is_ranged: bool    = w_range > 1
	var dist: int          = HexGrid.distance(unit["hex"], target["hex"])
	var hp_ratio: float    = float(unit["hp"]) / max(1.0, float(unit.get("hp_max", 1)))
	var low_hp: bool       = hp_ratio < 0.3

	if low_hp and unit["ap"] >= CombatCalc.AP_MOVE:
		# Badly hurt: fall back toward cover and distance.
		var retreat := _best_tactical_hex(unit_id, target["hex"])
		if retreat != unit["hex"]:
			try_move(unit_id, retreat)
	elif is_ranged:
		# Back away (seeking cover) if the target is too close.
		if dist < 3 and unit["ap"] >= CombatCalc.AP_MOVE:
			var reposition := _best_tactical_hex(unit_id, target["hex"])
			if reposition != unit["hex"]:
				try_move(unit_id, reposition)
		# Close to attack range if too far.
		elif dist > w_range and unit["ap"] >= CombatCalc.AP_MOVE:
			_ai_close_on(unit_id, target["hex"])
	else:
		# Melee: close in, stopping adjacent to the target.
		if dist > w_range and unit["ap"] >= CombatCalc.AP_MOVE:
			_ai_close_on(unit_id, target["hex"])

	# Attack if in range with LOS.
	dist = HexGrid.distance(unit["hex"], target["hex"])
	if dist <= w_range and unit["ap"] >= ap_atk and phase != Phase.ENDED:
		if LineOfSight.has_los(unit["hex"], target["hex"], _opaque_hexes()):
			try_attack(unit_id, target_id)

	call_deferred("_ai_done")


# Nearest living unit on the opposing team to the given unit ("" if none remain).
func _nearest_enemy_of(unit_id: String) -> String:
	var unit: Dictionary = units[unit_id]
	var my_team: String  = unit["team"]
	var best: String     = ""
	var best_dist: int   = 1 << 30
	for uid in units:
		var u: Dictionary = units[uid]
		if u.get("dead", false) or u["team"] == my_team:
			continue
		var d: int = HexGrid.distance(unit["hex"], u["hex"])
		if d < best_dist:
			best_dist = d
			best = uid
	return best


# Move toward a target hex along the best path the unit can afford this turn.
func _ai_close_on(unit_id: String, target_hex: Vector2i) -> void:
	var unit: Dictionary = units[unit_id]
	var blocked_no_target := _blocked_for(unit_id)
	blocked_no_target.erase(target_hex)
	var path := HexGrid.find_path(unit["hex"], target_hex, blocked_no_target)
	if path.size() > 1:
		@warning_ignore("integer_division")
		var ap_steps: int  = unit["ap"] / CombatCalc.AP_MOVE
		var max_steps: int = path.size() - 1
		var steps: int     = min(ap_steps, max_steps)
		if steps > 0:
			try_move(unit_id, path[steps - 1])


# Pick the reachable hex that best balances distance from the player with taking
# cover. Falls back to staying put if nothing is better.
func _best_tactical_hex(unit_id: String, player_hex: Vector2i) -> Vector2i:
	var unit: Dictionary = units[unit_id]
	var cur: Vector2i    = unit["hex"]
	var reachable: Dictionary = get_valid_moves(unit_id)
	var cover_map: Dictionary = _cover_map()
	var best: Vector2i   = cur
	var best_score: int  = HexGrid.distance(cur, player_hex)
	for h: Vector2i in reachable:
		var score: int = HexGrid.distance(h, player_hex)
		if LineOfSight.get_cover(player_hex, h, cover_map) > 0:
			score += 2
		if score > best_score:
			best_score = score
			best = h
	return best


func _ai_done() -> void:
	if phase != Phase.ENDED:
		_end_turn()


# ─── Death and end conditions ─────────────────────────────────────────────────

func _kill_unit(unit_id: String) -> void:
	var unit: Dictionary = units[unit_id]
	unit["dead"] = true
	_occupied.erase(unit["hex"])
	_initiative.remove(unit_id)
	unit_died.emit(unit_id)

	if unit["team"] == "enemy":
		var npc_id: String = unit.get("npc_id", unit_id)
		xp_earned += CombatCalc.kill_xp(DataManager.get_npc(npc_id))
		_roll_loot(npc_id)
	elif unit_id != "player":
		# A fallen companion leaves the party permanently.
		GameState.dismiss_companion(unit.get("npc_id", ""))

	_check_end()


func _roll_loot(npc_id: String) -> void:
	var npc: Dictionary = DataManager.get_npc(npc_id)

	for entry: Dictionary in npc.get("loot_table", []):
		if randf() > entry.get("chance", 0.0):
			continue
		var qty: int = randi_range(entry.get("min", 1), entry.get("max", 1))
		var iid: String = entry.get("item_id", "")
		var merged := false
		for existing: Dictionary in pending_loot:
			if existing["item_id"] == iid:
				existing["quantity"] += qty
				merged = true
				break
		if not merged:
			pending_loot.append({"item_id": iid, "quantity": qty})

	var caps_entry: Dictionary = npc.get("caps_loot", {})
	if not caps_entry.is_empty() and randf() <= caps_entry.get("chance", 0.0):
		var caps_qty: int = randi_range(caps_entry.get("min", 1), caps_entry.get("max", 1))
		var merged := false
		for existing: Dictionary in pending_loot:
			if existing["item_id"] == "__caps__":
				existing["quantity"] += caps_qty
				merged = true
				break
		if not merged:
			pending_loot.append({"item_id": "__caps__", "quantity": caps_qty})


func _check_end() -> void:
	var player_alive: bool  = not units.get("player", {}).get("dead", false)
	var enemies_alive: bool = false
	for uid in units:
		if units[uid]["team"] == "enemy" and not units[uid].get("dead", false):
			enemies_alive = true
			break

	if not player_alive:
		phase = Phase.ENDED
		combat_ended.emit(false)
	elif not enemies_alive:
		phase = Phase.ENDED
		combat_ended.emit(true)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _spend_ap(unit_id: String, amount: int) -> void:
	units[unit_id]["ap"] -= amount
	ap_changed.emit(unit_id, units[unit_id]["ap"])


func _can_act(unit_id: String) -> bool:
	return current_unit_id == unit_id \
		and not units.get(unit_id, {}).get("dead", false)


func _blocked_for(exclude_id: String) -> Array:
	# Use a set to dedupe; pathfinding rejects any hex listed here.
	var blocked: Dictionary = {}
	for hex in hex_grid:
		if TerrainDB.is_blocked(hex_grid[hex]):
			blocked[hex] = true
		else:
			# Wall off the edge of the map: any neighbour of a walkable tile that
			# isn't itself part of the terrain grid is impassable. Without this,
			# get_reachable/find_path only ever check the `blocked` list and treat
			# the infinite off-map void as free space — letting a kiting/fleeing
			# enemy walk right off the map, where it stays alive and the encounter
			# can never end (soft-lock).
			for nb: Vector2i in HexGrid.neighbors(hex):
				if not hex_grid.has(nb):
					blocked[nb] = true
	for hex in _occupied:
		if _occupied[hex] != exclude_id:
			blocked[hex] = true
	return blocked.keys()


func _opaque_hexes() -> Array:
	var result: Array = []
	for hex in hex_grid:
		if TerrainDB.is_opaque(hex_grid[hex]):
			result.append(hex)
	return result


func _cover_map() -> Dictionary:
	var result: Dictionary = {}
	for hex in hex_grid:
		var c: int = TerrainDB.cover_level(hex_grid[hex])
		if c > 0:
			result[hex] = c
	return result


func _cover_to_penalty(cover: int) -> int:
	match cover:
		LineOfSight.COVER_PARTIAL: return 15
		LineOfSight.COVER_FULL:    return 30
		_: return 0


func _player_weapon_id() -> String:
	for entry in GameState.inventory:
		if entry.get("equipped", false):
			var item := DataManager.get_item(entry["item_id"])
			if item.get("type") == "weapon":
				return entry["item_id"]
	# Nothing equipped: fall back to the campaign's default weapon (manifest-defined).
	return DataManager.get_manifest().get("default_unarmed_weapon", "pistol_9mm")


func _player_dr() -> int:
	for entry in GameState.inventory:
		if entry.get("equipped", false):
			var item := DataManager.get_item(entry["item_id"])
			if item.get("type") == "armor":
				return item.get("defense_bonus", 0)
	return 0
