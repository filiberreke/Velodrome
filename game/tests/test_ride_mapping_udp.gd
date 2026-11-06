extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(int(OS.get_cmdline_user_args()[0]))
	func _save_recording(_reason: String) -> void: pass
var game
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_for(marker: String, condition: Callable) -> void:
	print("RIDE_MAP_" + marker)
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		game._read_bridge()
		await process_frame
	check(condition.call(), "Simulator flow: " + marker)
func run_test() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.trainer_control.port = int(OS.get_cmdline_user_args()[1])
	game.ride_mapping.reset()
	var settings = game.get_node("GameSettings")
	settings.toggle_menu()
	settings.appearance_tabs.current_tab = settings.controller_test.get_index()
	await process_frame
	var editor = settings.controller_test
	editor.context_choice.select(1)
	editor._populate_actions()
	editor.action_choice.select(game.ride_mapping.ACTIONS.race.keys().find("rider_info"))
	editor._refresh_trigger()
	editor.trigger_choice.select(1)
	editor.begin_capture()
	await wait_for("CAPTURE", func(): return editor.candidate == "POWER_LEFT")
	check(settings.controller_test_active(), "Capture stays in safe test context")
	editor.confirm_mapping()
	check(game.ride_mapping.action_for("race", "POWER_LEFT") == "rider_info", "Simulator assignment confirmed")
	game.ride_mapping.assign("race", "look_back", "A", "hold")
	settings._close_settings()
	game._set_menu_visible(false)
	game.start_state = "RACING"
	game.running = true
	game.finished = false
	await wait_for("LOOK_DOWN", func(): return game.look_back_held)
	await wait_for("LOOK_UP", func(): return not game.look_back_held)
	var names: int = game.rider_name_mode
	await wait_for("INFO_DOWN", func(): return game.ride_buttons.has("POWER_LEFT"))
	check(game.rider_name_mode == names, "Release action waits while held")
	await wait_for("INFO_UP", func(): return not game.ride_buttons.has("POWER_LEFT"))
	check(game.rider_name_mode == (names + 1) % 3, "Simulator release dispatches exactly once")
	DirAccess.remove_absolute(game.ride_mapping.PATH)
	game.free()
	await process_frame
	print("VIRTUAL_BRIDGE_OK RIDE_MAPPING_UDP failures=%d" % failures)
	quit(0 if failures == 0 else 1)
