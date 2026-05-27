extends Node

signal state_changed

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
var skill_points: int = 0        # available to spend

# --- Inventory ---
var inventory: Array = []        # Array of { item_id, quantity, equipped }
var caps: int = 50               # starting caps

# --- World ---
var current_location: String = "haven_ridge"
var visited_locations: Array = []
var world_time_hours: int = 8    # starts at 8am day 1

# --- Factions ---
var faction_rep: Dictionary = {}   # faction_id -> int

# --- NPCs ---
var npc_relationships: Dictionary = {}    # npc_id -> int
var npc_arcs_completed: Dictionary = {}   # npc_id -> Array[String]

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


func new_game() -> void:
	player_name = "Drifter"
	stats = {"grit":5,"reflex":5,"mind":5,"body":5,"nerve":5,"presence":5}
	skill_investments = {"guns":0,"melee":0,"speech":0,"intimidate":0,"barter":0,"medicine":0,"lockpick":0,"tech":0,"stealth":0}
	hp = 0
	xp = 0
	level = 1
	skill_points = 0
	inventory = []
	caps = 50
	current_location = "haven_ridge"
	visited_locations = []
	world_time_hours = 8
	faction_rep = {}
	npc_relationships = {}
	npc_arcs_completed = {}
	quest_states = {}
	flags = {}
	recalculate_derived()
	hp = derived.get("max_hp", 20)
	state_changed.emit()


func recalculate_derived() -> void:
	derived["max_hp"]          = 20 + stats["body"] * 4 + stats["grit"] * 2
	derived["max_ap"]          = 4 + stats["reflex"]
	derived["carry_weight_max"] = 30 + stats["body"] * 5
	derived["evasion_base"]    = stats["reflex"] * 2
	derived["melee_dmg_bonus"] = stats["body"] / 3

	for skill_id in SKILL_BASE:
		var bases: Dictionary = SKILL_BASE[skill_id]
		var base_val: int = (
			stats[bases["primary"]] * 8 +
			stats[bases["secondary"]] * 4 + 5
		)
		var invested: int = skill_investments.get(skill_id, 0)
		skills[skill_id] = base_val + invested * 2


func set_flag(flag_id: String, value: Variant = true) -> void:
	flags[flag_id] = value
	state_changed.emit()


func get_flag(flag_id: String, default: Variant = false) -> Variant:
	return flags.get(flag_id, default)


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


func serialize() -> Dictionary:
	return {
		"player_name":       player_name,
		"stats":             stats.duplicate(),
		"skill_investments": skill_investments.duplicate(),
		"hp":                hp,
		"xp":                xp,
		"level":             level,
		"skill_points":      skill_points,
		"inventory":         inventory.duplicate(true),
		"caps":              caps,
		"current_location":  current_location,
		"visited_locations": visited_locations.duplicate(),
		"world_time_hours":  world_time_hours,
		"faction_rep":       faction_rep.duplicate(),
		"npc_relationships": npc_relationships.duplicate(),
		"npc_arcs_completed": npc_arcs_completed.duplicate(true),
		"quest_states":      quest_states.duplicate(true),
		"flags":             flags.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	player_name       = data.get("player_name", "Drifter")
	stats             = data.get("stats", stats)
	skill_investments = data.get("skill_investments", skill_investments)
	hp                = data.get("hp", 0)
	xp                = data.get("xp", 0)
	level             = data.get("level", 1)
	skill_points      = data.get("skill_points", 0)
	inventory         = data.get("inventory", [])
	caps              = data.get("caps", 50)
	current_location  = data.get("current_location", "haven_ridge")
	visited_locations = data.get("visited_locations", [])
	world_time_hours  = data.get("world_time_hours", 8)
	faction_rep       = data.get("faction_rep", {})
	npc_relationships = data.get("npc_relationships", {})
	npc_arcs_completed = data.get("npc_arcs_completed", {})
	quest_states      = data.get("quest_states", {})
	flags             = data.get("flags", {})
	recalculate_derived()
	state_changed.emit()
