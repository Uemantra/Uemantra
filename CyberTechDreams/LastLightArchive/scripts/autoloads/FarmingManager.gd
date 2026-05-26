extends Node

signal plot_watered(plot_id: String)
signal plot_harvested(plot_id: String, yield_amount: int)
signal growth_advanced(plot_id: String, new_stage: int)

const STAGE_EMPTY: int = 0
const STAGE_SEEDLING: int = 1
const STAGE_GROWING: int = 2
const STAGE_READY: int = 3

var _crops: Dictionary = {}


func _ready() -> void:
	_crops = DataManager.crops
	TimeManager.day_changed.connect(_on_day_changed)


func plant(plot_id: String, crop_id: String) -> void:
	if not _crops.has(crop_id):
		push_error("FarmingManager: unknown crop_id '%s'" % crop_id)
		return
	GameState.farm_plots[plot_id] = {
		"crop_id": crop_id,
		"growth_stage": STAGE_SEEDLING,
		"days_since_watered": 0,
		"planted_day": TimeManager.day,
	}
	GameState.state_changed.emit()


func water(plot_id: String) -> void:
	if not GameState.farm_plots.has(plot_id):
		return
	var plot: Dictionary = GameState.farm_plots[plot_id]
	if plot["growth_stage"] == STAGE_EMPTY:
		return
	plot["days_since_watered"] = 0
	GameState.state_changed.emit()
	plot_watered.emit(plot_id)


func harvest(plot_id: String) -> int:
	if not GameState.farm_plots.has(plot_id):
		return 0
	var plot: Dictionary = GameState.farm_plots[plot_id]
	if plot["growth_stage"] != STAGE_READY:
		return 0

	var crop: Dictionary = _crops.get(plot["crop_id"], {})
	var amount: int = randi_range(
		crop.get("yield_min", 1),
		crop.get("yield_max", 1)
	)

	# Reset the plot to empty after harvest.
	GameState.farm_plots[plot_id] = {
		"crop_id": "",
		"growth_stage": STAGE_EMPTY,
		"days_since_watered": 0,
		"planted_day": 0,
	}
	GameState.state_changed.emit()
	plot_harvested.emit(plot_id, amount)
	return amount


func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	for plot_id in GameState.farm_plots:
		var plot: Dictionary = GameState.farm_plots[plot_id]
		if plot["growth_stage"] == STAGE_EMPTY or plot["growth_stage"] == STAGE_READY:
			continue

		plot["days_since_watered"] += 1

		var crop: Dictionary = _crops.get(plot["crop_id"], {})
		var water_interval: int = crop.get("water_interval", 3)

		# Only advance growth when the plant has been watered recently enough.
		# Neglected crops pause — they never die.
		if plot["days_since_watered"] <= water_interval:
			plot["growth_stage"] = mini(plot["growth_stage"] + 1, STAGE_READY)
			GameState.state_changed.emit()
			growth_advanced.emit(plot_id, plot["growth_stage"])
