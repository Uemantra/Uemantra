extends PanelContainer

@onready var _close_btn: Button = $Contents/TitleRow/CloseBtn
@onready var _name_label: Label = $Contents/NameLabel
@onready var _hp_label: Label = $Contents/HpApRow/HpLabel
@onready var _ap_label: Label = $Contents/HpApRow/ApLabel
@onready var _caps_label: Label = $Contents/HpApRow/CapsLabel
@onready var _weapon_gear_lbl: Label         = $Contents/GearRow/WeaponGearLabel
@onready var _armor_gear_lbl:  Label         = $Contents/GearRow/ArmorGearLabel
@onready var _stats_column:    VBoxContainer = $Contents/ColumnsRow/StatsColumn
@onready var _skills_column:   VBoxContainer = $Contents/ColumnsRow/SkillsColumn
@onready var _skills_header:   Label         = $Contents/ColumnsRow/SkillsColumn/SkillsHeader
@onready var _xp_label:        Label         = $Contents/XpLabel

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
	_xp_label.text = "Level %d — XP: %d  (%d to next)" % [
		GameState.level, GameState.xp, GameState.xp_to_next_level()]
	_skills_header.text = "SKILLS   (Pts to spend: %d)" % GameState.skill_points

	# Equipped gear
	var weapon_text := "Weapon: —"
	var armor_text  := "Armor: —"
	for entry in GameState.inventory:
		if not entry.get("equipped", false):
			continue
		var item := DataManager.get_item(entry.get("item_id", ""))
		if item.is_empty():
			continue
		match item.get("type", ""):
			"weapon":
				var dice: String = item.get("damage_dice", "—")
				var bonus: int   = item.get("damage_bonus", 0)
				var rng: int     = item.get("range_tiles", 1)
				var ap: int      = item.get("ap_cost", 3)
				var dmg_str := "%s+%d" % [dice, bonus] if bonus > 0 else dice
				weapon_text = "Weapon: %s  %s  Rng %d  %dAP" % [item.get("name", "?"), dmg_str, rng, ap]
			"armor":
				var dr: int = item.get("defense_bonus", 0)
				armor_text = "Armor: %s  DR %d" % [item.get("name", "?"), dr]
	_weapon_gear_lbl.text = weapon_text
	_armor_gear_lbl.text  = armor_text

	# Stats
	for child in _stats_column.get_children():
		if child.name != "StatsHeader":
			child.queue_free()
	var stat_pts: int = GameState.stat_points_available
	if stat_pts > 0:
		var hint := Label.new()
		hint.text = "Stat points: %d" % stat_pts
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		_stats_column.add_child(hint)
	for stat_id in STAT_NAMES:
		var val: int = GameState.stats.get(stat_id, 5)
		var bonus: int = GameState.get_effective_stats().get(stat_id, val) - val
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		var bonus_str := "  (+%d)" % bonus if bonus > 0 else ""
		lbl.text = "%-12s %d%s" % [STAT_DISPLAY.get(stat_id, stat_id), val, bonus_str]
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if stat_pts > 0 and val < 10:
			var up_btn := Button.new()
			up_btn.text = "+"
			up_btn.custom_minimum_size = Vector2(28, 28)
			up_btn.pressed.connect(_on_raise_stat.bind(stat_id))
			row.add_child(up_btn)
		_stats_column.add_child(row)

	_refresh_perks()

	# Skills
	for child in _skills_column.get_children():
		if child.name != "SkillsHeader":
			child.queue_free()
	for skill_id in SKILL_DISPLAY:
		var val: int = GameState.skills.get(skill_id, 0)
		var invested: int = GameState.skill_investments.get(skill_id, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = "%-14s %d" % [SKILL_DISPLAY.get(skill_id, skill_id), val]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
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


# Perks live appended to the stats column (cleared/rebuilt each _refresh).
func _refresh_perks() -> void:
	var sep := HSeparator.new()
	_stats_column.add_child(sep)

	var hdr := Label.new()
	hdr.add_theme_font_size_override("font_size", 18)
	if GameState.perk_picks_available > 0:
		hdr.text = "PERKS   (picks: %d)" % GameState.perk_picks_available
		hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	else:
		hdr.text = "PERKS"
	_stats_column.add_child(hdr)

	if GameState.perks.is_empty():
		var none := Label.new()
		none.text = "  (none yet)"
		none.add_theme_font_size_override("font_size", 16)
		none.add_theme_color_override("font_color", Color(0.55, 0.52, 0.40))
		_stats_column.add_child(none)
	else:
		for pid in GameState.perks:
			var perk := DataManager.get_perk(pid)
			var pl := Label.new()
			pl.text = "  • %s" % perk.get("name", pid)
			pl.tooltip_text = perk.get("description", "")
			pl.add_theme_font_size_override("font_size", 16)
			_stats_column.add_child(pl)

	if GameState.perk_picks_available > 0:
		var pick_btn := Button.new()
		pick_btn.text = "Choose Perk"
		pick_btn.pressed.connect(_open_perk_picker)
		_stats_column.add_child(pick_btn)


func _on_raise_stat(stat_id: String) -> void:
	if GameState.spend_stat_point(stat_id):
		AudioManager.play_sfx("confirm")
		_refresh()


func _open_perk_picker() -> void:
	var dim := ColorRect.new()
	dim.name = "PerkPickerDim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -300; panel.offset_top = -260
	panel.offset_right = 300; panel.offset_bottom = 260
	dim.add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var title := Label.new()
	title.text = "CHOOSE A PERK"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var any_eligible := false
	for perk: Dictionary in DataManager.get_all_perks():
		var pid: String = perk.get("id", "")
		if pid in GameState.perks:
			continue
		var eligible: bool = GameState.can_take_perk(pid)
		if eligible:
			any_eligible = true
		var row := PanelContainer.new()
		var rvb := VBoxContainer.new()
		row.add_child(rvb)
		var name_lbl := Label.new()
		name_lbl.text = perk.get("name", pid)
		name_lbl.add_theme_font_size_override("font_size", 19)
		rvb.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = perk.get("description", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(480, 0)
		desc_lbl.add_theme_font_size_override("font_size", 15)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.67, 0.55))
		rvb.add_child(desc_lbl)
		if not eligible:
			var req_lbl := Label.new()
			req_lbl.text = "Locked — " + _perk_req_text(perk.get("requirements", {}))
			req_lbl.add_theme_font_size_override("font_size", 14)
			req_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.35))
			rvb.add_child(req_lbl)
		else:
			var take := Button.new()
			take.text = "Take"
			take.pressed.connect(func() -> void:
				if GameState.choose_perk(pid):
					AudioManager.play_sfx("confirm")
				dim.queue_free()
				_refresh())
			rvb.add_child(take)
		vb.add_child(row)

	if not any_eligible:
		var note := Label.new()
		note.text = "No perks available yet — raise your skills or level up."
		note.add_theme_font_size_override("font_size", 15)
		note.add_theme_color_override("font_color", Color(0.7, 0.67, 0.55))
		vb.add_child(note)

	var close := Button.new()
	close.text = "Cancel"
	close.pressed.connect(dim.queue_free)
	vb.add_child(close)


func _perk_req_text(req: Dictionary) -> String:
	var parts: Array = []
	if req.has("level"):
		parts.append("Level %d" % int(req["level"]))
	for st: String in req.get("stats", {}):
		parts.append("%s %d" % [st.capitalize(), int(req["stats"][st])])
	for sk: String in req.get("skills", {}):
		parts.append("%s %d" % [sk.capitalize(), int(req["skills"][sk])])
	return ", ".join(parts)


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
