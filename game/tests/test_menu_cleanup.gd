extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0

func _initialize() -> void: call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(3): await process_frame

func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var menu = game.setup_panel
	await check_keyboard_navigation(game)
	menu.show_choices()
	await settle()
	check(visible_back_buttons(menu) == 1, "Gallery exposes one header back action")
	check(menu.races_back.get_global_rect().end.y <= menu.gallery_grid.get_global_rect().position.y, "Back action stays above the gallery")
	menu.races_back.pressed.emit()
	check(menu.page == 0 and visible_back_buttons(menu) == 0, "Header back returns home and disappears there")
	for method in ["show_ftp", "show_workout_editor", "show_derny", "show_madison_training", "show_tournaments", "show_training_history", "show_records"]:
		menu.call(method)
		await settle()
		check(visible_back_buttons(menu) == 1, "Only the active screen's back action is visible: " + method)
	menu.show_derny()
	check(menu.derny_page.derny_motor_button.button_pressed, "Current derny remains selected")
	check(not menu.derny_page.derny_motor_button.button_group.allow_unpress, "Clicking the selected derny cannot clear the only available choice")
	check(menu.derny_page.heavy_motor_button.disabled, "Reserved heavy motor cannot start an unimplemented mode")
	menu.select_mode(0)
	menu.show_startlist()
	await settle()
	menu.startlist_page.previous_button.grab_focus()
	menu.startlist_page.bridge_action("A")
	await settle()
	check(menu.page == 2 and game.start_state == "SETUP", "Ride A on the relocated back button returns to settings rather than starting a race")
	var settings = game.get_node("GameSettings")
	settings.toggle_menu()
	await settle()
	check(root.get_visible_rect().encloses(settings.close_button.get_global_rect()), "Settings back remains in view")
	check(settings.close_button.get_global_rect().position.y < settings.appearance_tabs.get_global_rect().position.y, "Settings back stays above the tabs")
	settings._close_settings()
	var authorization = game.strava_client._build_authorization_dialog()
	authorization.popup_centered(Vector2i(800, 400))
	await settle()
	var instructions: Label = authorization.get_child(0).get_child(0)
	var callback_input: LineEdit = authorization.get_child(0).get_child(1)
	check(instructions.text.contains("config/strava_config.cfg"), "Authorization explains the configuration prerequisite")
	check(not instructions.get_rect().intersects(callback_input.get_rect()), "Callback field cannot cover the authorization instructions")
	check(authorization.size.y <= root.get_visible_rect().size.y, "Authorization dialog fits the screen")
	authorization.free()
	game.free()
	print("MENU_CLEANUP failures=", failures)
	quit(0 if failures == 0 else 1)

func visible_back_buttons(menu: Control) -> int:
	var count := 0
	for child in menu.page_header.get_children():
		if child is Button and child.is_visible_in_tree(): count += 1
	return count

func menu_key(menu: Control, code: int, down: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	event.echo = echo
	menu._unhandled_key_input(event)

func check_keyboard_navigation(game: Node) -> void:
	var menu = game.setup_panel
	check(menu.get_parent() is CanvasLayer, "Regression uses the real CanvasLayer menu parent")
	check(menu.keyboard_mapping == game.keyboard_mapping, "Menu shares the game keyboard mapping")
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.apply_ui()
	menu.show_choices()
	await settle()
	var before: Control = root.gui_get_focus_owner()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_RIGHT
		event.pressed = down
		root.push_input(event)
	await settle()
	check(root.gui_get_focus_owner() != before and menu.is_ancestor_of(root.gui_get_focus_owner()), "Real arrow input moves focus inside the menu")
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_F9]:
		menu.show_choices()
		menu_key(menu, code)
		check(menu.page == 1, "Unhandled arrow/unmapped key preserves gallery: %d" % code)
	for page in [1, 2, 3, 5]:
		if page == 1: menu.show_choices()
		elif page == 2: menu.select_mode(0)
		elif page == 3: menu.show_records()
		else: menu.select_mode(0); menu.show_startlist()
		menu_key(menu, KEY_UP)
		check(menu.page == page, "Unhandled arrow preserves page %d" % page)
		menu_key(menu, KEY_ESCAPE)
		check(menu.page == (0 if page == 1 else 2 if page == 5 else 1), "Back navigates from page %d" % page)
	menu.show_choices()
	check(game.keyboard_mapping.assign("menu", "back", KEY_F8).is_empty(), "Back can be rebound")
	menu_key(menu, KEY_ESCAPE)
	check(menu.page == 1, "Previous back binding no longer navigates")
	menu_key(menu, KEY_F8, false)
	menu_key(menu, KEY_F8, true, true)
	check(menu.page == 1, "Key release and echo do not navigate")
	menu_key(menu, KEY_F8)
	check(menu.page == 0, "Menu uses the live rebound back binding")
	menu.show_choices()
	game.keyboard_mapping.enabled = false
	menu_key(menu, KEY_F8)
	menu_key(menu, KEY_DOWN)
	check(menu.page == 1, "Disabled keyboard mapping leaves menu unchanged")
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.assign("menu", "back", KEY_ESCAPE)
	game.keyboard_mapping.apply_ui()
	await settle()
