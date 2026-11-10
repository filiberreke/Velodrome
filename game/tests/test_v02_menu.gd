extends SceneTree
const Menu := preload("res://race_menu.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func run_test() -> void:
	root.size = Vector2i(1920, 1080)
	var menu := Menu.new()
	root.add_child(menu)
	await settle()
	check(menu.page == 0 and menu.hub_page.visible and not menu.choice_page.visible, "Higher-level menu opens first")
	for button in menu.hub_page.get_children():
		check(root.get_visible_rect().encloses(button.get_global_rect()), "Main menu button fits screen")
	menu.hub_button.pressed.emit()
	await settle()
	check(menu.page == 1 and menu.choice_page.visible and not menu.hub_page.visible, "Races retain original gallery")
	check(menu.MODES.size() == 10 and menu.PLAYABLE == [0, 1, 2, 3, 5, 6, 7], "Existing race IDs preserved; keirin enabled")
	for card in menu.cards:
		check(root.get_visible_rect().encloses(card.get_global_rect()), "Existing race card fits with new back button")
	menu.select_mode(0)
	menu.count_input.value = 10
	menu.laps_input.value = 12
	menu.bridge_action("B")
	menu.bridge_action("B")
	check(menu.page == 0, "Controller returns from races to main menu")
	menu.show_training()
	check(menu.page == 6 and menu.training_page.visible, "Training category opens")
	menu.ftp_tile.pressed.emit()
	await settle()
	check(menu.page == 8 and menu.ftp_page.visible and menu.ftp_page.start_button.disabled, "FTP test requires real power signal")
	for button in [menu.ftp_page.start_button, menu.ftp_page.back_button]:
		check(root.get_visible_rect().encloses(button.get_global_rect()), "Training controls fit screen")
	menu.bridge_action("B")
	check(menu.page == 6, "Controller back leaves FTP safely")
	menu.bridge_action("B")
	menu.show_tournaments()
	check(menu.page == 7 and menu.tournament_page.visible, "Tournament placeholder has its own page")
	menu.bridge_action("B")
	menu.show_choices()
	menu.select_mode(0)
	check(menu.count_input.value == 10 and menu.laps_input.value == 12, "Category navigation preserves race settings")
	menu.free()
	print("V02_MENU failures=", failures)
	quit(0 if failures == 0 else 1)
