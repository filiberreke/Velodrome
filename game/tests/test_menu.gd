extends SceneTree
const Game := preload("res://main.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var menu = game.setup_panel
	check(menu.visible and menu.page == 1, "Opening screen is mode gallery")
	check(menu.cards.size() == 7 and menu.previews.size() == 7, "Six mode cards plus Records tile")
	var expected := ["Scratch", "Achtervolging", "Ploegenachtervolging", "Puntenkoers", "Ploegkoers", "Keirin"]
	for i in range(6):
		check(menu.MODES[i]["title"] == expected[i], "Requested card order")
		check(menu.previews[i].own_world_3d, "Preview isolated from stadium and racing world")
		var bounds: Rect2 = menu.cards[i].get_global_rect()
		check(bounds.size.x > 300 and bounds.size.y >= 300, "Card has room for illustration and text")
		check(bounds.end.x <= 1920.1 and bounds.end.y <= 1080.1, "Card fits reference screen")
	for item in game.race_hud_items:
		check(not item.visible, "Race HUD hidden in gallery")
	for bike in game.bikes:
		check(not bike.visible, "No racers on background track")
	var people := get_nodes_in_group("stadium_people")
	check(people.size() > 0, "Stadium crowd is available for race restoration")
	for person in people:
		check(not person.visible, "Stadium empty in menus")
	for index in range(3, 6):
		menu.cards[index].pressed.emit()
		check(menu.page == 2 and menu.settings_page.visible and not menu.choice_page.visible, "Card opens second menu")
		check(menu.start_button.disabled and not menu.race_settings.visible, "Unimplemented mode cannot start")
		game._confirm_start()
		check(game.start_state == "SETUP", "Unsupported mode does not start a scratch by mistake")
		menu.back_button.pressed.emit()
		check(menu.page == 1, "Back returns to gallery")
	menu.cards[0].pressed.emit()
	check(menu.race_settings.visible and not menu.start_button.disabled, "Scratch settings available")
	menu.count_input.value = 10
	menu.laps_input.value = 12
	menu.difficulty_slider.value = 70
	menu.demo_power_input.value = 350
	menu.back_button.pressed.emit()
	menu.cards[0].pressed.emit()
	check(menu.count_input.value == 10 and menu.laps_input.value == 12, "Back preserves configured values")
	await process_frame
	await process_frame
	check(menu.start_button.get_global_rect().end.y <= 1080.1, "Settings navigation fits screen")
	menu.start_button.pressed.emit()
	check(not menu.visible and game.start_state == "WAIT_STOP", "Start opens existing trainer/countdown flow")
	check(game.rider_count == 10 and game.race_laps == 12 and game.ai_difficulty == 70, "Selected race values passed through")
	check(game.demo_launch_watts == 350, "Demo power preset remains configurable")
	check(game.race_overlay.visible and not game.race_overlay.developer_panel.visible and not game.result_panel.visible, "Only compact race HUD restored on start")
	for bike in game.bikes:
		check(bike.visible, "Riders restored on start")
	for person in people:
		if person.name != "Vlagdame":
			check(person.visible, "Spectators and infield people restored on start")
	game._reset()
	check(menu.visible and menu.page == 1 and not game.race_overlay.visible, "Reset returns to clean gallery")
	game.free()
	print("MENU_FLOW_OK" if failures == 0 else "MENU_FLOW_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
