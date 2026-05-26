extends Node

signal state_changed

# --- Inventory ---
var inventory: Dictionary = {
	"scrap": 0,
	"relics": [],
	"echoes": [],
	"caches": [],
}

# --- Farm ---
# plot_id -> { "crop_id": String, "growth_stage": int, "days_since_watered": int, "planted_day": int }
var farm_plots: Dictionary = {}

# --- Village Standing ---
# companion_id -> standing int (not shown as a number to player, used internally for unlock gates)
var village_standing: Dictionary = {}

# --- Catalogue ---
# entry_id -> { "state": "sparse"|"annotated"|"complete", "annotations": [] }
var catalogue_entries: Dictionary = {}

# --- Companions ---
# Relationship is a raw integer, never displayed as a bar or percentage.
var companions: Dictionary = {
	"maren":  {"relationship": 0, "arcs_completed": []},
	"eli":    {"relationship": 0, "arcs_completed": []},
	"sable":  {"relationship": 0, "arcs_completed": []},
	"wren":   {"relationship": 0, "arcs_completed": []},
	"doss":   {"relationship": 0, "arcs_completed": []},
	"petra":  {"relationship": 0, "arcs_completed": []},
	"corvus": {"relationship": 0, "arcs_completed": []},
}

# --- Theory Board ---
# Weights accumulate silently. Never shown as percentages. Read at broadcast only.
var theory_weights: Dictionary = {
	"alignment_cascade": 0.0,
	"weaponized_drift":  0.0,
	"the_choice":        0.0,
	"civil_war":         0.0,
	"convergence":       0.0,
	"holdouts":          0.0,
}

# --- Technology ---
var tech_tier: int = 1

# --- Zones ---
# zone_id -> { "visited": bool, "locations_explored": [] }
var zones: Dictionary = {}

# --- Tools ---
var tool_infrastructure_tier: int = 1
var tool_backup_made: bool = false

# --- Arc flags ---
# Generic key/value store for arc milestones and one-off event state.
var flags: Dictionary = {}


func new_game() -> void:
	inventory = {"scrap": 0, "relics": [], "echoes": [], "caches": []}
	catalogue_entries = {}
	for id in companions:
		companions[id] = {"relationship": 0, "arcs_completed": []}
	for id in theory_weights:
		theory_weights[id] = 0.0
	tech_tier = 1
	zones = {}
	tool_infrastructure_tier = 1
	tool_backup_made = false
	flags = {}
	farm_plots = {}
	village_standing = {}
	state_changed.emit()


func set_flag(flag_id: String, value: Variant = true) -> void:
	flags[flag_id] = value
	state_changed.emit()


func get_flag(flag_id: String, default: Variant = false) -> Variant:
	return flags.get(flag_id, default)


func add_theory_weight(theory_id: String, weight: float) -> void:
	if theory_id in theory_weights:
		theory_weights[theory_id] += weight
		state_changed.emit()


# Returns the theory with the highest accumulated weight at broadcast time.
# In the event of a tie, convergence wins — all-of-the-above is always valid.
func get_dominant_theory() -> String:
	var max_weight := 0.0
	var dominant := "convergence"
	for theory_id in theory_weights:
		if theory_weights[theory_id] > max_weight:
			max_weight = theory_weights[theory_id]
			dominant = theory_id
	return dominant


func add_to_inventory(artifact_type: String, artifact_id: String) -> void:
	match artifact_type:
		"scrap":
			inventory["scrap"] += 1
		"relic":
			if artifact_id not in inventory["relics"]:
				inventory["relics"].append(artifact_id)
		"echo":
			if artifact_id not in inventory["echoes"]:
				inventory["echoes"].append(artifact_id)
		"cache":
			if artifact_id not in inventory["caches"]:
				inventory["caches"].append(artifact_id)
	state_changed.emit()


func mark_zone_visited(zone_id: String) -> void:
	if zone_id not in zones:
		zones[zone_id] = {"visited": true, "locations_explored": []}
	else:
		zones[zone_id]["visited"] = true
	state_changed.emit()


func mark_location_explored(zone_id: String, location_id: String) -> void:
	if zone_id not in zones:
		zones[zone_id] = {"visited": true, "locations_explored": []}
	if location_id not in zones[zone_id]["locations_explored"]:
		zones[zone_id]["locations_explored"].append(location_id)
	state_changed.emit()


func serialize() -> Dictionary:
	return {
		"inventory":               inventory.duplicate(true),
		"catalogue_entries":       catalogue_entries.duplicate(true),
		"companions":              companions.duplicate(true),
		"theory_weights":          theory_weights.duplicate(true),
		"tech_tier":               tech_tier,
		"zones":                   zones.duplicate(true),
		"tool_infrastructure_tier": tool_infrastructure_tier,
		"tool_backup_made":        tool_backup_made,
		"flags":                   flags.duplicate(true),
		"farm_plots":              farm_plots.duplicate(true),
		"village_standing":        village_standing.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	inventory                 = data.get("inventory", inventory)
	catalogue_entries         = data.get("catalogue_entries", catalogue_entries)
	companions                = data.get("companions", companions)
	theory_weights            = data.get("theory_weights", theory_weights)
	tech_tier                 = data.get("tech_tier", 1)
	zones                     = data.get("zones", zones)
	tool_infrastructure_tier  = data.get("tool_infrastructure_tier", 1)
	tool_backup_made          = data.get("tool_backup_made", false)
	flags                     = data.get("flags", flags)
	farm_plots                = data.get("farm_plots", {})
	village_standing          = data.get("village_standing", {})
	state_changed.emit()
