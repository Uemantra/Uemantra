extends Control

# The Theory Board accumulates evidence. It never gives a verdict.
# Weights are internal — the board shows what was found, not what it means.

const EVIDENCE_CARD_SCENE := preload("res://scenes/theory_board/evidence_card.tscn")
const THEORY_CARD_SCENE   := preload("res://scenes/theory_board/theory_card.tscn")

# Selected echo waiting for a theory to be clicked — connection mechanic.
var _pending_echo_id: String = ""

@onready var _theory_cards_container: Control      = $Board/TheoryCards
@onready var _holdouts_card: PanelContainer        = $Board/HoldoutsCard
@onready var _unresolved_container: VBoxContainer  = $Board/UnresolvedPile/PileVBox/EvidenceList
@onready var _connections_layer: Node2D            = $Board/ConnectionsLayer
@onready var _close_button: Button = $CloseButton

var _board_state: BoardState
# theory_id -> TheoryCard node
var _theory_card_nodes: Dictionary = {}
# echo_id -> EvidenceCard node (unresolved pile only; resolved cards live on theory cards)
var _unresolved_card_nodes: Dictionary = {}

# Static theory display data, loaded from theories.json.
var _theories_data: Dictionary = {}


func _ready() -> void:
	_board_state = BoardState.new()
	_load_theories_data()
	_build_theory_cards()
	_refresh()
	GameState.state_changed.connect(_on_state_changed)
	_close_button.pressed.connect(_on_close_pressed)


func _load_theories_data() -> void:
	_theories_data = DataManager.theories


func _build_theory_cards() -> void:
	# The five main theory cards are instantiated once and positioned manually.
	# Layout: two rows — top row 3 cards, bottom row 2 cards — centred on the board.
	var main_theories: Array[String] = [
		"alignment_cascade", "weaponized_drift", "the_choice",
		"civil_war", "convergence"
	]
	var positions: Array[Vector2] = [
		Vector2(30, 20),   # alignment_cascade
		Vector2(310, 20),  # weaponized_drift
		Vector2(590, 20),  # the_choice
		Vector2(170, 260), # civil_war
		Vector2(450, 260), # convergence
	]

	for i in range(main_theories.size()):
		var tid: String = main_theories[i]
		var card := THEORY_CARD_SCENE.instantiate()
		card.set("theory_id", tid)
		card.set("theory_name", _theories_data.get(tid, {}).get("name", tid))
		card.set("theory_description", _theories_data.get(tid, {}).get("card_text", ""))
		card.position = positions[i]
		_theory_cards_container.add_child(card)
		_theory_card_nodes[tid] = card
		card.selected.connect(_on_theory_card_selected)

	# Populate the Holdouts card from data — it's a fixed scene node, not instantiated.
	var holdouts_data: Dictionary = _theories_data.get("holdouts", {})
	var h_name: Label = _holdouts_card.get_node("VBox/NameLabel")
	var h_desc: Label = _holdouts_card.get_node("VBox/DescLabel")
	var h_margin: Label = _holdouts_card.get_node("VBox/MarginNote")
	if h_name:
		h_name.text = holdouts_data.get("name", "The Holdouts?")
	if h_desc:
		h_desc.text = holdouts_data.get("card_text", "")
	if h_margin:
		h_margin.text = holdouts_data.get("vera_margin_note", "")


func _refresh() -> void:
	# Rebuild evidence on each theory card.
	for theory_id in _theory_card_nodes:
		var card = _theory_card_nodes[theory_id]
		var evidence: Array[String] = _board_state.get_theory_evidence(theory_id)
		card.refresh(evidence)

	# Rebuild unresolved pile.
	for child in _unresolved_container.get_children():
		child.queue_free()
	_unresolved_card_nodes.clear()

	var unresolved: Array[String] = _board_state.get_unresolved_echoes()
	for echo_id in unresolved:
		var card := EVIDENCE_CARD_SCENE.instantiate()
		_unresolved_container.add_child(card)
		card.setup(echo_id, false, 0.0)
		card.selected.connect(_on_evidence_card_selected)
		_unresolved_card_nodes[echo_id] = card

	# Defer connection drawing by one frame so Control layout is complete.
	call_deferred("_redraw_connections")


func _redraw_connections() -> void:
	for child in _connections_layer.get_children():
		child.queue_free()

	var connections: Array[Dictionary] = _board_state.get_connections()
	for conn in connections:
		_draw_connection_line(conn["echo_id"], conn["theory_id"])


func _draw_connection_line(echo_id: String, theory_id: String) -> void:
	if theory_id not in _theory_card_nodes:
		return
	var theory_card = _theory_card_nodes[theory_id] as Control

	# Convert global rect centres to ConnectionsLayer local space so lines
	# are positioned correctly regardless of nesting depth.
	var theory_global_centre := theory_card.get_global_rect().get_center()
	var to_pos := _connections_layer.to_local(theory_global_centre)

	var from_pos: Vector2
	if echo_id in _unresolved_card_nodes:
		var ev_card: Control = _unresolved_card_nodes[echo_id]
		from_pos = _connections_layer.to_local(ev_card.get_global_rect().get_center())
	else:
		# Echo has been filed under a theory card — draw from that card's lower edge.
		var bottom_global := theory_card.get_global_rect().position + Vector2(theory_card.size.x * 0.5, theory_card.size.y)
		from_pos = _connections_layer.to_local(bottom_global)

	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 1.5
	line.default_color = Color(0.55, 0.2, 0.1, 0.7)  # faded red string
	line.antialiased = true
	_connections_layer.add_child(line)


# --- Connection mechanic ---

func _on_evidence_card_selected(echo_id: String) -> void:
	_pending_echo_id = echo_id


func _on_theory_card_selected(theory_id: String) -> void:
	if _pending_echo_id.is_empty():
		return
	var flag_key := "board_connection_" + _pending_echo_id + "_" + theory_id
	# Only draw if not already stored.
	if not GameState.get_flag(flag_key, false):
		GameState.set_flag(flag_key, true)
		# set_flag emits state_changed, which triggers _on_state_changed -> _refresh.
	_pending_echo_id = ""


func _on_state_changed() -> void:
	_refresh()


func _on_close_pressed() -> void:
	queue_free()
