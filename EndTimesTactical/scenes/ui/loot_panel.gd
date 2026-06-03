extends PanelContainer

signal loot_done()

@onready var _item_vbox:   VBoxContainer = $VBox/Scroll/ItemVBox
@onready var _take_all_btn: Button       = $VBox/ButtonRow/TakeAllBtn
@onready var _done_btn:     Button       = $VBox/ButtonRow/DoneBtn


func _ready() -> void:
	_take_all_btn.pressed.connect(_on_take_all)
	_done_btn.pressed.connect(_finish)
	loot_done.connect(queue_free)
	_refresh()


func _finish() -> void:
	loot_done.emit()


func _refresh() -> void:
	for child in _item_vbox.get_children():
		child.queue_free()

	if CombatManager.pending_loot.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing to loot."
		lbl.add_theme_font_size_override("font_size", 20)
		_item_vbox.add_child(lbl)
		_take_all_btn.disabled = true
		return

	_take_all_btn.disabled = false
	for entry: Dictionary in CombatManager.pending_loot:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(IconMapper.make_item_icon(entry["item_id"], "misc"))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 20)

		if entry["item_id"] == "__caps__":
			lbl.text = "Caps  ×%d" % entry["quantity"]
		else:
			var item := DataManager.get_item(entry["item_id"])
			lbl.text = "%s  ×%d" % [item.get("name", entry["item_id"]), entry["quantity"]]

		row.add_child(lbl)

		var take_btn := Button.new()
		take_btn.text = "TAKE"
		take_btn.custom_minimum_size = Vector2(70, 32)
		take_btn.pressed.connect(_on_take.bind(entry["item_id"]))
		row.add_child(take_btn)

		_item_vbox.add_child(row)


func _on_take(item_id: String) -> void:
	for i in CombatManager.pending_loot.size():
		var entry: Dictionary = CombatManager.pending_loot[i]
		if entry["item_id"] != item_id:
			continue
		_apply_loot(item_id, entry["quantity"])
		CombatManager.pending_loot.remove_at(i)
		break
	_refresh()


func _on_take_all() -> void:
	for entry: Dictionary in CombatManager.pending_loot:
		_apply_loot(entry["item_id"], entry["quantity"])
	CombatManager.pending_loot.clear()
	_finish()


func _apply_loot(item_id: String, qty: int) -> void:
	if item_id == "__caps__":
		GameState.caps += qty
	else:
		GameState.add_item(item_id, qty)
