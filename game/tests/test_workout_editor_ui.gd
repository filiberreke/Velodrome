extends SceneTree
const Menu := preload("res://race_menu.gd")
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(5): await process_frame
func shot(filename: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../" + filename + ".png")
func run_test() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu := Menu.new()
	menu.workout_library.folder = "user://test_workout_editor_library"
	root.add_child(menu)
	await settle()
	var upper_row = menu.hub_page.get_child(0)
	var lower_row = menu.hub_page.get_child(1)
	var training_tile = lower_row.get_child(0)
	var piste_tile = lower_row.get_child(1)
	var tournament_tile = upper_row.get_child(1)
	check(menu.hub_button.get_child(0).get_child(1).get_child_count() == 1, "Race tile reuses discipline image")
	check(is_equal_approx(training_tile.size.x, piste_tile.size.x), "Training row has equal half-width tiles")
	check(is_equal_approx(menu.hub_button.size.x, tournament_tile.size.x), "Races and tournaments share the first row")
	check(lower_row.position.y > upper_row.position.y, "Training categories are on the second row")
	for tile in [menu.hub_button, training_tile, piste_tile, tournament_tile]:
		check(root.get_visible_rect().encloses(tile.get_global_rect()), "Main tile fits")
	await shot("v02_hub")
	training_tile.pressed.emit()
	check(menu.page == 6, "Training tile opens training")
	menu.show_workout_editor()
	await settle()
	var editor = menu.workout_editor_page
	check(editor.block_buttons.size() == editor.blocks.size(), "One selectable target per chart block")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = editor.block_buttons[1].get_global_rect().get_center()
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await settle()
	check(editor.selected == 1, "Clicking chart selects its block")
	check(editor.inspector.get_child(0).text == "Constant vermogen", "Right inspector follows selection")
	var field = editor.inspector.get_child(2)
	field.get_line_edit().grab_focus()
	editor.message_edit.text = "Nog niet bewaard"
	field.value = 250
	await settle()
	check(editor.blocks[1].duration == 250, "Duration updates data")
	check(is_instance_valid(field) and field.get_line_edit().has_focus(), "Editing preserves field focus")
	check(editor.message_edit.text == "Nog niet bewaard", "Editing preserves pending message")
	editor._save_message()
	editor._move(-1)
	check(editor.selected == 0 and editor.blocks[0].kind == "SteadyState", "Left moves selected block earlier")
	editor._move(1)
	check(editor.selected == 1 and editor.blocks[1].kind == "SteadyState", "Right moves selected block later")
	editor._duplicate()
	check(editor.blocks.size() == 5 and editor.selected == 2, "Duplicate selects inserted block")
	editor.blocks[2].events[0].message = "Kopie"
	check(editor.blocks[1].events[0].message == "Nog niet bewaard", "Duplicate is independent")
	editor._remove()
	editor._add("IntervalsT")
	await settle()
	check(root.get_visible_rect().encloses(editor.inspector.get_global_rect()), "Interval inspector fits")
	await shot("v02_editor_intervals")
	editor._save_file("user://workout_editor_ui.zwo")
	var count: int = editor.blocks.size()
	editor._load_file("user://workout_editor_ui.zwo")
	check(editor.blocks.size() == count + 5 and editor.blocks[1].duration == 250 and editor.blocks[1].events[0].message == "Nog niet bewaard", "ZWO roundtrip preserves duration, messages and expanded intervals")
	editor._select(0)
	await settle()
	await shot("v02_editor")
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await settle()
		check(root.get_visible_rect().encloses(editor.get_global_rect()), "Editor fits at %s" % resolution)
		check(root.get_visible_rect().encloses(editor.inspector.get_global_rect()), "Inspector fits at %s" % resolution)
	menu.bridge_action("B")
	check(menu.page == 6, "Controller back returns to training")
	menu.show_workout_editor()
	while not editor.blocks.is_empty(): editor._remove()
	check(editor.selected == -1 and editor.action_buttons[2].disabled, "Empty workout clears selection and disables actions")
	editor._add("FreeRide")
	check(editor.selected == 0 and editor.block_buttons.size() == 1, "Empty workout can be rebuilt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://workout_editor_ui.zwo"))
	for item in menu.workout_library.all_workouts():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.workout_library._path(item.id)))
	menu.free()
	print("WORKOUT_EDITOR_UI failures=", failures)
	quit(0 if failures == 0 else 1)
