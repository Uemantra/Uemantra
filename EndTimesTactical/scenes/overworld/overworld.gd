extends Control

const NODE_RADIUS: float = 16.0
const NODE_COLOR_DEFAULT := Color(0.6, 0.55, 0.3, 1.0)
const NODE_COLOR_CURRENT := Color(0.9, 0.8, 0.3, 1.0)
const NODE_COLOR_LOCKED := Color(0.3, 0.3, 0.3, 0.5)

@onready var _map_layer: Node2D = $MapLayer
@onready var _location_label: Label = $TopBar/TopBarContents/LocationLabel
@onready var _time_label: Label = $TopBar/TopBarContents/TimeLabel
@onready var _travel_panel: PanelContainer = $TravelPanel
@onready var _travel_title: Label = $TravelPanel/TravelContents/TravelTitle
@onready var _travel_info: Label = $TravelPanel/TravelContents/TravelInfo
@onready var _confirm_btn: Button = $TravelPanel/TravelContents/TravelButtons/ConfirmBtn
@onready var _cancel_btn: Button = $TravelPanel/TravelContents/TravelButtons/CancelBtn

var _node_buttons: Dictionary = {}   # location_id -> Button
var _pending_destination: String = ""
var _pending_travel_hours: int = 0


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_travel_confirmed)
	_cancel_btn.pressed.connect(func(): _travel_panel.visible = false)
	GameState.state_changed.connect(_refresh_ui)
	_build_map()
	_refresh_ui()


func _build_map() -> void:
	var world := DataManager.get_world()
	var nodes: Array = world.get("nodes", [])
	for node_data in nodes:
		var node_id: String = node_data.get("id", "")
		var pos: Dictionary = node_data.get("position", {"x": 0, "y": 0})
		var btn := Button.new()
		btn.position = Vector2(pos["x"] - NODE_RADIUS, pos["y"] - NODE_RADIUS + 48)
		btn.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		btn.text = ""
		btn.tooltip_text = node_data.get("display_name", node_id)
		btn.pressed.connect(_on_node_clicked.bind(node_id))
		_map_layer.add_child(btn)
		_node_buttons[node_id] = btn

		var lbl := Label.new()
		lbl.text = node_data.get("display_name", node_id)
		lbl.position = Vector2(pos["x"] - 40, pos["y"] + NODE_RADIUS + 52)
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.theme_override_font_sizes = {"font_size": 11}
		_map_layer.add_child(lbl)

	_draw_connections(nodes)


func _draw_connections(nodes: Array) -> void:
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = Color(0.4, 0.35, 0.2, 0.6)
	_map_layer.add_child(line)
	var drawn: Dictionary = {}
	for node_data in nodes:
		var id: String = node_data.get("id", "")
		var pos_a := _get_node_pos(node_data)
		for conn in node_data.get("connections", []):
			var to_id: String = conn.get("to", "")
			var key := [id, to_id]
			key.sort()
			var key_str := str(key)
			if drawn.has(key_str):
				continue
			drawn[key_str] = true
			var to_node := _find_node_data(nodes, to_id)
			if to_node.is_empty():
				continue
			var pos_b := _get_node_pos(to_node)
			line.add_point(pos_a + Vector2(0, 48))
			line.add_point(pos_b + Vector2(0, 48))


func _refresh_ui() -> void:
	var current_id := GameState.current_location
	_location_label.text = "Location: %s" % DataManager.get_location(current_id).get("name", current_id)
	var hours := GameState.world_time_hours
	var day := hours / 24 + 1
	var hour_of_day := hours % 24
	_time_label.text = "Day %d — %02d:00" % [day, hour_of_day]

	var world := DataManager.get_world()
	var nodes: Array = world.get("nodes", [])
	for node_data in nodes:
		var node_id: String = node_data.get("id", "")
		if not _node_buttons.has(node_id):
			continue
		var btn: Button = _node_buttons[node_id]
		var unlock_flag = node_data.get("unlock_flag", null)
		var unlocked: bool = node_data.get("unlocked_by_default", false)
		if not unlocked and unlock_flag != null:
			unlocked = GameState.get_flag(unlock_flag)
		btn.disabled = (not unlocked) or (node_id == current_id)
		btn.modulate = NODE_COLOR_CURRENT if node_id == current_id else (NODE_COLOR_DEFAULT if unlocked else NODE_COLOR_LOCKED)


func _on_node_clicked(destination_id: String) -> void:
	if destination_id == GameState.current_location:
		return
	var loc := DataManager.get_location(GameState.current_location)
	var travel_hours: int = loc.get("travel_time_hours", {}).get(destination_id, 4)
	_pending_destination = destination_id
	_pending_travel_hours = travel_hours
	var dest_name := DataManager.get_location(destination_id).get("name", destination_id)
	_travel_title.text = "Travel to %s?" % dest_name
	_travel_info.text = "Approx. %d hours on foot" % travel_hours
	_travel_panel.visible = true


func _on_travel_confirmed() -> void:
	_travel_panel.visible = false
	if _pending_destination == "":
		return
	GameState.world_time_hours += _pending_travel_hours
	GameState.current_location = _pending_destination
	if _pending_destination not in GameState.visited_locations:
		GameState.visited_locations.append(_pending_destination)
	GameState.state_changed.emit()
	get_tree().change_scene_to_file("res://scenes/location/location.tscn")


func _get_node_pos(node_data: Dictionary) -> Vector2:
	var pos: Dictionary = node_data.get("position", {"x": 0, "y": 0})
	return Vector2(pos["x"], pos["y"])


func _find_node_data(nodes: Array, id: String) -> Dictionary:
	for n in nodes:
		if n.get("id", "") == id:
			return n
	return {}
