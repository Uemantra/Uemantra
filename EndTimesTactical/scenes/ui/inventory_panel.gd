extends PanelContainer

@onready var _caps_label: Label = $Contents/TitleRow/CapsLabel
@onready var _close_btn: Button = $Contents/TitleRow/CloseBtn
@onready var _item_vbox: VBoxContainer = $Contents/ItemList/ItemVBox
@onready var _stats_label: Label = $Contents/StatsLabel


func _ready() -> void:
	_close_btn.pressed.connect(queue_free)
	_refresh()


func _refresh() -> void:
	_caps_label.text = "Caps: %d" % GameState.caps

	for child in _item_vbox.get_children():
		child.queue_free()

	var total_weight := 0.0
	for entry in GameState.inventory:
		var item := DataManager.get_item(entry.get("item_id", ""))
		if item.is_empty():
			continue
		total_weight += item.get("weight", 0.0) * entry.get("quantity", 1)
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		var qty := entry.get("quantity", 1)
		var equipped: bool = entry.get("equipped", false)
		name_lbl.text = "%s x%d%s" % [item.get("name", "?"), qty, " [E]" if equipped else ""]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.theme_override_font_sizes = {"font_size": 14}
		row.add_child(name_lbl)

		var type_str: String = item.get("type", "")
		if type_str in ["weapon", "armor"]:
			var equip_btn := Button.new()
			equip_btn.text = "Unequip" if equipped else "Equip"
			equip_btn.custom_minimum_size = Vector2(80, 32)
			equip_btn.pressed.connect(_on_equip.bind(entry.get("item_id", ""), not equipped))
			row.add_child(equip_btn)

		if type_str == "consumable":
			var use_btn := Button.new()
			use_btn.text = "Use"
			use_btn.custom_minimum_size = Vector2(60, 32)
			use_btn.pressed.connect(_on_use.bind(entry.get("item_id", "")))
			row.add_child(use_btn)

		_item_vbox.add_child(row)

	var carry_max: int = GameState.derived.get("carry_weight_max", 55)
	_stats_label.text = "Weight: %.1f / %d kg" % [total_weight, carry_max]


func _on_equip(item_id: String, equip: bool) -> void:
	var item := DataManager.get_item(item_id)
	var item_type: String = item.get("type", "")
	if equip:
		for entry in GameState.inventory:
			var other := DataManager.get_item(entry.get("item_id", ""))
			if other.get("type", "") == item_type:
				entry["equipped"] = false
	for entry in GameState.inventory:
		if entry.get("item_id", "") == item_id:
			entry["equipped"] = equip
			break
	GameState.state_changed.emit()
	_refresh()


func _on_use(item_id: String) -> void:
	var item := DataManager.get_item(item_id)
	for effect in item.get("effects", []):
		match effect.get("type", ""):
			"heal_hp":
				GameState.hp = min(GameState.hp + effect.get("value", 0), GameState.derived.get("max_hp", 20))
			"remove_status":
				pass  # Wire to status effect system when implemented
	GameState.remove_item(item_id, 1)
	_refresh()
