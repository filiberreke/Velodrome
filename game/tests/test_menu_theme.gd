extends SceneTree
const Menu := preload("res://race_menu.gd")
var failures := 0
var starts := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in range(3): await process_frame
func run_test() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu := Menu.new()
	root.add_child(menu)
	menu.start_requested.connect(func() -> void: starts += 1)
	await settle()
	check(menu.cards.size() == 10 and menu.gallery_grid.columns == 5, "Nine disciplines and Records in a five-by-two gallery")
	var order: Array[String] = []
	for card in menu.gallery_grid.get_children(): order.append(String(card.name))
	check(order == ["scratch", "pursuit", "team_pursuit", "points", "elimination", "madison", "keirin", "time_trial", "tempo", "records"], "Visual order matches the approved mockup without changing existing race IDs")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		var bounds := root.get_visible_rect()
		for card in menu.cards:
			check(bounds.encloses(card.get_global_rect()), "Every tile fits at %s" % resolution)
		for i in range(10):
			for j in range(i + 1, 10): check(not menu.cards[i].get_global_rect().intersects(menu.cards[j].get_global_rect()), "Gallery cards do not overlap")
	for index in [7,8]:
		menu.cards[index].pressed.emit()
		await settle()
		check(menu.page == 2 and menu.start_button.disabled, "Future discipline opens an informative unavailable page")
		check(not menu.race_settings.visible and not menu.demo_settings.visible, "Future discipline hides active race inputs")
		menu.start_button.pressed.emit()
		menu.update_bridge_status(true,true,false)
		check(menu.start_button.disabled and starts == 0, "Trainer status cannot enable an unimplemented discipline")
		menu.bridge_action("B")
		check(menu.page == 1, "Bridge back works from future disciplines")
	menu.update_bridge_status(false,false,false)
	menu.records_store.path = "user://menu_theme_layout_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.records_store.path))
	menu.show_records()
	for i in range(10):
		menu.records_store.add({"id":"layout_%d"%i,"mode":4,"distance_m":1000,"team_size":0,"seconds":60.0+i,"player_name":"Een lange voorbeeldnaam","finished_at":1793520000.0+i,"finished_local":"01/11/2026 10:24"})
	menu.records_page.refresh()
	await settle()
	var page = menu.records_page
	check(page.shown.size() == 10, "Records show ten completed performances")
	check(page.rows.size.y <= page.rows.get_parent().size.y + .1, "All ten records fit without vertical scrolling")
	page.mode_buttons[1].pressed.emit()
	check(page.size_box.visible and page.mode_choice.get_selected_id() == 5 and page.mode_buttons[1].button_pressed, "Team tab updates model, selection and squad-size filter")
	page.distance_buttons[1].pressed.emit()
	check(page.distance_choice.get_selected_id() == 4000 and page.distance_buttons[1].button_pressed, "Distance tab updates the actual record category")
	page.mode_buttons[0].pressed.emit()
	check(not page.size_box.visible, "Individual pursuit hides squad size")
	page.back_button.pressed.emit()
	check(menu.page == 1, "Records returns to gallery")
	menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://menu_theme_layout_test.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://menu_theme_layout_test.json.bak"))
	print("MENU_THEME failures=", failures)
	quit(0 if failures == 0 else 1)
