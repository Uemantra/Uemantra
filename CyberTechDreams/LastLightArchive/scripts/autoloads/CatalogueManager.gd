extends Node

signal cache_processing_started(cache_id: String, tool_id: String)
signal cache_processing_complete(cache_id: String, results: Array)
signal entry_created(entry_id: String)
signal entry_annotated(entry_id: String)
signal theory_weight_added(theory_id: String, weight: float, echo_id: String)


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


# --- Queue management ---

func queue_cache(cache_id: String, tool_id: String) -> void:
	var queue := _get_queue()
	for item in queue:
		if item.get("cache_id") == cache_id and item.get("tool_id") == tool_id:
			return
	queue.append({"cache_id": cache_id, "tool_id": tool_id})
	_save_queue(queue)


func dequeue_cache(cache_id: String, tool_id: String) -> void:
	var queue := _get_queue()
	for i in range(queue.size() - 1, -1, -1):
		var item: Dictionary = queue[i]
		if item.get("cache_id") == cache_id and item.get("tool_id") == tool_id:
			queue.remove_at(i)
	_save_queue(queue)


func get_queue() -> Array:
	return _get_queue()


# --- Immediate processing ---

func process_cache_now(cache_id: String, tool_id: String) -> void:
	if not _can_use_tool(tool_id):
		push_error("CatalogueManager: tool '%s' not available at tier %d" % [tool_id, GameState.tool_infrastructure_tier])
		return
	cache_processing_started.emit(cache_id, tool_id)
	# The workshop scene drives the typewriter; results are assembled from data.
	# This signal is the trigger — actual result delivery happens when the
	# typewriter completes and the player makes an interpretation choice.


func is_processed(cache_id: String) -> bool:
	return GameState.get_flag("processed_" + cache_id, false)


func mark_processed(cache_id: String) -> void:
	GameState.set_flag("processed_" + cache_id, true)


# --- Interpretation choices ---

func accept_interpretation(cache_id: String, entry_id: String) -> void:
	var cache_data := DataManager.get_cache(cache_id)
	if cache_data.is_empty():
		return
	for yield_item in cache_data.get("yields", []):
		if yield_item.get("entry_id") != entry_id:
			continue
		var section: String = yield_item.get("catalogue_section", "uncategorised")
		var content: String = yield_item.get("content", "")
		var vera_note: String = yield_item.get("vera_note", "")
		create_entry(entry_id, section, content, vera_note)
		for theory_id in yield_item.get("theory_contributions", {}):
			var w: float = yield_item["theory_contributions"][theory_id]
			GameState.add_theory_weight(theory_id, w)
			theory_weight_added.emit(theory_id, w, "")
		break
	# Echoes carry their own theory weights separately.
	var echo_data := DataManager.get_echo(cache_id)
	if not echo_data.is_empty():
		for theory_id in echo_data.get("theory_contributions", {}):
			var w: float = echo_data["theory_contributions"][theory_id]
			GameState.add_theory_weight(theory_id, w)
			theory_weight_added.emit(theory_id, w, cache_id)
	mark_processed(cache_id)


func verify_interpretation(cache_id: String, tool_id: String) -> Dictionary:
	# Returns the actual (unvarnished) output and a flag indicating if the tool was wrong.
	# Also applies the partial weight modifier from the echo/cache data.
	var cache_data := DataManager.get_cache(cache_id)
	var echo_data := DataManager.get_echo(cache_id)
	var source := cache_data if not cache_data.is_empty() else echo_data
	if source.is_empty():
		return {}

	var tool_outputs: Dictionary = source.get("tool_outputs", {})
	if tool_id not in tool_outputs:
		return {}

	var tool_out: Dictionary = tool_outputs[tool_id]
	var is_wrong: bool = tool_out.get("is_wrong", false)
	var actual: String = tool_out.get("actual_output", tool_out.get("interpretation", ""))
	var weight_modifier: float = source.get("verification_weight_modifier", 1.0)

	# Apply partial theory weight from echo contributions.
	if not echo_data.is_empty():
		for theory_id in echo_data.get("theory_contributions", {}):
			var base_w: float = echo_data["theory_contributions"][theory_id]
			GameState.add_theory_weight(theory_id, base_w * weight_modifier)
			theory_weight_added.emit(theory_id, base_w * weight_modifier, cache_id)

	mark_processed(cache_id)
	return {
		"actual_output": actual,
		"is_wrong": is_wrong,
		"failure_mode": tool_out.get("failure_mode", ""),
		"verification_result": source.get("verification_result", ""),
	}


func cross_reference(cache_id: String, tool_id_2: String) -> Dictionary:
	if GameState.tool_infrastructure_tier < 3:
		push_error("CatalogueManager: cross_reference requires tool_infrastructure_tier >= 3")
		return {}
	if not _can_use_tool(tool_id_2):
		return {}
	var cache_data := DataManager.get_cache(cache_id)
	var echo_data := DataManager.get_echo(cache_id)
	var source := cache_data if not cache_data.is_empty() else echo_data
	if source.is_empty():
		return {}
	var tool_outputs: Dictionary = source.get("tool_outputs", {})
	if tool_id_2 not in tool_outputs:
		return {"tool_id": tool_id_2, "output": "", "available": false}
	var tool_out: Dictionary = tool_outputs[tool_id_2]
	return {
		"tool_id": tool_id_2,
		"output": tool_out.get("confident_output", tool_out.get("interpretation", "")),
		"confidence": tool_out.get("confidence", -1.0),
		"available": true,
	}


func mark_inconclusive(cache_id: String, echo_id: String) -> void:
	GameState.set_flag("inconclusive_" + echo_id, true)
	mark_processed(cache_id)


# --- Catalogue entry methods ---

func create_entry(entry_id: String, section: String, content: String, vera_note: String) -> void:
	if entry_id in GameState.catalogue_entries:
		return
	GameState.catalogue_entries[entry_id] = {
		"state": "sparse",
		"section": section,
		"content": content,
		"vera_note": vera_note,
		"annotations": [],
	}
	GameState.state_changed.emit()
	entry_created.emit(entry_id)


func annotate_entry(entry_id: String, annotation: String) -> void:
	if entry_id not in GameState.catalogue_entries:
		push_error("CatalogueManager: annotate_entry called on unknown entry '%s'" % entry_id)
		return
	var entry: Dictionary = GameState.catalogue_entries[entry_id]
	entry["annotations"].append(annotation)
	if entry["state"] == "sparse":
		entry["state"] = "annotated"
	GameState.state_changed.emit()
	entry_annotated.emit(entry_id)


func get_entry(entry_id: String) -> Dictionary:
	return GameState.catalogue_entries.get(entry_id, {})


func get_all_entries_for_section(section: String) -> Array:
	var result: Array = []
	for entry_id in GameState.catalogue_entries:
		var entry: Dictionary = GameState.catalogue_entries[entry_id]
		if entry.get("section", "") == section:
			result.append(entry_id)
	return result


# --- Overnight queue processing ---

func process_overnight_queue() -> void:
	var queue := _get_queue()
	if queue.is_empty():
		return
	var processed_results: Array = []
	for item in queue:
		var cache_id: String = item.get("cache_id", "")
		var tool_id: String = item.get("tool_id", "")
		if cache_id.is_empty() or tool_id.is_empty():
			continue
		if not _can_use_tool(tool_id):
			continue
		var results := _build_results(cache_id, tool_id)
		mark_processed(cache_id)
		processed_results.append({"cache_id": cache_id, "tool_id": tool_id, "results": results})
		cache_processing_complete.emit(cache_id, results)
	if not processed_results.is_empty():
		GameState.set_flag("rig_overnight_results", JSON.stringify(processed_results))
	_save_queue([])


# --- Internal helpers ---

func _get_queue() -> Array:
	var raw: Variant = GameState.get_flag("rig_queue", "[]")
	if raw is String:
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array:
			return parsed
	return []


func _save_queue(queue: Array) -> void:
	GameState.set_flag("rig_queue", JSON.stringify(queue))


func _can_use_tool(tool_id: String) -> bool:
	var tool_data := DataManager.get_tool(tool_id)
	if tool_data.is_empty():
		return false
	var min_tier: int = tool_data.get("available_from_infrastructure_tier", 1)
	return GameState.tool_infrastructure_tier >= min_tier


func _build_results(cache_id: String, tool_id: String) -> Array:
	var cache_data := DataManager.get_cache(cache_id)
	var echo_data := DataManager.get_echo(cache_id)
	var source := cache_data if not cache_data.is_empty() else echo_data
	if source.is_empty():
		return []
	var results: Array = []
	var tool_outputs: Dictionary = source.get("tool_outputs", {})
	for yield_item in source.get("yields", []):
		results.append({
			"entry_id": yield_item.get("entry_id", ""),
			"vera_note": yield_item.get("vera_note", ""),
			"content": yield_item.get("content", ""),
			"catalogue_section": yield_item.get("catalogue_section", ""),
		})
	if tool_id in tool_outputs:
		var tool_out: Dictionary = tool_outputs[tool_id]
		results.append({
			"tool_output": tool_out.get("confident_output", tool_out.get("interpretation", "")),
			"confidence": tool_out.get("confidence", -1.0),
			"tool_id": tool_id,
		})
	return results


func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	process_overnight_queue()
