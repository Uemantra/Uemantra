extends RefCounted
class_name BoardState

# Read-only view of GameState for the Theory Board.
# Does not modify anything — only interprets flags set by the Rig (SEG-04).
#
# Flag conventions (set by the Rig on Accept/Verify):
#   "echo_contributed_" + echo_id + "_" + theory_id  -> true
#   "inconclusive_" + echo_id                         -> true  (set by CatalogueManager)
#   "board_connection_" + echo_id + "_" + theory_id   -> true  (cosmetic, set by the board)


func get_theory_evidence(theory_id: String) -> Array[String]:
	var result: Array[String] = []
	for flag_key in GameState.flags:
		if _is_contribution_flag(flag_key, theory_id):
			var echo_id := _extract_echo_id_from_contribution(flag_key, theory_id)
			if echo_id != "":
				result.append(echo_id)
	return result


func get_unresolved_echoes() -> Array[String]:
	var result: Array[String] = []
	for flag_key in GameState.flags:
		if flag_key.begins_with("inconclusive_") and GameState.flags[flag_key] == true:
			var echo_id := flag_key.substr("inconclusive_".length())
			result.append(echo_id)
	return result


func get_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for flag_key in GameState.flags:
		if flag_key.begins_with("board_connection_") and GameState.flags[flag_key] == true:
			var rest := flag_key.substr("board_connection_".length())
			# Format: echo_id + "_" + theory_id
			# theory_ids never contain underscores that would be ambiguous — they use
			# compound words (alignment_cascade, weaponized_drift, etc.) but echo_ids
			# use the pattern "echo_NNN", so we split on the last known theory prefix.
			var parsed := _parse_connection_flag(rest)
			if not parsed.is_empty():
				result.append(parsed)
	return result


func get_holdouts_evidence() -> Array[String]:
	return get_theory_evidence("holdouts")


# --- Internal helpers ---

func _is_contribution_flag(flag_key: String, theory_id: String) -> bool:
	if not flag_key.begins_with("echo_contributed_"):
		return false
	return flag_key.ends_with("_" + theory_id)


func _extract_echo_id_from_contribution(flag_key: String, theory_id: String) -> String:
	# Strip prefix and suffix to get echo_id.
	var prefix := "echo_contributed_"
	var suffix := "_" + theory_id
	if not (flag_key.begins_with(prefix) and flag_key.ends_with(suffix)):
		return ""
	var inner := flag_key.substr(prefix.length(), flag_key.length() - prefix.length() - suffix.length())
	return inner


func _parse_connection_flag(rest: String) -> Dictionary:
	# rest is: echo_id + "_" + theory_id
	# Known theory ids are fixed — match from the end.
	var known_theories: Array[String] = [
		"alignment_cascade", "weaponized_drift", "the_choice",
		"civil_war", "convergence", "holdouts"
	]
	for theory_id in known_theories:
		if rest.ends_with("_" + theory_id):
			var echo_id := rest.substr(0, rest.length() - 1 - theory_id.length())
			if echo_id != "":
				return {"echo_id": echo_id, "theory_id": theory_id}
	return {}
