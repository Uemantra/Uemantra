extends Control

const TILE_SIZE: int = 48
const TILE_COLORS := {
	"default": Color(0.15, 0.13, 0.12, 1.0),
	"highlight_move": Color(0.2, 0.4, 0.7, 0.6),
	"highlight_attack": Color(0.7, 0.2, 0.2, 0.6),
	"current": Color(0.9, 0.8, 0.3, 0.4),
	"occupied": Color(0.4, 0.35, 0.3, 1.0),
}

@onready var _grid_container: Control = $GridContainer
@onready var _initiative_strip: VBoxContainer = $InitiativeStrip
@onready var _ap_label: Label = $ApLabel
@onready var _status_label: Label = $StatusLabel
@onready var _move_btn: Button = $ActionBar/MoveBtn
@onready var _attack_btn: Button = $ActionBar/AttackBtn
@onready var _item_btn: Button = $ActionBar/ItemBtn
@onready var _end_turn_btn: Button = $ActionBar/EndTurnBtn
@onready var _result_overlay: PanelContainer = $ResultOverlay
@onready var _result_title: Label = $ResultOverlay/ResultContents/ResultTitle
@onready var _result_message: Label = $ResultOverlay/ResultContents/ResultMessage
@onready var _result_btn: Button = $ResultOverlay/ResultContents/ResultBtn

enum Mode { NONE, MOVE, ATTACK }
var _mode: Mode = Mode.NONE
var _tile_rects: Dictionary = {}     # Vector2i -> ColorRect
var _combatant_labels: Dictionary = {}  # combatant_id -> Label
var _valid_cells: Array = []
var _valid_targets: Array = []


func _ready() -> void:
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.turn_ended.connect(_on_turn_ended)
	CombatManager.combatant_moved.connect(_on_combatant_moved)
	CombatManager.combatant_attacked.connect(_on_combatant_attacked)
	CombatManager.combatant_died.connect(_on_combatant_died)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.ap_spent.connect(_on_ap_spent)

	_move_btn.pressed.connect(_on_move_mode)
	_attack_btn.pressed.connect(_on_attack_mode)
	_item_btn.pressed.connect(_on_item_mode)
	_end_turn_btn.pressed.connect(_on_end_turn)
	_result_btn.pressed.connect(_on_result_continue)

	_build_grid()
	_refresh_combatant_labels()
	_refresh_initiative_strip()
	_refresh_action_buttons()


func _build_grid() -> void:
	for x in CombatManager.GRID_W:
		for y in CombatManager.GRID_H:
			var cell := Vector2i(x, y)
			var rect := ColorRect.new()
			rect.color = TILE_COLORS["default"]
			rect.size = Vector2(TILE_SIZE - 2, TILE_SIZE - 2)
			rect.position = Vector2(x * TILE_SIZE + 1, y * TILE_SIZE + 1)
			_grid_container.add_child(rect)
			_tile_rects[cell] = rect

			var btn := Button.new()
			btn.flat = true
			btn.size = Vector2(TILE_SIZE, TILE_SIZE)
			btn.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			btn.pressed.connect(_on_tile_clicked.bind(cell))
			_grid_container.add_child(btn)


func _refresh_combatant_labels() -> void:
	for lbl in _combatant_labels.values():
		lbl.queue_free()
	_combatant_labels.clear()

	for cid in CombatManager.get_all_combatants():
		var cdata: Dictionary = CombatManager.get_combatant(cid)
		if cdata.get("dead", false):
			continue
		var cell: Vector2i = cdata.get("cell", Vector2i(0, 0))
		var lbl := Label.new()
		lbl.text = _get_combatant_symbol(cid)
		lbl.theme_override_font_sizes = {"font_size": 20}
		lbl.position = Vector2(cell.x * TILE_SIZE + 8, cell.y * TILE_SIZE + 8)
		_grid_container.add_child(lbl)
		_combatant_labels[cid] = lbl

		_update_hp_color(cid)


func _get_combatant_symbol(cid: String) -> String:
	if cid == "player":
		return "@"
	var cdata := CombatManager.get_combatant(cid)
	return "!" if cdata.get("team", "") == "enemy" else "?"


func _update_hp_color(cid: String) -> void:
	if not _combatant_labels.has(cid):
		return
	var cdata := CombatManager.get_combatant(cid)
	var hp: int = cdata.get("hp", 0)
	var hp_max: int = cdata.get("hp_max", 1)
	var ratio: float = float(hp) / float(max(hp_max, 1))
	var lbl: Label = _combatant_labels[cid]
	if cid == "player":
		lbl.theme_override_colors = {"font_color": Color(0.3, 0.9, 0.3) if ratio > 0.5 else Color(1.0, 0.6, 0.1)}
	else:
		lbl.theme_override_colors = {"font_color": Color(0.9, 0.3, 0.3)}


func _refresh_initiative_strip() -> void:
	for child in _initiative_strip.get_children():
		if child is Label and child.name != "InitiativeLabel":
			child.queue_free()
	var current_id := CombatManager.get_current_combatant()
	for cid in CombatManager.get_all_combatants():
		var cdata := CombatManager.get_combatant(cid)
		if cdata.get("dead", false):
			continue
		var lbl := Label.new()
		var name_str := "You" if cid == "player" else DataManager.get_npc(cid).get("name", cid)
		var hp_str := "%d/%d HP" % [cdata.get("hp", 0), cdata.get("hp_max", 0)]
		lbl.text = "%s\n%s" % [name_str, hp_str]
		lbl.theme_override_font_sizes = {"font_size": 12}
		if cid == current_id:
			lbl.theme_override_colors = {"font_color": Color(0.9, 0.8, 0.3, 1)}
		_initiative_strip.add_child(lbl)


func _refresh_action_buttons() -> void:
	var is_player := CombatManager.is_player_turn()
	_move_btn.disabled = not is_player
	_attack_btn.disabled = not is_player
	_item_btn.disabled = not is_player
	_end_turn_btn.disabled = not is_player
	_clear_tile_highlights()
	_mode = Mode.NONE


func _highlight_cells(cells: Array, color_key: String) -> void:
	for cell in cells:
		if _tile_rects.has(cell):
			_tile_rects[cell].color = TILE_COLORS[color_key]


func _clear_tile_highlights() -> void:
	for cell in _tile_rects:
		_tile_rects[cell].color = TILE_COLORS["default"]
	var player_cell := CombatManager.get_combatant("player").get("cell", Vector2i(-1,-1))
	if _tile_rects.has(player_cell):
		_tile_rects[player_cell].color = TILE_COLORS["current"]


func _on_move_mode() -> void:
	_mode = Mode.MOVE
	_valid_cells = CombatManager.get_valid_moves("player")
	_clear_tile_highlights()
	_highlight_cells(_valid_cells, "highlight_move")


func _on_attack_mode() -> void:
	_mode = Mode.ATTACK
	_valid_targets = CombatManager.get_valid_targets("player")
	_clear_tile_highlights()
	var target_cells: Array = []
	for tid in _valid_targets:
		target_cells.append(CombatManager.get_combatant(tid).get("cell", Vector2i()))
	_highlight_cells(target_cells, "highlight_attack")


func _on_item_mode() -> void:
	pass  # Wire up to inventory selection in Milestone 4


func _on_end_turn() -> void:
	CombatManager.end_player_turn()


func _on_tile_clicked(cell: Vector2i) -> void:
	match _mode:
		Mode.MOVE:
			if cell in _valid_cells:
				CombatManager.try_move("player", cell)
				_refresh_combatant_labels()
				_clear_tile_highlights()
				_mode = Mode.NONE
		Mode.ATTACK:
			var target_id := _cell_to_enemy(cell)
			if target_id != "" and target_id in _valid_targets:
				CombatManager.try_attack("player", target_id)
				_refresh_combatant_labels()
				_refresh_initiative_strip()
				_clear_tile_highlights()
				_mode = Mode.NONE
		_:
			pass


func _cell_to_enemy(cell: Vector2i) -> String:
	for cid in CombatManager.get_all_combatants():
		var cdata := CombatManager.get_combatant(cid)
		if cdata.get("cell", Vector2i()) == cell and cdata.get("team", "") == "enemy" and not cdata.get("dead", false):
			return cid
	return ""


func _on_turn_started(combatant_id: String, ap_remaining: int) -> void:
	_ap_label.text = "AP: %d" % ap_remaining
	var name_str := "Your Turn" if combatant_id == "player" else "%s's Turn" % DataManager.get_npc(combatant_id).get("name", combatant_id)
	_status_label.text = name_str
	_refresh_action_buttons()
	_refresh_initiative_strip()


func _on_turn_ended(_combatant_id: String) -> void:
	_refresh_action_buttons()


func _on_combatant_moved(combatant_id: String, _from: Vector2i, to: Vector2i) -> void:
	if _combatant_labels.has(combatant_id):
		_combatant_labels[combatant_id].position = Vector2(to.x * TILE_SIZE + 8, to.y * TILE_SIZE + 8)
	if combatant_id == "player":
		_ap_label.text = "AP: %d" % CombatManager.get_ap("player")


func _on_combatant_attacked(attacker_id: String, target_id: String, damage: int, hit: bool) -> void:
	_update_hp_color(target_id)
	_refresh_initiative_strip()
	if hit:
		_status_label.text = "Hit! %d damage" % damage
	else:
		_status_label.text = "Missed!"
	if attacker_id == "player":
		_ap_label.text = "AP: %d" % CombatManager.get_ap("player")


func _on_combatant_died(combatant_id: String) -> void:
	if _combatant_labels.has(combatant_id):
		_combatant_labels[combatant_id].queue_free()
		_combatant_labels.erase(combatant_id)
	_refresh_initiative_strip()


func _on_ap_spent(combatant_id: String, ap_remaining: int) -> void:
	if combatant_id == "player":
		_ap_label.text = "AP: %d" % ap_remaining


func _on_combat_ended(victory: bool) -> void:
	_result_title.text = "VICTORY" if victory else "DEFEAT"
	_result_message.text = "Enemies defeated. You can proceed." if victory else "You have been defeated."
	_result_overlay.visible = true
	_result_overlay.move_to_front()

	if victory:
		var arena_id := CombatManager._arena_id
		for loc_id in DataManager.locations:
			var loc := DataManager.get_location(loc_id)
			if loc.get("combat_arena", "") == arena_id:
				var trigger: Dictionary = loc.get("combat_trigger", {})
				var once_flag: String = trigger.get("trigger_once_flag", "")
				if once_flag != "":
					GameState.set_flag(once_flag)
				break


func _on_result_continue() -> void:
	var victory: bool = _result_title.text == "VICTORY"
	if victory:
		GameState.hp = CombatManager.get_combatant("player").get("hp", GameState.derived.get("max_hp", 20))
		get_tree().change_scene_to_file("res://scenes/location/location.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
