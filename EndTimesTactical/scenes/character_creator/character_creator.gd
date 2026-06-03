extends Control

const STAT_NAMES  := ["grit", "reflex", "mind", "body", "nerve", "presence"]
const STAT_LABELS := {
	"grit":     "Grit     (endurance, melee HP bonus)",
	"reflex":   "Reflex   (AP pool, guns, evasion)",
	"mind":     "Mind     (lockpick, tech, medicine)",
	"body":     "Body     (HP pool, carry weight)",
	"nerve":    "Nerve    (intimidate, initiative)",
	"presence": "Presence (speech, barter)",
}
const SKILL_NAMES := ["guns", "melee", "speech", "intimidate", "barter",
					  "medicine", "lockpick", "tech", "stealth"]
const STAT_MIN    := 1
const STAT_MAX    := 10
const TOTAL_POINTS := 40   # 6×5 baseline = 30; player distributes 10 extra
const TAG_COUNT   := 3
const TAG_BONUS   := 20
const TRAIT_MAX   := 2     # optional: pick 0–2 traits at creation

var _stat_values: Dictionary = {}       # stat_id -> int
var _tagged_skills: Array    = []       # up to TAG_COUNT skill_ids
var _selected_traits: Array  = []       # up to TRAIT_MAX trait ids
var _stat_val_labels: Dictionary = {}   # stat_id -> Label showing number
var _skill_btns: Dictionary  = {}       # skill_id -> Button
var _trait_btns: Dictionary  = {}       # trait_id -> CheckButton

@onready var _name_edit:     LineEdit      = $BG/MainPanel/VBox/NameRow/NameEdit
@onready var _points_label:  Label         = $BG/MainPanel/VBox/ContentRow/StatsSection/PointsLabel
@onready var _stats_list:    VBoxContainer = $BG/MainPanel/VBox/ContentRow/StatsSection/StatsList
@onready var _skills_list:   VBoxContainer = $BG/MainPanel/VBox/ContentRow/SkillsSection/SkillsList
@onready var _summary_box:   VBoxContainer = $BG/MainPanel/VBox/ContentRow/SummarySection/SummaryBox
@onready var _status_label:  Label         = $BG/MainPanel/VBox/BottomRow/StatusLabel
@onready var _confirm_btn:   Button        = $BG/MainPanel/VBox/BottomRow/ConfirmBtn
@onready var _rand_btn:      Button        = $BG/MainPanel/VBox/BottomRow/RandBtn


func _ready() -> void:
	_reset_stats()
	_build_stats_ui()
	_build_skills_ui()
	_build_traits_ui()
	_refresh_summary()
	_validate()
	_name_edit.text_changed.connect(func(_t): _validate())
	_confirm_btn.pressed.connect(_on_confirm)
	_rand_btn.pressed.connect(_on_randomize)


func _reset_stats() -> void:
	for s: String in STAT_NAMES:
		_stat_values[s] = 5
	_tagged_skills.clear()


func _points_used() -> int:
	var total := 0
	for s: String in STAT_NAMES:
		total += _stat_values.get(s, 5)
	return total


func _points_remaining() -> int:
	return TOTAL_POINTS - _points_used()


func _build_stats_ui() -> void:
	for s: String in STAT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_lbl := Label.new()
		name_lbl.text = STAT_LABELS.get(s, s).split("(")[0].strip_edges()
		name_lbl.custom_minimum_size = Vector2(80, 0)
		name_lbl.add_theme_font_size_override("font_size", 17)
		row.add_child(name_lbl)

		var minus_btn := Button.new()
		minus_btn.text = "–"
		minus_btn.custom_minimum_size = Vector2(24, 24)
		minus_btn.add_theme_font_size_override("font_size", 20)
		minus_btn.pressed.connect(_on_stat_change.bind(s, -1))
		row.add_child(minus_btn)

		var val_lbl := Label.new()
		val_lbl.text = str(_stat_values[s])
		val_lbl.custom_minimum_size = Vector2(22, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 18)
		_stat_val_labels[s] = val_lbl
		row.add_child(val_lbl)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(24, 24)
		plus_btn.add_theme_font_size_override("font_size", 20)
		plus_btn.pressed.connect(_on_stat_change.bind(s, 1))
		row.add_child(plus_btn)

		var desc_lbl := Label.new()
		desc_lbl.text = "(%s)" % STAT_LABELS.get(s, "").split("(")[-1].rstrip(")")
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.40))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_lbl)

		_stats_list.add_child(row)


func _build_skills_ui() -> void:
	for sk: String in SKILL_NAMES:
		var btn := CheckButton.new()
		btn.text = sk.capitalize()
		btn.add_theme_font_size_override("font_size", 17)
		btn.toggled.connect(_on_skill_toggle.bind(sk))
		_skill_btns[sk] = btn
		_skills_list.add_child(btn)


func _build_traits_ui() -> void:
	var sep := HSeparator.new()
	_skills_list.add_child(sep)
	var hdr := Label.new()
	hdr.text = "TRAITS  (optional, pick up to %d)" % TRAIT_MAX
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(0.6, 0.57, 0.42))
	_skills_list.add_child(hdr)

	for trait_data: Dictionary in DataManager.get_all_traits():
		var tid: String = trait_data.get("id", "")
		var btn := CheckButton.new()
		btn.text = trait_data.get("name", tid)
		btn.tooltip_text = trait_data.get("description", "")
		btn.add_theme_font_size_override("font_size", 16)
		btn.toggled.connect(_on_trait_toggle.bind(tid))
		_trait_btns[tid] = btn
		_skills_list.add_child(btn)


func _on_trait_toggle(toggled_on: bool, trait_id: String) -> void:
	if toggled_on:
		if trait_id not in _selected_traits:
			if _selected_traits.size() >= TRAIT_MAX:
				_trait_btns[trait_id].set_pressed_no_signal(false)
				return
			_selected_traits.append(trait_id)
	else:
		_selected_traits.erase(trait_id)
	_refresh_summary()


func _on_stat_change(stat_id: String, delta: int) -> void:
	var cur: int = _stat_values.get(stat_id, 5)
	var new_val: int = cur + delta
	if new_val < STAT_MIN or new_val > STAT_MAX:
		return
	if delta > 0 and _points_remaining() <= 0:
		return
	_stat_values[stat_id] = new_val
	_stat_val_labels[stat_id].text = str(new_val)
	_points_label.text = "Points remaining: %d" % _points_remaining()
	_refresh_summary()
	_validate()


func _on_skill_toggle(toggled_on: bool, skill_id: String) -> void:
	if toggled_on:
		if skill_id not in _tagged_skills:
			if _tagged_skills.size() >= TAG_COUNT:
				# Undo the toggle — cap reached
				_skill_btns[skill_id].set_pressed_no_signal(false)
				return
			_tagged_skills.append(skill_id)
	else:
		_tagged_skills.erase(skill_id)
	_refresh_summary()
	_validate()


func _refresh_summary() -> void:
	for child in _summary_box.get_children():
		child.queue_free()

	var body:   int = _stat_values.get("body",   5) as int
	var grit:   int = _stat_values.get("grit",   5) as int
	var reflex: int = _stat_values.get("reflex", 5) as int
	var hp:     int = 20 + body * 4 + grit * 2
	var ap:     int = 4  + reflex
	var cw:     int = 30 + body * 5
	var evad:   int = reflex * 2

	var lines := [
		["Max HP",       str(hp)],
		["Max AP",       str(ap)],
		["Carry Weight", str(cw) + " kg"],
		["Evasion",      str(evad)],
	]

	for line: Array in lines:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.text = line[0]
		k.custom_minimum_size = Vector2(110, 0)
		k.add_theme_font_size_override("font_size", 16)
		k.add_theme_color_override("font_color", Color(0.6, 0.57, 0.42))
		row.add_child(k)
		var v := Label.new()
		v.text = line[1]
		v.add_theme_font_size_override("font_size", 16)
		row.add_child(v)
		_summary_box.add_child(row)

	if not _tagged_skills.is_empty():
		var sep := HSeparator.new()
		_summary_box.add_child(sep)
		var tag_lbl := Label.new()
		tag_lbl.text = "Tagged skills (+%d):" % TAG_BONUS
		tag_lbl.add_theme_font_size_override("font_size", 16)
		tag_lbl.add_theme_color_override("font_color", Color(0.6, 0.57, 0.42))
		_summary_box.add_child(tag_lbl)
		for sk: String in _tagged_skills:
			var sl := Label.new()
			sl.text = "  • %s" % sk.capitalize()
			sl.add_theme_font_size_override("font_size", 16)
			_summary_box.add_child(sl)

	if not _selected_traits.is_empty():
		var tsep := HSeparator.new()
		_summary_box.add_child(tsep)
		var thdr := Label.new()
		thdr.text = "Traits:"
		thdr.add_theme_font_size_override("font_size", 16)
		thdr.add_theme_color_override("font_color", Color(0.6, 0.57, 0.42))
		_summary_box.add_child(thdr)
		for tid: String in _selected_traits:
			var tl := Label.new()
			tl.text = "  • %s" % DataManager.get_trait(tid).get("name", tid)
			tl.add_theme_font_size_override("font_size", 16)
			_summary_box.add_child(tl)


func _validate() -> bool:
	var name_ok: bool = _name_edit.text.strip_edges().length() > 0
	var tags_ok: bool = _tagged_skills.size() == TAG_COUNT
	var ok := name_ok and tags_ok
	_confirm_btn.disabled = not ok
	if not name_ok:
		_status_label.text = "Enter a name."
	elif not tags_ok:
		_status_label.text = "Tag exactly %d skills." % TAG_COUNT
	else:
		_status_label.text = ""
	return ok


func _on_confirm() -> void:
	if not _validate():
		return
	GameState.new_game()
	GameState.player_name  = _name_edit.text.strip_edges()
	for s: String in STAT_NAMES:
		GameState.stats[s] = _stat_values[s]
	GameState.tagged_skills = _tagged_skills.duplicate()
	GameState.traits = _selected_traits.duplicate()
	GameState.recalculate_derived()
	GameState.hp = GameState.derived.get("max_hp", 20)
	QuestManager.start_quest("main_quest_the_signal")
	get_tree().change_scene_to_file("res://scenes/world/local_map.tscn")


func _on_randomize() -> void:
	# Distribute TOTAL_POINTS randomly, min 1 / max 10 per stat
	var remaining := TOTAL_POINTS
	for s: String in STAT_NAMES:
		_stat_values[s] = STAT_MIN
		remaining -= STAT_MIN
	# Randomly add remaining points
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(remaining):
		var available: Array = STAT_NAMES.filter(func(s): return _stat_values[s] < STAT_MAX)
		if available.is_empty():
			break
		var target: String = available[rng.randi() % available.size()]
		_stat_values[target] += 1
	# Random skill tags
	_tagged_skills.clear()
	var shuffled := SKILL_NAMES.duplicate()
	shuffled.shuffle()
	_tagged_skills = shuffled.slice(0, TAG_COUNT)
	# Randomize clears any chosen traits (player can re-pick deliberately)
	_selected_traits.clear()
	for tid: String in _trait_btns:
		_trait_btns[tid].set_pressed_no_signal(false)
	# Update UI
	for s: String in STAT_NAMES:
		_stat_val_labels[s].text = str(_stat_values[s])
	for sk: String in SKILL_NAMES:
		_skill_btns[sk].set_pressed_no_signal(sk in _tagged_skills)
	_points_label.text = "Points remaining: %d" % _points_remaining()
	_refresh_summary()
	_validate()
