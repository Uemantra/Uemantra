extends Node

signal broadcast_initiated
signal machines_said_choice_made(choice: String)
signal broadcast_sequence_complete
signal epilogue_started(theory_id: String)

# Preferred Catalogue sections for epilogue narration, in order.
const _PREFERRED_SECTIONS: Array = ["people_we_never_knew", "recovered_fragments"]
const _MAX_EPILOGUE_ENTRIES: int = 5


func can_initiate() -> bool:
	return GameState.get_flag("broadcast_ready", false)


func initiate_broadcast() -> void:
	if not can_initiate():
		return
	if GameState.get_flag("broadcast_initiated", false):
		return
	GameState.set_flag("broadcast_initiated", true)
	broadcast_initiated.emit()


func set_machines_said_choice(choice: String) -> void:
	GameState.set_flag("machines_said_choice", choice)
	machines_said_choice_made.emit(choice)


func complete_broadcast() -> void:
	GameState.set_flag("broadcast_complete", true)
	var theory_id := get_dominant_theory()
	broadcast_sequence_complete.emit()
	epilogue_started.emit(theory_id)


func get_dominant_theory() -> String:
	return GameState.get_dominant_theory()


# Returns an Array of entry_id strings for Vera to read in the epilogue.
# Prefers "people_we_never_knew" and "recovered_fragments", includes at least
# one relic if available, capped at _MAX_EPILOGUE_ENTRIES.
func get_epilogue_entries() -> Array:
	var selected: Array = []

	# Pass 1: preferred sections in order.
	for section in _PREFERRED_SECTIONS:
		var entries: Array = CatalogueManager.get_all_entries_for_section(section)
		for entry_id in entries:
			if entry_id not in selected:
				selected.append(entry_id)
			if selected.size() >= _MAX_EPILOGUE_ENTRIES:
				break
		if selected.size() >= _MAX_EPILOGUE_ENTRIES:
			break

	# Pass 2: ensure at least one relic if we have room and one exists.
	var has_relic := false
	for entry_id in selected:
		var entry: Dictionary = CatalogueManager.get_entry(entry_id)
		if entry.get("section", "") == "relics":
			has_relic = true
			break

	if not has_relic and selected.size() < _MAX_EPILOGUE_ENTRIES:
		var relic_entries: Array = CatalogueManager.get_all_entries_for_section("relics")
		if not relic_entries.is_empty():
			selected.append(relic_entries[0])

	# Pass 3: fill remaining slots from any section.
	if selected.size() < _MAX_EPILOGUE_ENTRIES:
		for entry_id in GameState.catalogue_entries:
			if entry_id not in selected:
				selected.append(entry_id)
			if selected.size() >= _MAX_EPILOGUE_ENTRIES:
				break

	return selected


# Returns Array[Dictionary] with keys: companion_id, arc_resolved, card_text.
# Only companions the player has met (relationship > 0) are included.
# Arc resolved = arcs_completed is not empty.
# Unresolved arcs get card_text "Still here."
func get_companion_cards() -> Array:
	var cards: Array = []
	var companion_data_all: Dictionary = DataManager.companions_data

	for companion_id in GameState.companions:
		var gs_data: Dictionary = GameState.companions[companion_id]
		var relationship: int = gs_data.get("relationship", 0)
		if relationship <= 0:
			continue

		var arcs_completed: Array = gs_data.get("arcs_completed", [])
		var arc_resolved: bool = not arcs_completed.is_empty()
		var card_text: String

		if arc_resolved:
			card_text = _resolved_card_text(companion_id, companion_data_all)
		else:
			card_text = "Still here."

		cards.append({
			"companion_id": companion_id,
			"arc_resolved": arc_resolved,
			"card_text": card_text,
		})

	return cards


# --------------------------------------------------------------------------- #
# Internal
# --------------------------------------------------------------------------- #

func _resolved_card_text(companion_id: String, companion_data_all: Dictionary) -> String:
	var data: Dictionary = companion_data_all.get(companion_id, {})
	var role: String = data.get("role", "")
	var arc_summary: String = data.get("arc_summary", "")

	# Build one sentence from the arc_summary.
	# We take the first sentence (ending at the first period or the full string).
	var sentence: String = arc_summary
	var period_pos: int = arc_summary.find(".")
	if period_pos > 0:
		sentence = arc_summary.substr(0, period_pos + 1)

	if role != "" and sentence != "":
		return "%s. %s" % [role, sentence]
	elif role != "":
		return role + "."
	elif sentence != "":
		return sentence
	return "Still here."
