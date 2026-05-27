extends PanelContainer

@onready var _close_btn: Button = $Contents/TitleRow/CloseBtn
@onready var _name_label: Label = $Contents/NameLabel
@onready var _hp_label: Label = $Contents/HpApRow/HpLabel
@onready var _ap_label: Label = $Contents/HpApRow/ApLabel
@onready var _caps_label: Label = $Contents/HpApRow/CapsLabel
@onready var _stats_column: VBoxContainer = $Contents/ColumnsRow/StatsColumn
@onready var _skills_column: VBoxContainer = $Contents/ColumnsRow/SkillsColumn
@onready var _skills_header: Label = $Contents/ColumnsRow/SkillsColumn/SkillsHeader
@onready var _xp_label: Label = $Contents/XpLabel

const STAT_NAMES := ["grit", "reflex", "mind", "body", "nerve", "presence"]
const STAT_DISPLAY := {
	"grit": "Grit",
	"reflex": "Reflex",
	"mind": "Mind",
	"body": "Body",
	"nerve": "Nerve",
	"presence": "Presence",
}
const SKILL_DISPLAY := {
	"guns": "Guns",
	"melee": "Melee",
	"speech": "Speech",
	"intimidate": "Intimidate",
	"barter": "Barter",
	"medicine": "Medicine",
	"lockpick": "Lockpick",
	"tech": "Tech",
	"stealth": "Stealth",
}


func _ready() -> void:
	_close_btn.pressed.connect(queue_free)
	_refresh()


func _refresh() -> void:
	_name_label.text = GameState.player_name
	var max_hp: int = GameState.derived.get("max_hp", 20)
	_hp_label.text = "HP: %d / %d" % [GameState.hp, max_hp]
	_ap_label.text = "AP / turn: %d" % GameState.derived.get("max_ap", 5)
	_caps_label.text = "Caps: %d" % GameState.caps
	_xp_label.text = "Level %d — XP: %d" % [GameState.level, GameState.xp]
	_skills_header.text = "SKILLS   (Pts to spend: %d)" % GameState.skill_points

	# Stats
	for child in _stats_column.get_children():
		if child.name != "StatsHeader":
			child.queue_free()
	for stat_id in STAT_NAMES:
		var val: int = GameState.stats.get(stat_id, 5)
		var lbl := Label.new()
		lbl.text = "%-12s %d" % [STAT_DISPLAY.get(stat_id, stat_id), val]
		lbl.theme_override_font_sizes = {"font_size": 14}
		_stats_column.add_child(lbl)

	# Skills
	for child in _skills_column.get_children():
		if child.name != "SkillsHeader":
			child.queue_free()
	for skill_id in SKILL_DISPLAY:
		var val: int = GameState.skills.get(skill_id, 0)
		var invested: int = GameState.skill_investments.get(skill_id, 0)
		var row := HBoxContainer.new()
		row.theme_override_constants = {"separation": 8}

		var name_lbl := Label.new()
		name_lbl.text = "%-14s %d" % [SKILL_DISPLAY.get(skill_id, skill_id), val]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.theme_override_font_sizes = {"font_size": 13}
		row.add_child(name_lbl)

		if GameState.skill_points > 0:
			var invest_btn := Button.new()
			invest_btn.text = "+"
			invest_btn.custom_minimum_size = Vector2(28, 28)
			invest_btn.pressed.connect(_on_invest.bind(skill_id))
			row.add_child(invest_btn)

		if invested > 0:
			var divest_btn := Button.new()
			divest_btn.text = "-"
			divest_btn.custom_minimum_size = Vector2(28, 28)
			divest_btn.pressed.connect(_on_divest.bind(skill_id))
			row.add_child(divest_btn)

		_skills_column.add_child(row)


func _on_invest(skill_id: String) -> void:
	if GameState.skill_points <= 0:
		return
	GameState.skill_investments[skill_id] = GameState.skill_investments.get(skill_id, 0) + 1
	GameState.skill_points -= 1
	GameState.recalculate_derived()
	GameState.state_changed.emit()
	_refresh()


func _on_divest(skill_id: String) -> void:
	var current: int = GameState.skill_investments.get(skill_id, 0)
	if current <= 0:
		return
	GameState.skill_investments[skill_id] = current - 1
	GameState.skill_points += 1
	GameState.recalculate_derived()
	GameState.state_changed.emit()
	_refresh()
