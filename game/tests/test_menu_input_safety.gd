extends SceneTree

class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _quit_application() -> void: pass
	func _confirm_start() -> void: pass

var game: Game
var failures := 0
var events := 0
var screens := 0
var control_checks := 0
var accepts := 0
const NAV_KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB]

func _initialize() -> void: call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(4): await process_frame

func tap(code: int, shift: bool = false, echo: bool = false, modifiers: int = 0) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		event.shift_pressed = shift
		event.ctrl_pressed = bool(modifiers & 1)
		event.alt_pressed = bool(modifiers & 2)
		event.meta_pressed = bool(modifiers & 4)
		event.echo = echo and down
		root.push_input(event)
		events += 1
	await process_frame

func run_test() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	game.bridge_devices.close_page()
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.apply_ui()
	var menu = game.setup_panel
	menu.training_store.folder = "user://menu_input_safety_history"
	var saved := {"version":1,"id":"input-safety-derny","kind":"derny","title":"Test Derny","samples":[{"time_s":0,"power_w":180},{"time_s":60,"power_w":220}],"duration_s":60,"final":true}
	check(menu.training_store.save(saved), "Save history fixture")
	menu.show_piste_training()
	menu.show_training_history()
	menu.training_history_page.rows.get_child(0).pressed.emit()
	await settle()
	root.gui_release_focus()
	await tap(KEY_UP)
	check(root.gui_get_focus_owner() != null, "History result recovers focus on Up")
	if "--regression-only" not in OS.get_cmdline_user_args():
		await sweep_all_screens()
	game.free()
	print("MENU_INPUT_SAFETY failures=", failures, " screens=", screens, " controls=", control_checks, " accepts=", accepts, " events=", events)
	quit(0 if failures == 0 else 1)

# Open each state independently, so a back/accept key cannot accidentally make
# the rest of the sweep test a different screen. All user data is test-local.
func open_screen(name: String) -> Control:
	var menu = game.setup_panel
	var settings = game.get_node("GameSettings")
	game.keyboard_mapping.profiles = preload("res://keyboard_mapping.gd").DEFAULT_KEYS.duplicate(true)
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.apply_ui()
	if game.piste_training != null and game.piste_training.active: game.piste_training.page.leave()
	if is_instance_valid(game.ride_navigation.keyboard): game.ride_navigation.close_keyboard(false)
	settings._close_settings()
	game.bridge_devices.close_page()
	game.race_paused = false
	game.finished = false
	game.finish_overlay.hide()
	game.exit_menu.hide_pause()
	menu.show()
	menu.show_hub()
	if name.begins_with("mode_"):
		menu.select_mode(int(name.get_slice("_", 1)))
	elif name.begins_with("startlist_"):
		menu.select_mode(int(name.get_slice("_", 1)))
		menu.show_startlist()
	elif name.begins_with("opponent_"):
		menu.select_mode(int(name.get_slice("_", 1)))
		menu.pursuit_flow.next_step()
	elif name.begins_with("exercise_"):
		menu.show_piste_exercise(name.trim_prefix("exercise_"))
	elif name.begins_with("history_"):
		var kind := name.trim_prefix("history_")
		var saved := {"kind":kind,"samples":[{"time_s":0,"power_w":180},{"time_s":60,"power_w":220}],"final":true}
		if kind == "derny": menu.show_derny(); menu.derny_page.show_activity(saved)
		elif kind == "madison": menu.show_madison_training(); menu.madison_page.show_activity(saved)
		else: menu.show_piste_exercise(kind); menu.exercise_page.show_activity(saved)
	elif name.begins_with("settings_"):
		settings.toggle_menu()
		settings.appearance_tabs.current_tab = int(name.get_slice("_", 1))
	elif name == "devices": game.bridge_devices.open_page()
	elif name == "pause": game.race_paused = true; game.exit_menu.show_pause()
	elif name == "quit": game.exit_menu.show_quit()
	elif name == "results": menu.hide(); game.finished = true; game.finish_overlay.show()
	elif name == "workout":
		menu.workout_play_page.load_workout({"id":"input-safety","name":"Input safety","blocks":[{"kind":"SteadyState","duration":60.0,"power_low":0.6,"power_high":0.6}]})
		menu._show_section(14, "Input safety", menu.workout_play_page)
	elif name == "keyboard":
		settings.toggle_menu()
		game.ride_navigation.open_keyboard(settings.rider_name_input)
	else: menu.call(name)
	await settle()
	game.ride_navigation.refresh_focus()
	return game.ride_navigation.active_scope()

func sweep_screen(name: String) -> void:
	var scope := await open_screen(name)
	check(scope != null, "Active scope: " + name)
	if scope == null: return
	screens += 1
	var items: Array[Control] = game.ride_navigation.controls(scope)
	check(not items.is_empty(), "Focusable controls: " + name)
	for source in items:
		for code in NAV_KEYS + [KEY_TAB]:
			if not is_instance_valid(source) or not source.is_visible_in_tree(): continue
			source.grab_focus()
			await tap(code, code == KEY_TAB and control_checks % 2 == 0)
			control_checks += 1
			var focused := root.gui_get_focus_owner()
			check(focused != null and focused.is_visible_in_tree(), "Navigation keeps visible focus: " + name)
	# Recovery from no focus was the original crash path. Test every direction
	# both as a keyboard event and as the physical controller's routed action.
	for code in NAV_KEYS:
		root.gui_release_focus()
		await tap(code)
	for token in ["UP", "DOWN", "LEFT", "RIGHT", "UNKNOWN"]:
		root.gui_release_focus()
		game._ride_action(token)
		await process_frame
	# Exercise printable keys, the special-key range (including function keys,
	# keypad, Home/End/PageUp/PageDown/Delete), release, repeats and modifiers.
	# Action keys are tested separately, since they intentionally leave a page.
	var codes: Array = range(KEY_SPACE, KEY_ASCIITILDE + 1)
	codes.append_array(range(KEY_SPECIAL, KEY_SPECIAL + 256))
	for code in codes:
		if code in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_F10]: continue
		if is_instance_valid(scope) and scope.is_visible_in_tree():
			var current: Array[Control] = game.ride_navigation.controls(scope)
			if not current.is_empty(): current[0].grab_focus()
		await tap(code)
		await tap(code, false, true)
		await tap(code, true)
	for modifiers in range(1, 8):
		for code in NAV_KEYS + [KEY_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_F10, KEY_A, KEY_DELETE]:
			await tap(code, false, false, modifiers)
	# Back, settings, and accept are real input events too. Confirm on the
	# relocated Back button rather than starting sessions or external uploads.
	scope = await open_screen(name)
	var current: Array[Control] = game.ride_navigation.controls(scope)
	for item in current:
		if item is Button and ("←" in item.text or item.text in ["Terug", "Annuleren", "Hervatten"]):
			item.grab_focus()
			await tap(KEY_ENTER)
			break
	await open_screen(name)
	await tap(KEY_ESCAPE)
	await open_screen(name)
	await tap(KEY_F10)
	await tap(KEY_F10)
	print("INPUT_SCREEN ", name, " controls=", items.size(), " events=", events)
	await check_accepts(name)

func close_dialogs(node: Node) -> void:
	for child in node.get_children():
		if child is Window: child.hide()
		else: close_dialogs(child)

func check_accepts(name: String) -> void:
	var scope := await open_screen(name)
	var items: Array[Control] = game.ride_navigation.controls(scope)
	for index in range(items.size()):
		scope = await open_screen(name)
		var current: Array[Control] = game.ride_navigation.controls(scope)
		if index >= current.size(): continue
		var source := current[index]
		# Exercise UI activation without opening an external browser or uploading
		# user content. Race starts and application exit are stubbed above.
		if source is Button and ("Strava" in source.text or "Upload" in source.text):
			for connection in source.get_signal_connection_list("pressed"):
				source.disconnect("pressed", connection.callable)
		source.grab_focus()
		await tap(KEY_ENTER)
		await settle()
		accepts += 1
		close_dialogs(game)
	print("INPUT_ACCEPT ", name, " total=", accepts)

func sweep_all_screens() -> void:
	for method in ["show_hub", "show_choices", "show_training", "show_piste_training", "show_workout_editor", "show_ftp", "show_derny", "show_madison_training", "show_training_history", "show_tournaments", "show_records"]:
		await sweep_screen(method)
	for mode in range(8):
		await sweep_screen("mode_%d" % mode)
	for mode in [0, 3, 5, 6]: await sweep_screen("startlist_%d" % mode)
	for mode in [1, 2]: await sweep_screen("opponent_%d" % mode)
	for kind in ["free_ride", "flying_start", "take_lap"]:
		await sweep_screen("exercise_" + kind)
	for kind in ["derny", "madison", "free_ride", "flying_start", "take_lap"]:
		await sweep_screen("history_" + kind)
	var settings = game.get_node("GameSettings")
	for tab in range(settings.appearance_tabs.get_tab_count()):
		await sweep_screen("settings_%d" % tab)
	for name in ["workout", "devices", "pause", "quit", "results", "keyboard"]: await sweep_screen(name)
