extends Control

# Built item panel colors — not decorative, functional contrast.
const COLOR_BUILT := Color(0.35, 0.55, 0.35, 1.0)
const COLOR_AVAILABLE := Color(0.22, 0.28, 0.22, 1.0)
const COLOR_LOCKED := Color(0.18, 0.18, 0.18, 1.0)

@onready var tier_columns: Array = [
	$Layout/ScrollContainer/HBox/Tier1,
	$Layout/ScrollContainer/HBox/Tier2,
	$Layout/ScrollContainer/HBox/Tier3,
	$Layout/ScrollContainer/HBox/Tier4,
]
@onready var status_label: Label = $Layout/StatusBar/StatusLabel
@onready var scrap_label: Label = $Layout/StatusBar/ScrapLabel

var _pending_build_item_id: String = ""


func _ready() -> void:
	TechManager.item_built.connect(_on_item_built)
	TechManager.tier_unlocked.connect(_on_tier_unlocked)
	_refresh_all()


func _refresh_all() -> void:
	scrap_label.text = "Scrap: %d" % GameState.inventory.get("scrap", 0)
	for tier_index in range(4):
		_refresh_tier_column(tier_index + 1)


func _refresh_tier_column(tier: int) -> void:
	var column: VBoxContainer = tier_columns[tier - 1]

	# Clear existing item panels (keep the header nodes).
	var items_container: VBoxContainer = column.get_node("ItemsContainer")
	for child in items_container.get_children():
		child.queue_free()

	var items: Array = TechManager.get_all_items_for_tier(tier)
	for item in items:
		var panel := _build_item_panel(item)
		items_container.add_child(panel)


func _build_item_panel(item: Dictionary) -> PanelContainer:
	var item_id: String = item["id"]
	var built: bool = TechManager.is_built(item_id)
	var check: Dictionary = TechManager.can_build(item_id)

	var panel := PanelContainer.new()
	panel.name = "Item_" + item_id

	var style := StyleBoxFlat.new()
	if built:
		style.bg_color = COLOR_BUILT
	elif check["ok"]:
		style.bg_color = COLOR_AVAILABLE
	else:
		style.bg_color = COLOR_LOCKED
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Item name.
	var name_label := Label.new()
	name_label.text = item.get("name", item_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Description.
	var desc_label := Label.new()
	desc_label.text = item.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	if built:
		var built_label := Label.new()
		built_label.text = "[Built]"
		built_label.add_theme_font_size_override("font_size", 12)
		built_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))
		vbox.add_child(built_label)
	else:
		# Show missing prerequisites by name.
		for prereq_id in check.get("missing_prerequisites", []):
			var prereq_label := Label.new()
			var display_name := _prereq_display_name(prereq_id)
			prereq_label.text = "Needs: " + display_name
			prereq_label.add_theme_font_size_override("font_size", 11)
			prereq_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4, 1.0))
			prereq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(prereq_label)

		# Show missing companion relationships by name.
		for companion_id in check.get("missing_companions", []):
			var companion_data: Dictionary = DataManager.get_companion(companion_id)
			var companion_name: String = companion_data.get("name", companion_id.capitalize())
			var required_rel: int = item.get("companion_requirements", {}).get(companion_id, 0)
			var rel_label := Label.new()
			rel_label.text = "Requires " + companion_name
			rel_label.add_theme_font_size_override("font_size", 11)
			rel_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.85, 1.0))
			rel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(rel_label)

		# Cost and build button — only show if not hard-locked on prerequisites.
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 8)
		vbox.add_child(cost_row)

		var cost_label := Label.new()
		var cost_scrap: int = item.get("cost_scrap", 0)
		cost_label.text = "%d scrap" % cost_scrap
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_row.add_child(cost_label)

		var build_btn := Button.new()
		build_btn.text = "Build"
		build_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_btn.disabled = not check["ok"]
		build_btn.pressed.connect(_on_build_pressed.bind(item_id))
		cost_row.add_child(build_btn)


	return panel


func _prereq_display_name(prereq_id: String) -> String:
	# Tier completion flags.
	if prereq_id == "tier_1_complete":
		return "all Tier 1 items"
	if prereq_id == "tier_2_complete":
		return "all Tier 2 items"
	if prereq_id == "tier_3_complete":
		return "all Tier 3 items"

	# Strip "built_" prefix then look up name in tech tree data.
	var lookup_id := prereq_id
	if lookup_id.begins_with("built_"):
		lookup_id = lookup_id.substr(6)

	var item: Dictionary = TechManager._tech_tree.get(lookup_id, {})
	if not item.is_empty():
		return item.get("name", lookup_id)

	return prereq_id.replace("_", " ").capitalize()


func _on_build_pressed(item_id: String) -> void:
	var item: Dictionary = TechManager._tech_tree.get(item_id, {})
	if item.is_empty():
		return

	var cost: int = item.get("cost_scrap", 0)
	var have: int = GameState.inventory.get("scrap", 0)

	if cost > 0:
		# Open confirmation dialog.
		# add_child first so @onready nodes are resolved before setup() runs.
		_pending_build_item_id = item_id
		var dialog: Window = preload("res://scenes/tech/build_confirm.tscn").instantiate()
		dialog.confirmed.connect(_on_build_confirmed)
		dialog.cancelled.connect(_on_build_cancelled)
		add_child(dialog)
		dialog.setup(item.get("name", item_id), cost, have)
		dialog.popup_centered()
	else:
		_execute_build(item_id)


func _on_build_confirmed() -> void:
	if _pending_build_item_id != "":
		_execute_build(_pending_build_item_id)
	_pending_build_item_id = ""


func _on_build_cancelled() -> void:
	_pending_build_item_id = ""


func _execute_build(item_id: String) -> void:
	var success := TechManager.build(item_id)
	if success:
		var item: Dictionary = TechManager._tech_tree.get(item_id, {})
		_show_status("Built: " + item.get("name", item_id))


func _show_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = message
	# Clear after a few seconds using a one-shot timer.
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func(): if status_label: status_label.text = "")


func _on_item_built(_item_id: String) -> void:
	_refresh_all()


func _on_tier_unlocked(_tier: int) -> void:
	_refresh_all()
