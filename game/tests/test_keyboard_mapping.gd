extends SceneTree
const Mapping := preload("res://keyboard_mapping.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
var game
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: int, down: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	event.echo = echo
	game._input(event)
func tap(code: int) -> void:
	key(code)
	key(code, false)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var mapping := Mapping.new()
	check(mapping.validate(mapping.profiles).is_empty(), "Defaults are valid")
	check(mapping.profiles.race.shift_up == KEY_UP and mapping.profiles.simulator.power_up == KEY_UP, "Distinct trainer/simulator defaults")
	check(not mapping.assign("race","camera_next",KEY_UP).is_empty(), "Same-context conflict rejected")
	check(mapping.assign("race","camera_next",KEY_H | KEY_MASK_CTRL).is_empty(), "Modifier shortcut accepted")
	check(not mapping.assign("global","settings",KEY_UP).is_empty(), "Global conflicts rejected")
	check(mapping.assign("menu","up",KEY_I).is_empty(), "Menu keys can be reassigned")
	mapping.apply_ui()
	var old_up := InputEventKey.new(); old_up.keycode = KEY_UP
	var new_up := InputEventKey.new(); new_up.keycode = KEY_I
	check(not InputMap.event_is_action(old_up,"ui_up") and InputMap.event_is_action(new_up,"ui_up"), "Native menus use new mapping instead of old arrows")
	check(mapping.save("user://keyboard_test.json") == OK, "Mapping saved")
	var reloaded := Mapping.new()
	reloaded.load_settings("user://keyboard_test.json")
	check(int(reloaded.profiles.race.camera_next) == KEY_H | KEY_MASK_CTRL, "Mapping survives reload")
	var file := FileAccess.open("user://keyboard_test.json",FileAccess.WRITE)
	file.store_string("invalid")
	file.close()
	reloaded.load_settings("user://keyboard_test.json")
	check(reloaded.profiles.race.camera_next == KEY_C and not reloaded.status.is_empty(), "Corrupt mapping falls back")
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.keyboard_mapping.profiles = Mapping.DEFAULT_KEYS.duplicate(true)
	game.keyboard_mapping.enabled = true
	game.keyboard_mapping.apply_ui()
	game.bridge_devices.panel_root.hide()
	game._set_menu_visible(false)
	game.start_state = "RACING"
	game.running = true
	game.finished = false
	game.trainer_seen = false
	game.connected = false
	game.watts = 100
	tap(KEY_UP)
	check(game.watts == 125, "No trainer: Up increases simulated power")
	game.trainer_seen = true
	game.connected = true
	var server := PacketPeerUDP.new()
	check(server.bind(0,"127.0.0.1") == OK, "Loopback gear receiver")
	game.trainer_control.port = server.get_local_port()
	game.trainer_control.armed = true
	game.trainer_control.enabled_before = true
	game.trainer_control.phase = "ACTIVE"
	game.trainer_control.state = {"desired_mode":"SIM"}
	tap(KEY_UP)
	await process_frame
	check(game.watts == 125, "Trainer: Up never changes simulated power")
	check(server.get_available_packet_count() == 1, "Trainer: one gear command sent")
	if server.get_available_packet_count() > 0:
		var packet: Dictionary = JSON.parse_string(server.get_packet().get_string_from_utf8())
		check(packet.command == "shift" and packet.direction == 1, "Up requests heavier gear")
	var client = game.trainer_control
	var request_id: String = client.requests.keys()[0]
	client.handle_response({"type":"error","v":1,"id":request_id,"ok":false,"code":"unknown_command","message":"test: oude bridge"}, game._now_s())
	check(client.phase == "ACTIVE" and client.armed, "An older bridge refusal does not block the active trainer")
	game.connected = false
	tap(KEY_UP)
	check(game.watts == 125 and game._keyboard_profile() == "race", "Trainer dropout cannot activate simulator power")
	game.connected = true
	var camera: int = game.camera_mode
	tap(KEY_C)
	check(game.camera_mode == posmod(camera+1,4), "Default camera shortcut")
	game.keyboard_mapping.assign("race","camera_next",KEY_H)
	camera = game.camera_mode
	tap(KEY_C)
	check(game.camera_mode == camera, "Old shortcut no longer acts")
	tap(KEY_H)
	check(game.camera_mode == posmod(camera+1,4), "Rebound shortcut acts")
	key(KEY_B)
	check(game.look_back_held, "Look back holds")
	key(KEY_B,false)
	check(not game.look_back_held, "Look back releases")
	key(KEY_B)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.look_back_held, "Focus loss releases look back")
	key(KEY_B,false)
	var settings = game.get_node("GameSettings")
	settings.open_device_mapping()
	await process_frame
	check(settings.keyboard_settings.is_visible_in_tree(), "Connection settings open keyboard mapping without Ride")
	settings.ride_tabs.grab_focus()
	var selected_tab: int = settings.appearance_tabs.current_tab
	tap(KEY_LEFT)
	check(settings.appearance_tabs.current_tab == selected_tab-1, "Keyboard changes settings tabs")
	tap(KEY_RIGHT)
	check(settings.appearance_tabs.current_tab == selected_tab, "Keyboard returns to keyboard editor")
	var editor = settings.keyboard_settings
	editor.capture_context = "race"
	editor.capture_action = "camera_next"
	tap(KEY_F10)
	check(settings.panel_root.visible, "Capturing settings key does not close editor")
	check(not editor.capture_action.is_empty(), "Conflict keeps capture available")
	tap(KEY_J)
	check(int(game.keyboard_mapping.profiles.race.camera_next) == KEY_J, "Editor stores new key")
	check(game.camera_mode == posmod(camera+1,4), "Capture never triggers gameplay")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/keyboard_settings.png"))
	settings._close_settings()
	game.keyboard_mapping.enabled = false
	game.race_paused = false
	camera = game.camera_mode
	tap(KEY_J)
	check(game.camera_mode == camera, "Keyboard can be disabled")
	tap(KEY_F10)
	check(settings.panel_root.visible, "Settings remain accessible when keyboard disabled")
	settings._close_settings()
	server.close()
	game.queue_free()
	await process_frame
	print("KEYBOARD_MAPPING_OK" if failures == 0 else "KEYBOARD_MAPPING_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
