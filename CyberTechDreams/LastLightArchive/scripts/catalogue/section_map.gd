extends Control

@onready var map_container: VBoxContainer = $ScrollContainer/MapContainer

# Beige-ish tones for the hand-drawn map aesthetic.
const COLOR_VISITED := Color(0.35, 0.3, 0.25)
const COLOR_UNVISITED := Color(0.65, 0.6, 0.55)
const COLOR_ZONE_BG_VISITED := Color(0.88, 0.84, 0.74, 1.0)
const COLOR_ZONE_BG_UNVISITED := Color(0.82, 0.79, 0.72, 0.6)


func _ready() -> void:
	refresh()


func set_catalogue(_catalogue: Control) -> void:
	pass


func refresh() -> void:
	_clear_map()
	var zone_ids := DataManager.zones_data.keys()
	if zone_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nothing charted yet."
		empty_label.add_theme_color_override("font_color", COLOR_UNVISITED)
		map_container.add_child(empty_label)
		return
	for zone_id in zone_ids:
		_add_zone_block(zone_id)


func _add_zone_block(zone_id: String) -> void:
	var zone_authored := DataManager.get_zone(zone_id)
	var zone_runtime: Dictionary = GameState.zones.get(zone_id, {})
	var visited: bool = zone_runtime.get("visited", false)
	var locations_explored: Array = zone_runtime.get("locations_explored", [])

	var zone_name: String = zone_authored.get("name", zone_id)

	var zone_panel := PanelContainer.new()
	zone_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_ZONE_BG_VISITED if visited else COLOR_ZONE_BG_UNVISITED
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.6, 0.55, 0.45)
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 8
	zone_panel.add_theme_stylebox_override("panel", panel_style)

	var zone_vbox := VBoxContainer.new()
	zone_vbox.add_theme_constant_override("separation", 4)
	zone_panel.add_child(zone_vbox)

	var zone_label := Label.new()
	zone_label.text = zone_name if visited else "???"
	zone_label.add_theme_font_size_override("font_size", 15)
	zone_label.add_theme_color_override("font_color", COLOR_VISITED if visited else COLOR_UNVISITED)
	zone_vbox.add_child(zone_label)

	if visited:
		var locations: Dictionary = zone_authored.get("locations", {})
		for loc_id in locations:
			var loc_data: Dictionary = locations[loc_id]
			var loc_explored: bool = loc_id in locations_explored
			var loc_label := Label.new()
			var loc_name: String = loc_data.get("name", loc_id)
			loc_label.text = "    " + (loc_name if loc_explored else "???")
			loc_label.add_theme_font_size_override("font_size", 13)
			loc_label.add_theme_color_override(
				"font_color",
				COLOR_VISITED if loc_explored else COLOR_UNVISITED
			)
			zone_vbox.add_child(loc_label)

	map_container.add_child(zone_panel)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	map_container.add_child(spacer)


func _clear_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
