extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
var game
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func raw(button: String, down: bool) -> void:
	game._process_bridge_packet({"type":"controller_button", "source_button":button, "pressed":down})
func race() -> void:
	game._set_menu_visible(false)
	game.start_state = "RACING"
	game.running = true
	game.finished = false
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var mapping = game.ride_mapping
	mapping.reset()
	check(mapping.assign("race", "look_back", "A", "hold").is_empty(), "Assign rear view to A")
	race()
	var original_camera: int = game.camera_mode
	game._process_bridge_packet({"type":"button", "source_button":"UP", "button":"UP", "pressed":false})
	check(game.camera_mode == original_camera, "Legacy release cannot trigger a configured press action")
	raw("A", true)
	check(game.look_back_held, "Raw A starts mapped hold without legacy packet")
	game._process_bridge_packet({"type":"button", "source_button":"A", "button":"Z"})
	check(not game.race_paused, "Legacy copy cannot pause or double-trigger")
	raw("A", false)
	check(not game.look_back_held, "Mapped hold releases")
	check(mapping.assign("race", "camera_next", "DROP_LEFT", "release").is_empty(), "Assign drop release")
	var camera: int = game.camera_mode
	raw("POWER_LEFT", true)
	check(game.camera_mode == camera, "Release binding does nothing on press")
	raw("POWER_LEFT", false)
	check(game.camera_mode == posmod(camera + 1, 4), "Release action routes from physical identity")
	raw("POWER_LEFT", false)
	check(game.camera_mode == posmod(camera + 1, 4), "Duplicate release ignored")
	raw("A", true)
	game._process_bridge_packet({"type":"controller_connection", "connected":false})
	check(not game.look_back_held, "Disconnect terminates remapped hold")
	raw("A", true)
	game._process_bridge_packet({"type":"controller_connection", "connected":true, "buttons":[]})
	check(not game.look_back_held, "Heartbeat repairs remapped hold")
	raw("A", true)
	game._expire_bridge_optional_fields(game.last_controller_signal + 2.1)
	check(not game.look_back_held, "Silence terminates remapped hold")
	var settings = game.get_node("GameSettings")
	raw("A", true)
	settings.toggle_menu()
	check(not game.look_back_held, "Opening settings terminates hold")
	settings.appearance_tabs.current_tab = settings.controller_test.get_index()
	await process_frame
	var editor = settings.controller_test
	editor.context_choice.select(1)
	editor._populate_actions()
	editor.action_choice.select(mapping.ACTIONS.race.keys().find("rider_info"))
	editor._refresh_trigger()
	editor.begin_capture()
	raw("ONOFF_LEFT", true)
	check(editor.candidate == "ONOFF_LEFT", "UI captures previously unmapped physical button")
	raw("ONOFF_LEFT", false)
	editor.confirm_mapping()
	check(mapping.action_for("race", "ONOFF_LEFT") == "rider_info", "UI confirms mapping")
	var fresh = load("res://ride_mapping.gd").new()
	fresh.load_settings()
	check(fresh.profiles == mapping.profiles, "Confirmed UI mapping survives reload")
	editor.begin_capture()
	raw("Z", true)
	check(settings.controller_test_active() and editor.candidate == "Z", "Capture consumes Z instead of leaving diagnostics")
	raw("Z", false)
	editor.confirm_mapping()
	check(editor.mapping_status.text.contains("Conflict") and mapping.action_for("race", "Z") == "pause", "UI rejects collisions without replacing pause")
	editor.cancel_capture()
	editor.begin_capture()
	settings.appearance_tabs.current_tab = 0
	await process_frame
	check(not editor.capturing and editor.candidate.is_empty(), "Tab change cancels capture")
	settings._close_settings()
	game.race_paused = false
	game.exit_menu.cancel_or_resume()
	race()
	var names: int = game.rider_name_mode
	raw("ONOFF_LEFT", true)
	raw("ONOFF_LEFT", true)
	check(game.rider_name_mode != names, "Saved mapping works immediately")
	raw("ONOFF_LEFT", false)
	camera = game.camera_mode
	raw("POWER_LEFT", true)
	settings.toggle_menu()
	raw("POWER_LEFT", false)
	check(game.camera_mode == camera, "Release cannot cross contexts")
	settings._close_settings()
	game.race_paused = false
	race()
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	game._unhandled_key_input(key)
	raw("A", true)
	raw("A", false)
	check(game.look_back_held, "Controller release preserves keyboard fallback hold")
	key.pressed = false
	game._input(key)
	check(not game.look_back_held, "Keyboard fallback releases normally")
	DirAccess.remove_absolute(mapping.PATH)
	game.free()
	await process_frame
	print("RIDE_MAPPING_ROUTING_OK failures=%d" % failures)
	quit(0 if failures == 0 else 1)
