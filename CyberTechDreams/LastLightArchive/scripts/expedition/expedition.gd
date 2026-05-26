extends Control

const HazardSystem = preload("res://scripts/systems/HazardSystem.gd")

@onready var zone_name_label: Label = $VBox/ZoneNameLabel
@onready var location_name_label: Label = $VBox/LocationNameLabel
@onready var location_desc_label: RichTextLabel = $VBox/LocationDescLabel
@onready var hazard_label: Label = $VBox/HazardLabel
@onready var carry_label: Label = $VBox/CarryLabel
@onready var connections_container: VBoxContainer = $VBox/ConnectionsSection/ConnectionsList
@onready var artifacts_container: VBoxContainer = $VBox/ArtifactsSection/ArtifactsList
@onready var pickup_message_label: Label = $VBox/PickupMessage
@onready var field_note_label: RichTextLabel = $VBox/CacheFieldNote
@onready var return_button: Button = $VBox/ReturnButton

var _hazard_system: HazardSystem
var _pickup_timer: SceneTreeTimer = null
var _field_note_timer: SceneTreeTimer = null

# Tracks which artifact ids at the current location have been picked up this visit.
var _picked_up_ids: Array = []


func _ready() -> void:
	_hazard_system = HazardSystem.new()
	ExpeditionManager.location_entered.connect(_on_location_entered)
	ExpeditionManager.carry_weight_changed.connect(_on_carry_weight_changed)
	ExpeditionManager.expedition_ended.connect(_on_expedition_ended)
	ExpeditionManager.cache_discovered.connect(_on_cache_discovered)
	pickup_message_label.visible = false
	field_note_label.visible = false
	hazard_label.visible = false
	var zone_data := DataManager.get_zone(ExpeditionManager.current_zone_id)
	zone_name_label.text = zone_data.get("name", "")
	_update_carry_label(ExpeditionManager.carry_weight_current, ExpeditionManager.carry_weight_max)
	location_name_label.text = "—"
	location_desc_label.text = zone_data.get("description", "")
	return_button.pressed.connect(_on_return_pressed)
	_populate_connections_from_zone(zone_data)


func _populate_connections_from_zone(zone_data: Dictionary) -> void:
	_clear_container(connections_container)
	var locations: Dictionary = zone_data.get("locations", {})
	for loc_id in locations:
		var loc_data: Dictionary = locations[loc_id]
		var btn := Button.new()
		btn.text = loc_data.get("name", loc_id)
		btn.pressed.connect(_on_travel_pressed.bind(loc_id))
		connections_container.add_child(btn)


func _on_location_entered(location_id: String) -> void:
	_picked_up_ids.clear()
	var location_data := ExpeditionManager.get_current_location_data()
	location_name_label.text = location_data.get("name", location_id)
	location_desc_label.text = location_data.get("description", "")
	var player_has_light: bool = GameState.get_flag("has_light_source", false)
	var hazard_result := _hazard_system.evaluate(location_data, player_has_light, GameState.tech_tier)
	if hazard_result["hazard_type"] != "":
		hazard_label.text = hazard_result["description"]
		hazard_label.visible = true
	else:
		hazard_label.visible = false
	_populate_connections(location_data)
	if hazard_result["blocked"]:
		_clear_container(artifacts_container)
	else:
		_populate_artifacts(location_data)


func _populate_connections(location_data: Dictionary) -> void:
	_clear_container(connections_container)
	var connections: Array = location_data.get("connections", [])
	var zone_data := DataManager.get_zone(ExpeditionManager.current_zone_id)
	var locations: Dictionary = zone_data.get("locations", {})
	for loc_id in connections:
		var dest_data: Dictionary = locations.get(loc_id, {})
		var btn := Button.new()
		btn.text = dest_data.get("name", loc_id)
		btn.pressed.connect(_on_travel_pressed.bind(loc_id))
		connections_container.add_child(btn)


func _populate_artifacts(location_data: Dictionary) -> void:
	_clear_container(artifacts_container)
	var artifacts: Array = location_data.get("artifacts", [])
	for artifact in artifacts:
		var a_id: String = artifact.get("id", "")
		var a_type: String = artifact.get("type", "")
		var already_have := false
		match a_type:
			"scrap":
				pass
			"relic":
				already_have = a_id in GameState.inventory["relics"]
			"echo":
				already_have = a_id in GameState.inventory["echoes"]
			"cache":
				already_have = a_id in GameState.inventory["caches"]
		if already_have or a_id in _picked_up_ids:
			continue
		var row := HBoxContainer.new()
		var desc_label := Label.new()
		desc_label.text = artifact.get("description", a_id)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)
		var btn := Button.new()
		if a_type == "cache":
			btn.text = "Lift"
		else:
			btn.text = "Take"
		btn.pressed.connect(_on_pickup_pressed.bind(artifact))
		row.add_child(btn)
		artifacts_container.add_child(row)


func _on_travel_pressed(location_id: String) -> void:
	ExpeditionManager.enter_location(location_id)


func _on_pickup_pressed(artifact: Dictionary) -> void:
	var a_type: String = artifact.get("type", "")
	var a_id: String = artifact.get("id", "")
	var weight: float = artifact.get("weight", 1.0)
	if a_type == "cache":
		ExpeditionManager.discover_cache(a_id)
		_picked_up_ids.append(a_id)
		_refresh_artifacts()
		return
	var success := ExpeditionManager.try_pickup_artifact(a_type, a_id, weight)
	if success:
		_picked_up_ids.append(a_id)
		_show_pickup_message(_pickup_text(a_type, artifact))
		_refresh_artifacts()
	else:
		_show_pickup_message("Too heavy. Leave something behind.")


func _pickup_text(artifact_type: String, artifact: Dictionary) -> String:
	match artifact_type:
		"scrap":
			return "Scrap collected."
		"relic":
			return artifact.get("description", "Relic collected.")
		"echo":
			return artifact.get("description", "Echo collected.")
	return "Collected."


func _refresh_artifacts() -> void:
	var location_data := ExpeditionManager.get_current_location_data()
	_populate_artifacts(location_data)


func _show_pickup_message(msg: String) -> void:
	pickup_message_label.text = msg
	pickup_message_label.visible = true
	if _pickup_timer != null:
		_pickup_timer = null
	_pickup_timer = get_tree().create_timer(3.0)
	_pickup_timer.timeout.connect(func(): pickup_message_label.visible = false)


func _on_carry_weight_changed(current: float, max_weight: float) -> void:
	_update_carry_label(current, max_weight)


func _update_carry_label(current: float, max_weight: float) -> void:
	carry_label.text = "Pack: %.1f / %.1f kg" % [current, max_weight]


func _on_expedition_ended() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_return_pressed() -> void:
	ExpeditionManager.end_expedition()


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_cache_discovered(cache_id: String, field_note: String) -> void:
	field_note_label.text = "[i]" + field_note + "[/i]"
	field_note_label.visible = true
	if _field_note_timer != null:
		_field_note_timer = null
	_field_note_timer = get_tree().create_timer(6.0)
	_field_note_timer.timeout.connect(func(): field_note_label.visible = false)

