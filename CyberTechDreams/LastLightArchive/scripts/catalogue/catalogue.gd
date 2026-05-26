extends Control

@onready var section_container: Control = $NotebookPanel/RightPage/SectionContainer
@onready var section_tabs: HBoxContainer = $NotebookPanel/TabStrip

var current_section: String = "relics"
var current_entry_index: int = 0

const SECTIONS: Array[String] = [
	"relics",
	"fragments",
	"people_know",
	"people_never_know",
	"machines_said",
	"map",
]

const SECTION_LABELS: Dictionary = {
	"relics":           "Relics",
	"fragments":        "Recovered Fragments",
	"people_know":      "People We Know",
	"people_never_know": "People We'll Never Know",
	"machines_said":    "What the Machines Said",
	"map":              "The Archive Map",
}

const SECTION_SCENES: Dictionary = {
	"relics":           "res://scenes/catalogue/section_relics.tscn",
	"fragments":        "res://scenes/catalogue/section_fragments.tscn",
	"people_know":      "res://scenes/catalogue/section_people_know.tscn",
	"people_never_know": "res://scenes/catalogue/section_people_never_know.tscn",
	"machines_said":    "res://scenes/catalogue/section_machines_said.tscn",
	"map":              "res://scenes/catalogue/section_map.tscn",
}

var _tab_buttons: Dictionary = {}
var _active_section_node: Control = null


func _ready() -> void:
	_build_tabs()
	GameState.state_changed.connect(_on_state_changed)
	open_section(current_section)


func _build_tabs() -> void:
	for child in section_tabs.get_children():
		child.queue_free()
	for section_id in SECTIONS:
		var btn := Button.new()
		btn.text = SECTION_LABELS[section_id]
		btn.toggle_mode = true
		btn.pressed.connect(open_section.bind(section_id))
		section_tabs.add_child(btn)
		_tab_buttons[section_id] = btn


func open_section(section_id: String) -> void:
	current_section = section_id
	current_entry_index = 0
	_update_tab_highlights()
	_load_section_scene(section_id)


func open_to_entry(entry_id: String) -> void:
	# Determine which section this entry belongs to and navigate there.
	var entry_data := GameState.catalogue_entries.get(entry_id, {})
	if entry_data.is_empty():
		return
	var section_id := _section_for_entry(entry_id, entry_data)
	open_section(section_id)
	if _active_section_node and _active_section_node.has_method("select_entry"):
		_active_section_node.select_entry(entry_id)


func _section_for_entry(entry_id: String, _entry_data: Dictionary) -> String:
	# Companion entries live in people_know.
	if entry_id in GameState.companions:
		return "people_know"
	# Cache-derived entries carry their section in the authored data.
	# We look up the raw authored section tag to route correctly.
	var authored_section := _get_authored_section_tag(entry_id)
	match authored_section:
		"people_we_never_knew":
			return "people_never_know"
		"what_the_machines_said":
			return "machines_said"
		"relics":
			return "relics"
	# Entries without a known authored section that arrived from cache processing
	# are recovered fragments by default.
	if _entry_data.get("from_cache", false):
		return "fragments"
	return "relics"


func _get_authored_section_tag(entry_id: String) -> String:
	# Relics and echoes have a catalogue_section field in their authored data.
	var relic_data := DataManager.get_relic(entry_id)
	if not relic_data.is_empty():
		return relic_data.get("catalogue_section", "relics")
	# Cache yields embed catalogue_section per yield entry — stored on the entry itself.
	for cache_id in DataManager.caches:
		var cache_data: Dictionary = DataManager.get_cache(cache_id)
		for yield_item in cache_data.get("yields", []):
			if yield_item.get("entry_id", "") == entry_id:
				return yield_item.get("catalogue_section", "")
	return ""


func _load_section_scene(section_id: String) -> void:
	if _active_section_node != null:
		_active_section_node.queue_free()
		_active_section_node = null
	var scene_path: String = SECTION_SCENES.get(section_id, "")
	if scene_path == "":
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	_active_section_node = packed.instantiate()
	section_container.add_child(_active_section_node)
	# Pass a reference back so sections can request entry-view navigation.
	if _active_section_node.has_method("set_catalogue"):
		_active_section_node.set_catalogue(self)


func show_entry(entry_id: String) -> void:
	# Called by section sub-scenes when the player selects an entry.
	var entry_view_packed: PackedScene = load("res://scenes/catalogue/entry_view.tscn")
	if entry_view_packed == null:
		return
	if _active_section_node != null:
		_active_section_node.queue_free()
		_active_section_node = null
	_active_section_node = entry_view_packed.instantiate()
	section_container.add_child(_active_section_node)
	if _active_section_node.has_method("load_entry"):
		_active_section_node.load_entry(entry_id)
	if _active_section_node.has_method("set_back_callback"):
		_active_section_node.set_back_callback(func(): open_section(current_section))


func _update_tab_highlights() -> void:
	for section_id in _tab_buttons:
		var btn: Button = _tab_buttons[section_id]
		btn.button_pressed = (section_id == current_section)


func _on_state_changed() -> void:
	# Refresh the currently visible section when game state changes.
	if _active_section_node and _active_section_node.has_method("refresh"):
		_active_section_node.refresh()
