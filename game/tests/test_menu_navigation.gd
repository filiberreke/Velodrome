extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
var game: Game
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(4): await process_frame
func tap(code: int, shift: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = down
		root.push_input(event)
	await settle()
func expect_move(source: Control, code: int, destination: Control, message: String, shift: bool = false) -> void:
	source.grab_focus()
	await tap(code, shift)
	var actual := root.gui_get_focus_owner()
	check(actual == destination, message + " (actual: " + str(actual.get_path() if actual != null else "none") + ")")
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/velodrome-preview/" + name + ".png")
func run_test() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	game.bridge_devices.close_page()
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.apply_ui()
	var menu = game.setup_panel
	menu.show_choices()
	await settle()
	await expect_move(menu.cards[0], KEY_RIGHT, menu.cards[1], "Race gallery: right follows visible columns")
	await expect_move(menu.cards[1], KEY_DOWN, menu.cards[6], "Race gallery: down keeps the same column")
	await expect_move(menu.cards[6], KEY_UP, menu.cards[1], "Race gallery: up returns to the same column")
	await expect_move(menu.cards[5], KEY_RIGHT, menu.cards[5], "Race gallery: right edge never jumps to another row")
	await expect_move(menu.cards[0], KEY_UP, menu.races_back, "Race gallery: up reaches the relocated back button")
	await expect_move(menu.races_back, KEY_TAB, menu.cards[0], "Tab follows the visible header before the gallery")
	await expect_move(menu.cards[5], KEY_TAB, menu.cards[4], "Tab follows display order, not mode IDs")
	await expect_move(menu.cards[0], KEY_TAB, menu.races_back, "Shift Tab returns to the visible back button", true)
	check(game.keyboard_mapping.assign("menu", "right", KEY_F6).is_empty(), "Right can be rebound")
	await expect_move(menu.cards[0], KEY_F6, menu.cards[1], "Rebound key moves exactly one column")
	game.keyboard_mapping.assign("menu", "right", KEY_RIGHT)
	game.keyboard_mapping.apply_ui()
	menu.cards[0].grab_focus()
	game._ride_action("RIGHT")
	check(root.gui_get_focus_owner() == menu.cards[1], "Controller and keyboard share the same focus order")
	menu.show_piste_training()
	await settle()
	await expect_move(menu.piste_tiles.free_ride, KEY_RIGHT, menu.piste_tiles.derny, "Piste: horizontal row")
	await expect_move(menu.piste_tiles.derny, KEY_DOWN, menu.piste_tiles.madison, "Piste: down stays in column")
	await expect_move(menu.piste_tiles.madison, KEY_UP, menu.piste_tiles.derny, "Piste: vertical navigation is reversible")
	await capture("44-piste-toetsenbordfocus")
	menu.show_derny()
	await settle()
	var derny = menu.derny_page
	check(root.gui_get_focus_owner() == derny.derny_motor_button, "Derny opens at the motor choice")
	await expect_move(derny.derny_motor_button, KEY_RIGHT, derny.derny_motor_button, "Unavailable heavy motor is skipped")
	await expect_move(derny.derny_motor_button, KEY_DOWN, derny.start_speed.get_line_edit(), "Derny: down reaches speed")
	var speed: float = derny.start_speed.value
	await expect_move(derny.start_speed.get_line_edit(), KEY_DOWN, derny.start_button, "Speed: down navigates to start")
	check(derny.start_speed.value == speed, "Down navigates without changing speed")
	derny.start_speed.get_line_edit().grab_focus()
	await capture("45-derny-toetsenbordfocus")
	await expect_move(derny.start_speed.get_line_edit(), KEY_RIGHT, derny.start_speed.get_line_edit(), "Speed: right keeps focus while editing")
	check(derny.start_speed.value == speed + derny.start_speed.step, "Right adjusts speed")
	menu.show_madison_training()
	await settle()
	check(root.gui_get_focus_owner() == menu.madison_page.difficulty, "Madison opens at difficulty, before start")
	await expect_move(menu.madison_page.difficulty, KEY_DOWN, menu.madison_page.count, "Madison: difficulty then attempts")
	menu.show_piste_exercise("take_lap")
	await settle()
	check(root.gui_get_focus_owner() == menu.exercise_page.tempo_input.get_line_edit(), "Lap exercise opens at tempo")
	await expect_move(menu.exercise_page.tempo_input.get_line_edit(), KEY_DOWN, menu.exercise_page.limit_input.get_line_edit(), "Lap exercise: tempo then time limit")
	var settings = game.get_node("GameSettings")
	settings.toggle_menu()
	await settle()
	settings.appearance_tabs.current_tab = 0
	await settle()
	await expect_move(settings.rider_name_input, KEY_DOWN, settings.rider_weight_input.get_line_edit(), "Settings: name then weight")
	await expect_move(settings.rider_weight_input.get_line_edit(), KEY_DOWN, settings.rider_ftp_input.get_line_edit(), "Settings: weight then FTP")
	await expect_move(settings.rider_ftp_input.get_line_edit(), KEY_UP, settings.rider_weight_input.get_line_edit(), "Settings: up reverses the visual order")
	await capture("46-instellingen-toetsenbordfocus")
	settings._close_settings()
	# Every visible menu participates in one Tab cycle, including dynamically
	# reparented controls, while disabled and hidden controls remain unreachable.
	for method in ["show_hub", "show_choices", "show_training", "show_workout_editor", "show_derny", "show_madison_training", "show_tournaments", "show_training_history", "show_records"]:
		menu.call(method)
		await settle()
		var items: Array[Control] = game.ride_navigation.controls(menu)
		check(not items.is_empty(), "Focusable controls on " + method)
		items[0].grab_focus()
		var visited := {}
		for i in range(items.size()):
			var focused := root.gui_get_focus_owner()
			check(focused != null and focused.is_visible_in_tree() and items.has(focused), "Tab stays in active page: " + method)
			if focused != null: visited[focused.get_instance_id()] = true
			await tap(KEY_TAB)
		check(visited.size() == items.size(), "Tab visits every control once: " + method)
	# Scrolling must reveal the focused item without changing the Tab order.
	var scope := Control.new()
	root.add_child(scope)
	var header := Button.new()
	header.position = Vector2(0, 0); header.size = Vector2(200, 40)
	scope.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 60); scroll.size = Vector2(200, 120)
	scope.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for i in range(12):
		var button := Button.new()
		button.text = "Row %d" % i
		button.custom_minimum_size = Vector2(180, 45)
		rows.add_child(button)
	await settle()
	game.ride_navigation.refresh_focus(scope)
	var first := rows.get_child(0) as Button
	var last := rows.get_child(11) as Button
	check(header.get_node(header.focus_next) == first, "Scroll list starts after its header")
	last.grab_focus()
	await settle()
	check(scroll.scroll_vertical > 0, "Offscreen focus scrolls into view")
	game.ride_navigation.refresh_focus(scope)
	check(header.get_node(header.focus_next) == first and last.get_node(last.focus_next) == header, "Scrolling preserves Tab order")
	scope.free()
	game.free()
	print("MENU_NAVIGATION failures=", failures)
	quit(0 if failures == 0 else 1)
