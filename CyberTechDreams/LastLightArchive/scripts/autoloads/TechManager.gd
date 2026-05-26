extends Node

signal item_built(item_id: String)
signal tier_unlocked(tier: int)
signal zone_unlocked(zone_id: String)

var _tech_tree: Dictionary = {}

# Tier metadata: subtitle and cultural unlock text, indexed by tier number.
# Items themselves carry per-item cultural_unlock; this is the tier-level summary.
const TIER_SUBTITLES: Dictionary = {
	1: "Making do with what's here",
	2: "Remembering how things fit together",
	3: "Understanding what we lost",
	4: "Sending it forward",
}

const TIER_NAMES: Dictionary = {
	1: "Salvage",
	2: "Fabrication",
	3: "Electronics",
	4: "Broadcast",
}


func _ready() -> void:
	_tech_tree = DataManager.tech_tree


func is_built(item_id: String) -> bool:
	return GameState.get_flag("built_" + item_id)


func can_build(item_id: String) -> Dictionary:
	# Returns { "ok": bool, "missing_prerequisites": [], "missing_companions": [], "scrap_short": int }
	var result := {
		"ok": false,
		"missing_prerequisites": [],
		"missing_companions": [],
		"scrap_short": 0,
	}

	var item: Dictionary = _tech_tree.get(item_id, {})
	if item.is_empty():
		return result

	if is_built(item_id):
		return result

	# Check prerequisites — each entry is either a flag name or an item_id.
	# Tier completion flags ("tier_1_complete" etc.) live directly in GameState.flags.
	# Item build flags use the "built_" prefix.
	for prereq in item.get("prerequisites", []):
		var satisfied: bool
		if prereq.begins_with("tier_") or prereq.begins_with("built_"):
			satisfied = GameState.get_flag(prereq)
		else:
			satisfied = is_built(prereq)
		if not satisfied:
			result["missing_prerequisites"].append(prereq)

	# Check companion relationship requirements.
	for companion_id in item.get("companion_requirements", {}):
		var required_rel: int = item["companion_requirements"][companion_id]
		var actual_rel: int = 0
		if GameState.companions.has(companion_id):
			actual_rel = GameState.companions[companion_id].get("relationship", 0)
		if actual_rel < required_rel:
			result["missing_companions"].append(companion_id)

	# Check scrap.
	var cost: int = item.get("cost_scrap", 0)
	var have: int = GameState.inventory.get("scrap", 0)
	if have < cost:
		result["scrap_short"] = cost - have

	result["ok"] = (
		result["missing_prerequisites"].is_empty()
		and result["missing_companions"].is_empty()
		and result["scrap_short"] == 0
	)
	return result


func build(item_id: String) -> bool:
	var check := can_build(item_id)
	if not check["ok"]:
		return false

	var item: Dictionary = _tech_tree[item_id]
	var cost: int = item.get("cost_scrap", 0)

	GameState.inventory["scrap"] -= cost

	# Mark as built.
	GameState.set_flag("built_" + item_id, true)

	_apply_mechanical_effects(item_id, item.get("mechanical_effects", {}))
	_check_tier_completion(item.get("tier", 0))

	item_built.emit(item_id)
	return true


func get_all_items_for_tier(tier: int) -> Array:
	var result: Array = []
	for item_id in _tech_tree:
		if _tech_tree[item_id].get("tier", 0) == tier:
			result.append(_tech_tree[item_id])
	return result


func get_current_tier() -> int:
	return GameState.tech_tier


func get_tier_name(tier: int) -> String:
	return TIER_NAMES.get(tier, "")


func get_tier_subtitle(tier: int) -> String:
	return TIER_SUBTITLES.get(tier, "")


# Returns the cultural unlock text for a tier — taken from the first item in that
# tier that has a non-empty cultural_unlock, since only one item per tier carries it.
func get_tier_cultural_unlock(tier: int) -> String:
	for item_id in _tech_tree:
		var item: Dictionary = _tech_tree[item_id]
		if item.get("tier", 0) == tier and item.get("cultural_unlock", "") != "":
			return item["cultural_unlock"]
	return ""


func _apply_mechanical_effects(item_id: String, effects: Dictionary) -> void:
	if effects.is_empty():
		return

	# sets_flag is already handled via built_ prefix in build().
	# Named mechanical effects below are additive to that.

	if item_id == "raft":
		GameState.set_flag("has_raft", true)
		zone_unlocked.emit("zone_flooded")

	elif item_id == "hardware_bench":
		# built_ flag is already set; hardware_bench_built is the canonical check
		# for Cache reading elsewhere in the codebase.
		GameState.set_flag("hardware_bench_built", true)

	elif item_id == "cross_verification_rig":
		GameState.tool_infrastructure_tier = 3
		GameState.state_changed.emit()

	elif item_id == "hardened_storage":
		GameState.tool_backup_made = true
		GameState.state_changed.emit()

	elif item_id == "community_hall":
		GameState.set_flag("community_hall_built", true)

	elif item_id.begins_with("broadcast_tower_stage_"):
		_check_broadcast_ready()


func _check_broadcast_ready() -> void:
	if (
		GameState.get_flag("built_broadcast_tower_stage_1")
		and GameState.get_flag("built_broadcast_tower_stage_2")
		and GameState.get_flag("built_broadcast_tower_stage_3")
	):
		GameState.set_flag("broadcast_ready", true)


func _check_tier_completion(tier: int) -> void:
	if tier < 1 or tier > 4:
		return

	# Already completed.
	if GameState.get_flag("tier_%d_complete" % tier):
		return

	var items := get_all_items_for_tier(tier)
	for item in items:
		if item.get("optional", false):
			continue
		if not is_built(item["id"]):
			return

	# All items built.
	GameState.set_flag("tier_%d_complete" % tier, true)
	if GameState.tech_tier < tier + 1:
		GameState.tech_tier = tier + 1
		GameState.state_changed.emit()
	tier_unlocked.emit(tier)
