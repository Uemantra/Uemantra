extends Node2D

const PLOT_IDS: Array[String] = ["plot_0", "plot_1", "plot_2", "plot_3", "plot_4", "plot_5"]

# ColorRect color per growth stage so the state is legible without art.
const STAGE_COLORS: Array[Color] = [
	Color(0.25, 0.18, 0.12),  # empty — dark soil
	Color(0.35, 0.52, 0.22),  # seedling — pale green
	Color(0.22, 0.62, 0.25),  # growing — mid green
	Color(0.88, 0.74, 0.18),  # ready — golden
]

var _plot_nodes: Dictionary = {}


func _ready() -> void:
	_ensure_plots()
	_build_plot_ui()

	FarmingManager.plot_watered.connect(_on_plot_watered)
	FarmingManager.plot_harvested.connect(_on_plot_harvested)
	FarmingManager.growth_advanced.connect(_on_growth_advanced)
	GameState.state_changed.connect(_refresh_all)

	_refresh_all()


func _ensure_plots() -> void:
	# Seed GameState with empty plots on first visit so plots always exist.
	for plot_id in PLOT_IDS:
		if not GameState.farm_plots.has(plot_id):
			GameState.farm_plots[plot_id] = {
				"crop_id": "",
				"growth_stage": 0,
				"days_since_watered": 0,
				"planted_day": 0,
			}


func _build_plot_ui() -> void:
	var grid: GridContainer = $PlotGrid
	for plot_id in PLOT_IDS:
		var container := VBoxContainer.new()
		container.name = plot_id

		var rect := ColorRect.new()
		rect.name = "Rect"
		rect.custom_minimum_size = Vector2(100, 80)
		rect.color = STAGE_COLORS[0]
		container.add_child(rect)

		var label := Label.new()
		label.name = "Label"
		label.text = plot_id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(label)

		var btn := Button.new()
		btn.name = "ActionBtn"
		btn.text = "Plant"
		# Capture plot_id in closure via a bound callable.
		btn.pressed.connect(_on_plot_button_pressed.bind(plot_id))
		container.add_child(btn)

		grid.add_child(container)
		_plot_nodes[plot_id] = container


func _refresh_all() -> void:
	for plot_id in _plot_nodes:
		_refresh_plot(plot_id)


func _refresh_plot(plot_id: String) -> void:
	if not _plot_nodes.has(plot_id):
		return
	var container: VBoxContainer = _plot_nodes[plot_id]
	var plot: Dictionary = GameState.farm_plots.get(plot_id, {})
	var stage: int = plot.get("growth_stage", 0)
	var crop_id: String = plot.get("crop_id", "")
	var dsw: int = plot.get("days_since_watered", 0)

	container.get_node("Rect").color = STAGE_COLORS[stage]

	var label_text: String
	match stage:
		0:
			label_text = "[empty]"
		1:
			label_text = "%s\nseedling\n+%dd" % [crop_id, dsw]
		2:
			label_text = "%s\ngrowing\n+%dd" % [crop_id, dsw]
		3:
			label_text = "%s\nREADY" % crop_id
	container.get_node("Label").text = label_text

	var btn: Button = container.get_node("ActionBtn")
	match stage:
		0:
			btn.text = "Plant"
			btn.disabled = false
		1, 2:
			btn.text = "Water"
			btn.disabled = false
		3:
			btn.text = "Harvest"
			btn.disabled = false


func _on_plot_button_pressed(plot_id: String) -> void:
	var plot: Dictionary = GameState.farm_plots.get(plot_id, {})
	var stage: int = plot.get("growth_stage", 0)
	match stage:
		0:
			# Pick the first available crop for now — a crop selection UI is a later pass.
			FarmingManager.plant(plot_id, "potato")
		1, 2:
			FarmingManager.water(plot_id)
		3:
			var amount: int = FarmingManager.harvest(plot_id)
			print("[Farm] Harvested %s: %d" % [plot_id, amount])


func _on_plot_watered(plot_id: String) -> void:
	_refresh_plot(plot_id)


func _on_plot_harvested(plot_id: String, _yield_amount: int) -> void:
	_refresh_plot(plot_id)


func _on_growth_advanced(plot_id: String, _new_stage: int) -> void:
	_refresh_plot(plot_id)
