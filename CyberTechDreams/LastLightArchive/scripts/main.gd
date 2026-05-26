extends Control


func _ready() -> void:
	theme = ThemeBuilder.build_paper_theme()
	$VBox/Continue.disabled = not SaveManager.has_save()


func _on_new_game_pressed() -> void:
	GameState.new_game()
	TimeManager.deserialize({})
	SaveManager.save()
	# TODO SEG-01: transition to village scene
	print("New game — %s" % TimeManager.get_display_string())


func _on_continue_pressed() -> void:
	var ok := SaveManager.load_save()
	if ok:
		# TODO SEG-01: transition to village scene
		print("Loaded — %s" % TimeManager.get_display_string())
	else:
		$VBox/Continue.disabled = true
