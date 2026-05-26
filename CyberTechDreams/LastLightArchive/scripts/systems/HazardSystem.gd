extends RefCounted

# "flooded" requires tech tier 2+ (raft). Pass current tier to evaluate().
func evaluate(location_data: Dictionary, player_has_light: bool, player_tech_tier: int = 1) -> Dictionary:
	var hazards: Array = location_data.get("hazards", [])
	if hazards.is_empty():
		return {"blocked": false, "description": "", "hazard_type": ""}

	for hazard in hazards:
		var h_type: String = hazard.get("type", "")
		var h_desc: String = hazard.get("description", "")
		match h_type:
			"darkness":
				if not player_has_light:
					return {
						"blocked": true,
						"description": h_desc,
						"hazard_type": "darkness",
					}
			"flooded":
				if player_tech_tier < 2:
					return {
						"blocked": true,
						"description": h_desc,
						"hazard_type": "flooded",
					}
			"unstable":
				# Never blocked — Vera notes the risk and continues.
				return {
					"blocked": false,
					"description": h_desc,
					"hazard_type": "unstable",
				}

	return {"blocked": false, "description": "", "hazard_type": ""}
