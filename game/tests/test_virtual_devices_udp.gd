extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(int(OS.get_cmdline_user_args()[0]))
	func _ready() -> void:
		super._ready()
		bridge_devices.port = int(OS.get_cmdline_user_args()[1])
		bridge_devices.socket.set_dest_address("127.0.0.1", bridge_devices.port)
	func _save_recording(_reason: String) -> void: pass
var game
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_for(condition: Callable, message: String, timeout: int = 6000) -> void:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call() and Time.get_ticks_msec() < deadline:
		game._read_bridge()
		await process_frame
	check(condition.call(), message)
func run_test() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	var page = game.bridge_devices
	await wait_for(func(): return page.panel_root.visible and not page.snapshot.is_empty(), "Virtual bridge automatically opens devices")
	check(page.snapshot.devices.size() == 2, "Two-device preset contains exactly two discovered devices")
	check(page.snapshot.devices[0].name == "Wahoo KICKR" and page.snapshot.devices[1].name == "Zwift Ride (links)", "Requested device names exposed")
	check(page.choices.trainer.item_count == 2 and page.choices.controller.item_count == 2, "Each device only appears in its supported role")
	page._select("trainer", 0)
	await wait_for(func(): return page.pending.is_empty() and page.snapshot.selected.trainer == "" and not game.connected, "Disabling trainer updates real simulator telemetry")
	page._select("trainer", 1)
	await wait_for(func(): return page.pending.is_empty() and page.snapshot.selected.trainer == "virtual:wahoo-kickr" and game.connected, "Trainer reselects over real UDP")
	page.open_mapping()
	var settings = game.get_node("GameSettings")
	check(settings.controller_test_active(), "Selected virtual Ride opens button mapping")
	settings._close_settings()
	check(page.panel_root.visible, "Settings returns to devices")
	page.close_page()
	await process_frame
	check(not page.panel_root.visible, "Skip remains closed")
	game.start_state = "RACING"
	game.running = true
	game.clock = 42.0
	page.open_page()
	check(game.race_paused, "Device page pauses race")
	print("VIRTUAL_DEVICES_HIDE")
	await wait_for(func(): return not game.connected and page.snapshot.connected.trainer == "", "Disappearing selected trainer becomes unavailable")
	check(page.snapshot.selected.trainer == "virtual:wahoo-kickr", "Missing selection is retained")
	print("VIRTUAL_DEVICES_RETURN")
	await wait_for(func(): return game.connected and page.snapshot.connected.trainer == "virtual:wahoo-kickr", "Returning device reconnects without losing selection")
	print("VIRTUAL_DEVICES_OFFLINE")
	await wait_for(func(): return page.status.text.contains("niet bereikbaar"), "Full bridge outage is shown")
	print("VIRTUAL_DEVICES_ONLINE")
	await wait_for(func(): return not page.status.text.contains("niet bereikbaar"), "Device polling recovers after bridge returns")
	check(game.race_paused and game.clock == 42.0 and game.start_state == "RACING", "All simulator flows preserve paused race state")
	page.close_page()
	game.free()
	await process_frame
	print("VIRTUAL_BRIDGE_OK" if failures == 0 else "VIRTUAL_BRIDGE_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
