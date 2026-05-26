extends Control

@onready var zones_container: VBoxContainer = $VBox/ZonesList
@onready var back_button: Button = $VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_zones()


func _populate_zones() -> void:
	for child in zones_container.get_children():
		child.queue_free()

	var player_tier: int = GameState.tech_tier
	for zone_id in DataManager.zones_data:
		var zone: Dictionary = DataManager.zones_data[zone_id]
		if player_tier < zone.get("tier_required", 1):
			continue
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = zone.get("name", zone_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = zone.get("description", "")
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc_label)
		var btn := Button.new()
		btn.text = "Reach"
		var visited: bool = GameState.zones.get(zone_id, {}).get("visited", false)
		if visited:
			btn.text = "Return"
		btn.pressed.connect(_on_zone_selected.bind(zone_id))
		row.add_child(btn)
		zones_container.add_child(row)


func _on_zone_selected(zone_id: String) -> void:
	ExpeditionManager.start_expedition(zone_id)
	get_tree().change_scene_to_file("res://scenes/expedition/expedition.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
