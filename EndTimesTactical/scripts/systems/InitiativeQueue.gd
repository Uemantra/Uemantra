class_name InitiativeQueue
extends RefCounted

var _order: Array = []


func build(combatants: Dictionary) -> void:
	_order = combatants.keys()
	_order.sort_custom(func(a, b):
		return combatants[a].get("initiative", 0) > combatants[b].get("initiative", 0)
	)


func current() -> String:
	if _order.is_empty():
		return ""
	return _order[0]


func advance() -> void:
	if not _order.is_empty():
		_order.append(_order.pop_front())


func remove(combatant_id: String) -> void:
	_order.erase(combatant_id)


func get_order() -> Array:
	return _order.duplicate()


func is_empty() -> bool:
	return _order.is_empty()
