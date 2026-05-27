extends PanelContainer

@onready var _close_btn: Button = $Contents/TitleRow/CloseBtn
@onready var _quest_vbox: VBoxContainer = $Contents/QuestScroll/QuestVBox


func _ready() -> void:
	_close_btn.pressed.connect(queue_free)
	_refresh()


func _refresh() -> void:
	for child in _quest_vbox.get_children():
		child.queue_free()

	var active_quests := QuestManager.get_active_quests()
	if active_quests.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No active quests."
		empty_lbl.theme_override_colors = {"font_color": Color(0.5, 0.5, 0.5, 1)}
		_quest_vbox.add_child(empty_lbl)
		return

	for quest_id in active_quests:
		var display := QuestManager.get_quest_display(quest_id)
		if display.is_empty():
			continue
		var container := VBoxContainer.new()
		container.theme_override_constants = {"separation": 6}

		var title_lbl := Label.new()
		title_lbl.text = display.get("title", quest_id)
		title_lbl.theme_override_font_sizes = {"font_size": 16}
		title_lbl.theme_override_colors = {"font_color": Color(0.9, 0.8, 0.4, 1)}
		container.add_child(title_lbl)

		var stage_lbl := Label.new()
		stage_lbl.text = display.get("stage", "")
		stage_lbl.theme_override_font_sizes = {"font_size": 13}
		stage_lbl.theme_override_colors = {"font_color": Color(0.7, 0.7, 0.6, 1)}
		container.add_child(stage_lbl)

		for obj in display.get("objectives", []):
			var obj_lbl := Label.new()
			var complete: bool = obj.get("complete", false)
			var optional: bool = obj.get("optional", false)
			var prefix := "[✓] " if complete else "[ ] "
			var suffix := " (optional)" if optional else ""
			obj_lbl.text = prefix + obj.get("text", "") + suffix
			obj_lbl.theme_override_font_sizes = {"font_size": 13}
			var color := Color(0.5, 0.8, 0.5, 1) if complete else Color(0.8, 0.8, 0.8, 1)
			obj_lbl.theme_override_colors = {"font_color": color}
			container.add_child(obj_lbl)

		_quest_vbox.add_child(container)

	# Also show completed quests
	for quest_id in GameState.quest_states:
		if GameState.quest_states[quest_id].get("state", "") == "complete":
			var quest := DataManager.get_quest(quest_id)
			var lbl := Label.new()
			lbl.text = "[✓] %s — Completed" % quest.get("title", quest_id)
			lbl.theme_override_font_sizes = {"font_size": 14}
			lbl.theme_override_colors = {"font_color": Color(0.4, 0.6, 0.4, 1)}
			_quest_vbox.add_child(lbl)
