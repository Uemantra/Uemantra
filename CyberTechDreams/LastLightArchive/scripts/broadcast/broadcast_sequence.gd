extends Control

# Beat types: "text" = player advances; "auto" = auto-advances after delay.
const _AUTO_BEAT_DURATION: float = 3.0

@onready var _beat_label: RichTextLabel = $BeatLabel
@onready var _advance_button: Button = $AdvanceButton

var _beats: Array = []
var _current_beat: int = 0
var _waiting_auto: bool = false
var _tween: Tween


func _ready() -> void:
	_advance_button.pressed.connect(_on_advance_pressed)
	_beat_label.modulate.a = 0.0
	_build_beats()
	_show_beat(_current_beat)


func _input(event: InputEvent) -> void:
	if _waiting_auto:
		return
	if event.is_action_pressed("ui_accept"):
		_on_advance_pressed()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- #
# Beat construction
# --------------------------------------------------------------------------- #

func _build_beats() -> void:
	_beats.clear()

	# Beat 1: atmosphere.
	_beats.append({
		"type": "text",
		"text": "Evening. Ashford is quiet in the way it gets when everyone knows something is happening.",
	})

	# Beat 2: companions present.
	var present_lines: Array = _build_companion_lines()
	for line in present_lines:
		_beats.append({"type": "text", "text": line})

	# Beat 3: Corvus plays.
	var corvus_gs: Dictionary = GameState.companions.get("corvus", {})
	var corvus_resolved: bool = not corvus_gs.get("arcs_completed", []).is_empty()
	if corvus_resolved:
		_beats.append({
			"type": "text",
			"text": "Corvus plays. It is everything the Catalogue contains, filtered through him. It lasts eleven minutes. No one speaks.",
		})
	else:
		_beats.append({
			"type": "text",
			"text": "Corvus plays something older. Something he wrote before any of this.",
		})

	# Beat 4: Vera at the encoding station.
	_beats.append({
		"type": "text",
		"text": "Vera sits at the encoding station.",
	})

	# Beat 5: machines_said note.
	var choice: String = GameState.get_flag("machines_said_choice", "none")
	var machines_said_text: String
	match choice:
		"full":
			machines_said_text = "She includes the machines' words. All of them. Flagged as model output in the transmission packet."
		"curated":
			machines_said_text = "She includes what she can verify. The rest stays in the notebook, for whoever comes next."
		"none":
			machines_said_text = "She leaves their words out. They were hers to keep."
		_:
			machines_said_text = "She leaves their words out. They were hers to keep."
	_beats.append({"type": "text", "text": machines_said_text})

	# Beat 6: signal goes out.
	_beats.append({
		"type": "text",
		"text": "The signal goes out.",
	})

	# Beat 7: silence — auto-advance.
	_beats.append({
		"type": "auto",
		"text": "",
	})


func _build_companion_lines() -> Array:
	var lines: Array = []
	var companion_present_lines: Dictionary = {
		"maren":  "Maren is in the corner chair. She brought her recording notebook.",
		"eli":    "Eli is in the workshop door. He doesn't come in, but he doesn't leave either.",
		"sable":  "Sable is outside, visible through the window. They don't knock.",
		"wren":   "Wren stands near the wall. She hasn't said anything yet.",
		"doss":   "Doss has his book open but he isn't reading it.",
		"petra":  "Petra is here. She checked in once and hasn't left.",
		"corvus": "",
	}

	for companion_id in GameState.companions:
		var gs_data: Dictionary = GameState.companions[companion_id]
		if gs_data.get("relationship", 0) <= 0:
			continue
		# Corvus is handled in his own beat.
		if companion_id == "corvus":
			continue
		var line: String = companion_present_lines.get(companion_id, "")
		if line != "":
			lines.append(line)

	return lines


# --------------------------------------------------------------------------- #
# Beat display
# --------------------------------------------------------------------------- #

func _show_beat(index: int) -> void:
	if index >= _beats.size():
		_transition_to_epilogue()
		return

	var beat: Dictionary = _beats[index]
	var text: String = beat.get("text", "")
	var beat_type: String = beat.get("type", "text")

	_beat_label.text = text

	if beat_type == "auto":
		_advance_button.hide()
		_waiting_auto = true
		_fade_in_label()
		await get_tree().create_timer(_AUTO_BEAT_DURATION).timeout
		_waiting_auto = false
		_current_beat += 1
		_show_beat(_current_beat)
	else:
		_advance_button.show()
		_fade_in_label()


func _fade_in_label() -> void:
	if _tween:
		_tween.kill()
	_beat_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_beat_label, "modulate:a", 1.0, 0.4)


func _on_advance_pressed() -> void:
	if _waiting_auto:
		return
	_current_beat += 1
	_show_beat(_current_beat)


func _transition_to_epilogue() -> void:
	BroadcastManager.complete_broadcast()
	var epilogue_scene: PackedScene = load("res://scenes/broadcast/epilogue.tscn")
	get_tree().change_scene_to_packed(epilogue_scene)
