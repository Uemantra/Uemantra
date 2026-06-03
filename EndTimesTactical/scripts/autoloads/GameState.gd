extends Node

signal state_changed
# Emitted when the player gains one or more levels. `rewards` summarises what was
# granted across all levels gained in this batch (see add_xp / _grant_level_rewards).
signal leveled_up(new_level: int, rewards: Dictionary)
# Emitted when story content asks to roll the end-game credits/epilogue. The active
# gameplay scene listens and switches to the ending screen. `ending_id` is informational.
signal ending_requested(ending_id: String)

# Default karma title bands (threshold -> title). A campaign can override these in its
# manifest under "karma": { "titles": { "-100": "Villain", ... } }. The displayed title is
# the one for the highest threshold the player's karma meets.
const DEFAULT_KARMA_TITLES := {
	-100: "Villain", -50: "Outlaw", -15: "Troublemaker",
	0: "Neutral", 15: "Good-Natured", 50: "Guardian", 100: "Champion",
}

# --- Progression tuning ---
const XP_LEVEL_FACTOR    := 50   # cumulative XP to reach level L = 50 * L * (L-1)
const SKILL_POINTS_BASE  := 5    # per level, before the Mind bonus
const PERK_EVERY_LEVELS  := 3    # a perk pick on levels 3, 6, 9, ...
const STAT_EVERY_LEVELS  := 4    # a stat point on levels 4, 8, 12, ...

# --- Player ---
var player_name: String = "Drifter"
var stats: Dictionary = {
	"grit":     5,
	"reflex":   5,
	"mind":     5,
	"body":     5,
	"nerve":    5,
	"presence": 5,
}
# Per-skill points invested (each point = +2 to skill base)
var skill_investments: Dictionary = {
	"guns": 0, "melee": 0, "speech": 0, "intimidate": 0,
	"barter": 0, "medicine": 0, "lockpick": 0, "tech": 0, "stealth": 0,
}
var skills: Dictionary = {}      # calculated by recalculate_derived()
var derived: Dictionary = {}     # max_hp, max_ap, carry_weight_max
var hp: int = 0
var xp: int = 0
var level: int = 1
var karma: int = 0               # global good/evil standing; drives titles + ending slides
var skill_points: int = 0        # available to spend on skills
var stat_points_available: int = 0   # available to raise a stat (granted every 4th level)
var perk_picks_available: int = 0    # unspent perk choices (granted every 3rd level)

# --- Perks & traits ---
var perks: Array = []            # chosen perk ids (from data/perks/)
var traits: Array = []           # chosen trait ids, picked at character creation (data/traits/)

# --- Inventory ---
var inventory: Array = []        # Array of { item_id, quantity, equipped }
var caps: int = 50               # starting caps

# --- World ---
var current_location: String = "haven_ridge"
var visited_locations: Array = []
var world_time_hours: int = 8    # starts at 8am day 1
var discovered_location_ids: Array = []
var return_scene: String = ""
var pending_combat: Dictionary = {}
var pending_combat_enemies: Array = []
var pending_encounter: Dictionary = {}   # transient: a random-encounter local map to load next
var pending_ending: String = ""          # transient: ending_id to play on the ending screen
var worldmap_pos: Vector2 = Vector2.ZERO # last wasteland-map marker position (0,0 = use current town)
var exploration_states: Dictionary = {}

# --- Character creation ---
var tagged_skills: Array = []

# --- Factions ---
var faction_rep: Dictionary = {}   # faction_id -> int

# --- NPCs ---
var npc_relationships: Dictionary = {}    # npc_id -> int
var npc_arcs_completed: Dictionary = {}   # npc_id -> Array[String]

# --- Party ---
var party: Array = []                     # companion npc_ids currently travelling with you

# --- Quests ---
var quest_states: Dictionary = {}  # quest_id -> { active_stage_index, state }

# --- Flags ---
var flags: Dictionary = {}

const SKILL_BASE: Dictionary = {
	"guns":       {"primary": "reflex",   "secondary": "nerve"},
	"melee":      {"primary": "body",     "secondary": "grit"},
	"speech":     {"primary": "presence", "secondary": "mind"},
	"intimidate": {"primary": "nerve",    "secondary": "presence"},
	"barter":     {"primary": "presence", "secondary": "mind"},
	"medicine":   {"primary": "mind",     "secondary": "grit"},
	"lockpick":   {"primary": "mind",     "secondary": "reflex"},
	"tech":       {"primary": "mind",     "secondary": "nerve"},
	"stealth":    {"primary": "reflex",   "secondary": "nerve"},
}


# Starting state comes from the active campaign's manifest (campaign.json -> player_start).
# The literals here are only fallbacks for a manifest that omits a field, so the engine
# still boots even with a minimal/malformed campaign.
func new_game() -> void:
	var start: Dictionary = DataManager.get_manifest().get("player_start", {})
	player_name = start.get("name", "Drifter")
	var base_stats := {"grit":5,"reflex":5,"mind":5,"body":5,"nerve":5,"presence":5}
	stats = (start.get("stats", base_stats) as Dictionary).duplicate()
	skill_investments = {"guns":0,"melee":0,"speech":0,"intimidate":0,"barter":0,"medicine":0,"lockpick":0,"tech":0,"stealth":0}
	tagged_skills = []
	hp = 0
	xp = 0
	level = 1
	karma = int(start.get("karma", 0))
	skill_points = 0
	stat_points_available = 0
	perk_picks_available = 0
	perks = []
	traits = []
	inventory = _build_start_inventory(start.get("inventory", []))
	caps = int(start.get("caps", 50))
	current_location = start.get("location", "haven_ridge")
	visited_locations = []
	world_time_hours = int(start.get("time_hours", 8))
	discovered_location_ids = []
	return_scene = ""
	pending_combat = {}
	pending_combat_enemies = []
	pending_encounter = {}
	pending_ending = ""
	exploration_states = {}
	faction_rep = {}
	npc_relationships = {}
	npc_arcs_completed = {}
	party = []
	quest_states = {}
	flags = {}
	_discover_default_locations()
	recalculate_derived()
	hp = derived.get("max_hp", 20)
	state_changed.emit()


# Normalize manifest player_start.inventory entries into the internal inventory shape,
# filling in defaults for any omitted fields.
func _build_start_inventory(entries: Array) -> Array:
	var out: Array = []
	for e: Dictionary in entries:
		out.append({
			"item_id":  e.get("item_id", ""),
			"quantity": int(e.get("quantity", 1)),
			"equipped": bool(e.get("equipped", false)),
		})
	return out


func recalculate_derived() -> void:
	var es: Dictionary = get_effective_stats()
	@warning_ignore("integer_division")
	var level_hp: int = (level - 1) * (3 + es["grit"] / 2)
	derived["max_hp"]          = 20 + es["body"] * 4 + es["grit"] * 2 + level_hp + _effect_sum("max_hp_bonus")
	derived["max_ap"]          = 4 + es["reflex"] + _effect_sum("max_ap_bonus")
	derived["carry_weight_max"] = 30 + es["body"] * 5 + _effect_sum("carry_bonus")
	derived["evasion_base"]    = es["reflex"] * 2
	@warning_ignore("integer_division")
	var mdb: int = es["body"] / 3
	derived["melee_dmg_bonus"] = mdb

	var skill_all: int = _effect_sum("skill_bonus_all")
	for skill_id in SKILL_BASE:
		var bases: Dictionary = SKILL_BASE[skill_id]
		var base_val: int = (
			es[bases["primary"]] * 8 +
			es[bases["secondary"]] * 4 + 5
		)
		var invested: int = skill_investments.get(skill_id, 0)
		var tag_bonus: int = 20 if skill_id in tagged_skills else 0
		skills[skill_id] = base_val + invested * 2 + tag_bonus + skill_all + _skill_bonus(skill_id)


# ─── Experience & leveling ─────────────────────────────────────────────────────

# Cumulative XP required to *be* at the given level. Level 1 = 0.
static func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	return XP_LEVEL_FACTOR * lvl * (lvl - 1)


func xp_into_level() -> int:
	return xp - xp_for_level(level)


func xp_to_next_level() -> int:
	return xp_for_level(level + 1) - xp


# Award XP and apply any level-ups it triggers. Returns the number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var old_max_hp: int = derived.get("max_hp", hp)
	xp += amount
	var rewards: Dictionary = {"levels": [], "skill_points": 0, "perk_picks": 0, "stat_points": 0}

	while xp >= xp_for_level(level + 1):
		level += 1
		rewards["levels"].append(level)
		var sp: int = SKILL_POINTS_BASE + get_effective_stats().get("mind", 5)
		skill_points += sp
		rewards["skill_points"] += sp
		if level % PERK_EVERY_LEVELS == 0:
			perk_picks_available += 1
			rewards["perk_picks"] += 1
		if level % STAT_EVERY_LEVELS == 0:
			stat_points_available += 1
			rewards["stat_points"] += 1

	var levels_gained: int = rewards["levels"].size()
	if levels_gained > 0:
		recalculate_derived()
		# Leveling tops the player up by the HP they just gained.
		var new_max: int = derived.get("max_hp", hp)
		hp = min(hp + max(0, new_max - old_max_hp), new_max)
		state_changed.emit()
		leveled_up.emit(level, rewards)
	else:
		state_changed.emit()
	return levels_gained


# Spend one banked stat point to permanently raise a stat (no take-backs).
func spend_stat_point(stat_id: String) -> bool:
	if stat_points_available <= 0 or not stats.has(stat_id):
		return false
	stat_points_available -= 1
	stats[stat_id] += 1
	recalculate_derived()
	state_changed.emit()
	return true


# ─── Perks & traits ────────────────────────────────────────────────────────────

func choose_perk(perk_id: String) -> bool:
	if perk_picks_available <= 0 or perk_id in perks:
		return false
	if not can_take_perk(perk_id):
		return false
	perks.append(perk_id)
	perk_picks_available -= 1
	recalculate_derived()
	state_changed.emit()
	return true


func can_take_perk(perk_id: String) -> bool:
	var perk: Dictionary = DataManager.get_perk(perk_id)
	if perk.is_empty():
		return false
	var req: Dictionary = perk.get("requirements", {})
	if level < int(req.get("level", 1)):
		return false
	var es: Dictionary = get_effective_stats()
	for st: String in req.get("stats", {}):
		if es.get(st, 0) < int(req["stats"][st]):
			return false
	for sk: String in req.get("skills", {}):
		if skills.get(sk, 0) < int(req["skills"][sk]):
			return false
	return true


# All effect dictionaries contributed by currently-active perks and traits.
func _all_effects() -> Array:
	var out: Array = []
	for pid: String in perks:
		for e: Dictionary in DataManager.get_perk(pid).get("effects", []):
			out.append(e)
	for tid: String in traits:
		for e: Dictionary in DataManager.get_trait(tid).get("effects", []):
			out.append(e)
	return out


func _effect_sum(type_name: String) -> int:
	var total: int = 0
	for e: Dictionary in _all_effects():
		if e.get("type", "") == type_name:
			total += int(e.get("value", 0))
	return total


func _skill_bonus(skill_id: String) -> int:
	var total: int = 0
	for e: Dictionary in _all_effects():
		if e.get("type", "") == "skill_bonus" and e.get("skill", "") == skill_id:
			total += int(e.get("value", 0))
	return total


# Base stats plus any flat stat bonuses from perks/traits. Used everywhere a stat
# value drives a calculation (derived stats, skills, combat unit construction).
func get_effective_stats() -> Dictionary:
	var s: Dictionary = stats.duplicate()
	for e: Dictionary in _all_effects():
		if e.get("type", "") == "stat_bonus":
			var st: String = e.get("stat", "")
			if s.has(st):
				s[st] += int(e.get("value", 0))
	return s


# Aggregated combat modifiers from perks/traits, consumed by CombatManager.
func combat_mods() -> Dictionary:
	var m: Dictionary = {
		"hit_all": 0, "hit_guns": 0, "hit_melee": 0,
		"crit_chance": 0, "crit_damage_pct": 0,
		"dmg_all": 0, "dmg_guns": 0, "dmg_melee": 0,
		"dr": 0, "ranged_ap_reduction": 0, "no_aimed": false, "heal_pct": 0,
	}
	for e: Dictionary in _all_effects():
		var v: int = int(e.get("value", 0))
		match e.get("type", ""):
			"hit_bonus":
				var k: String = "hit_" + str(e.get("subtype", "all"))
				m[k] = m.get(k, 0) + v
			"crit_chance_bonus":  m["crit_chance"] += v
			"crit_damage_bonus":  m["crit_damage_pct"] += v
			"damage_flat_bonus":
				var dk: String = "dmg_" + str(e.get("subtype", "all"))
				m[dk] = m.get(dk, 0) + v
			"dr_bonus":           m["dr"] += v
			"ranged_ap_reduction": m["ranged_ap_reduction"] += v
			"no_aimed":           m["no_aimed"] = true
			"bonus_heal_pct":     m["heal_pct"] += v
	return m


func _discover_default_locations() -> void:
	var world := DataManager.get_world()
	for node_data: Dictionary in world.get("nodes", []):
		if node_data.get("unlocked_by_default", false):
			var id: String = node_data.get("id", "")
			if id != "" and id not in discovered_location_ids:
				discovered_location_ids.append(id)


func discover_location(loc_id: String) -> void:
	if loc_id not in discovered_location_ids:
		discovered_location_ids.append(loc_id)
		state_changed.emit()


func is_location_discovered(loc_id: String) -> bool:
	return loc_id in discovered_location_ids


func get_exploration_state(map_id: String) -> Dictionary:
	if not exploration_states.has(map_id):
		exploration_states[map_id] = {"explored_tiles": [], "dead_actors": []}
	return exploration_states[map_id]


func mark_actor_dead(map_id: String, actor_id: String) -> void:
	var s := get_exploration_state(map_id)
	if actor_id not in s["dead_actors"]:
		s["dead_actors"].append(actor_id)


func mark_tiles_explored(map_id: String, cells: Array) -> void:
	var s := get_exploration_state(map_id)
	for cell: Vector2i in cells:
		if cell not in s["explored_tiles"]:
			s["explored_tiles"].append(cell)


func set_flag(flag_id: String, value: Variant = true) -> void:
	flags[flag_id] = value
	state_changed.emit()


func get_flag(flag_id: String, default: Variant = false) -> Variant:
	return flags.get(flag_id, default)


# ─── Karma & endings ───────────────────────────────────────────────────────────

func add_karma(delta: int) -> void:
	if delta == 0:
		return
	karma += delta
	state_changed.emit()


func get_karma() -> int:
	return karma


# The player's karma title — highest band threshold their karma meets. Campaign may
# override the bands in manifest.karma.titles ({ "<threshold>": "Title" }).
func get_karma_title() -> String:
	var titles: Dictionary = DataManager.get_manifest().get("karma", {}).get("titles", {})
	var best_label := "Neutral"
	var best_threshold := -2147483648
	if titles.is_empty():
		for threshold: int in DEFAULT_KARMA_TITLES:
			if karma >= threshold and threshold > best_threshold:
				best_threshold = threshold
				best_label = DEFAULT_KARMA_TITLES[threshold]
	else:
		for key in titles:
			var threshold := int(key)
			if karma >= threshold and threshold > best_threshold:
				best_threshold = threshold
				best_label = str(titles[key])
	return best_label


# Ask the active gameplay scene to roll the ending. Story hooks (a final dialogue line or
# a main-quest completion) call this; the scene listens on `ending_requested`.
func request_ending(ending_id: String = "default") -> void:
	pending_ending = ending_id
	ending_requested.emit(ending_id)


func add_rep(faction_id: String, delta: int) -> void:
	faction_rep[faction_id] = faction_rep.get(faction_id, 0) + delta
	state_changed.emit()


func get_rep(faction_id: String) -> int:
	return faction_rep.get(faction_id, 0)


func get_rep_label(faction_id: String) -> String:
	var faction := DataManager.get_faction(faction_id)
	if faction.is_empty():
		return "Unknown"
	var rep := get_rep(faction_id)
	var labels: Dictionary = faction.get("rep_labels", {})
	var thresholds: Dictionary = faction.get("rep_thresholds", {})
	var best_label := "Outsider"
	var best_threshold := -999
	for key in thresholds:
		var threshold: int = thresholds[key]
		if rep >= threshold and threshold > best_threshold:
			best_threshold = threshold
			best_label = labels.get(str(threshold), key)
	return best_label


# ─── Party / companions ────────────────────────────────────────────────────────

func recruit_companion(npc_id: String) -> void:
	if npc_id != "" and npc_id not in party:
		party.append(npc_id)
		state_changed.emit()


func dismiss_companion(npc_id: String) -> void:
	if npc_id in party:
		party.erase(npc_id)
		state_changed.emit()


func is_in_party(npc_id: String) -> bool:
	return npc_id in party


func get_party() -> Array:
	return party


func change_npc_relationship(npc_id: String, delta: int) -> void:
	npc_relationships[npc_id] = npc_relationships.get(npc_id, 0) + delta
	state_changed.emit()


func get_npc_relationship(npc_id: String) -> int:
	return npc_relationships.get(npc_id, 0)


func add_item(item_id: String, qty: int = 1) -> void:
	for entry in inventory:
		if entry["item_id"] == item_id:
			entry["quantity"] += qty
			state_changed.emit()
			return
	inventory.append({"item_id": item_id, "quantity": qty, "equipped": false})
	state_changed.emit()


func remove_item(item_id: String, qty: int = 1) -> bool:
	for i in inventory.size():
		if inventory[i]["item_id"] == item_id:
			if inventory[i]["quantity"] < qty:
				return false
			inventory[i]["quantity"] -= qty
			if inventory[i]["quantity"] <= 0:
				inventory.remove_at(i)
			state_changed.emit()
			return true
	return false


func has_item(item_id: String, qty: int = 1) -> bool:
	for entry in inventory:
		if entry["item_id"] == item_id and entry["quantity"] >= qty:
			return true
	return false


func get_item_quantity(item_id: String) -> int:
	for entry in inventory:
		if entry["item_id"] == item_id:
			return entry["quantity"]
	return 0


func _serialize_exploration_states() -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in exploration_states:
		var s: Dictionary = exploration_states[map_id]
		var tiles: Array = []
		for cell: Vector2i in s.get("explored_tiles", []):
			tiles.append({"x": cell.x, "y": cell.y})
		out[map_id] = {"explored_tiles": tiles, "dead_actors": s.get("dead_actors", []).duplicate()}
	return out


func _deserialize_exploration_states(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in data:
		var s: Dictionary = data[map_id]
		var tiles: Array[Vector2i] = []
		for t: Dictionary in s.get("explored_tiles", []):
			tiles.append(Vector2i(t.get("x", 0), t.get("y", 0)))
		out[map_id] = {"explored_tiles": tiles, "dead_actors": s.get("dead_actors", []).duplicate()}
	return out


func serialize() -> Dictionary:
	return {
		"player_name":           player_name,
		"stats":                 stats.duplicate(),
		"skill_investments":     skill_investments.duplicate(),
		"tagged_skills":         tagged_skills.duplicate(),
		"hp":                    hp,
		"xp":                    xp,
		"level":                 level,
		"karma":                 karma,
		"skill_points":          skill_points,
		"stat_points_available": stat_points_available,
		"perk_picks_available":  perk_picks_available,
		"perks":                 perks.duplicate(),
		"traits":                traits.duplicate(),
		"inventory":             inventory.duplicate(true),
		"caps":                  caps,
		"current_location":      current_location,
		"visited_locations":     visited_locations.duplicate(),
		"world_time_hours":      world_time_hours,
		"discovered_location_ids": discovered_location_ids.duplicate(),
		"return_scene":          return_scene,
		"exploration_states":    _serialize_exploration_states(),
		"faction_rep":           faction_rep.duplicate(),
		"npc_relationships":     npc_relationships.duplicate(),
		"npc_arcs_completed":    npc_arcs_completed.duplicate(true),
		"party":                 party.duplicate(),
		"quest_states":          quest_states.duplicate(true),
		"flags":                 flags.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	player_name              = data.get("player_name", "Drifter")
	stats                    = data.get("stats", stats)
	skill_investments        = data.get("skill_investments", skill_investments)
	tagged_skills            = data.get("tagged_skills", [])
	hp                       = data.get("hp", 0)
	xp                       = data.get("xp", 0)
	level                    = data.get("level", 1)
	karma                    = data.get("karma", 0)
	skill_points             = data.get("skill_points", 0)
	stat_points_available    = data.get("stat_points_available", 0)
	perk_picks_available     = data.get("perk_picks_available", 0)
	perks                    = data.get("perks", [])
	traits                   = data.get("traits", [])
	inventory                = data.get("inventory", [])
	caps                     = data.get("caps", 50)
	current_location         = data.get("current_location", "haven_ridge")
	visited_locations        = data.get("visited_locations", [])
	world_time_hours         = data.get("world_time_hours", 8)
	discovered_location_ids  = data.get("discovered_location_ids", [])
	return_scene             = data.get("return_scene", "")
	exploration_states       = _deserialize_exploration_states(data.get("exploration_states", {}))
	faction_rep              = data.get("faction_rep", {})
	npc_relationships        = data.get("npc_relationships", {})
	npc_arcs_completed       = data.get("npc_arcs_completed", {})
	party                    = data.get("party", [])
	quest_states             = data.get("quest_states", {})
	flags                    = data.get("flags", {})
	recalculate_derived()
	state_changed.emit()
