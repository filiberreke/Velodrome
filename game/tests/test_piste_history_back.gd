extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var menu = preload("res://race_menu.gd").new()
	root.add_child(menu)
	for kind in ["derny","madison","free_ride","flying_start","take_lap"]:
		var activity := {"kind":kind,"title":"Opgeslagen training","duration_s":120,"final":true,"samples":[{"time_s":0.0,"power_w":150.0},{"time_s":1.0,"power_w":160.0}]}
		menu.show_training_history()
		menu.training_history_page._open_activity(activity)
		var page = menu.derny_page if kind == "derny" else menu.madison_page if kind == "madison" else menu.exercise_page
		check(page.return_to_history and page.back_button.text == "← Opgeslagen trainingen" and page.back_button.is_visible_in_tree(),kind+" shows history back button")
		page.back_button.pressed.emit()
		check(menu.page == 13 and menu.training_history_page.is_visible_in_tree(),kind+" button returns to history")
		menu.training_history_page._open_activity(activity)
		menu.bridge_action("B")
		check(menu.page == 13 and menu.training_history_page.is_visible_in_tree(),kind+" B action returns to history")
		menu.training_history_page._open_activity(activity)
		page.prepare_new_training()
		check(not page.return_to_history and page.back_button.text == "← Pistetraining",kind+" restarting resets destination")
		page.back_button.pressed.emit()
		check(menu.page == 11,kind+" fresh training returns to piste menu")
	menu.free()
	print("PISTE_HISTORY_BACK failures=",failures)
	quit(0 if failures == 0 else 1)
