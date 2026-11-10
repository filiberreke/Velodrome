extends SceneTree
class Model extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _ready() -> void:
		super._ready()
		bridge_devices.set_process(false)
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game := Model.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var page = game.bridge_devices
	check(not page.panel_root.visible, "No bridge: hub remains usable")
	check(page.close_button.text == "Overslaan", "No connection uses Overslaan")
	var preferences = game.get_node("GameSettings")
	check(not page.open_button.get_global_rect().intersects(preferences.open_button.get_global_rect()), "Status/setup control does not overlap settings")
	check(page.open_button.icon != null and page.open_button.text != "Apparaten", "Single status control includes setup icon instead of separate devices caption")
	game.setup_panel.update_bridge_status(true, true, false)
	page._process(0.0)
	check(page.open_button.text.contains("Trainer verbonden"), "Combined control preserves live bridge status")
	game.setup_panel.update_bridge_status(false, false, false)
	page._process(0.0)
	check(page.open_button.text.contains("Demo beschikbaar"), "Combined control preserves demo status")
	var server := PacketPeerUDP.new()
	server.bind(0, "127.0.0.1")
	page.port = server.get_local_port()
	page.socket.set_dest_address("127.0.0.1", page.port)
	var state := {"device_selection_v": 1, "devices": [
		{"address": "bike-1", "name": "Trainer gevonden", "roles": ["trainer"], "available": true},
		{"address": "ride-1", "name": "Zwift Ride links", "roles": ["controller"], "available": true},
		{"address": "hr-1", "name": "Hartslag BLE", "roles": ["heart_rate"], "available": true}],
		"selected": {"trainer": "bike-1", "controller": "ride-1", "heart_rate": "hr-1"},
		"connected": {"trainer": "bike-1", "controller": "ride-1"}, "scan_error": ""}
	var id: String = page._send("devices")
	for _i in 5: await process_frame
	check(server.get_available_packet_count() > 0, "Device poll reaches real loopback socket")
	server.get_packet()
	server.set_dest_address("127.0.0.1", page.socket.get_local_port())
	server.put_packet(JSON.stringify({"type": "ack", "v": 1, "id": id, "ok": true, "state": state}).to_utf8_buffer())
	for _i in 5: await process_frame
	page._process(0.0)
	check(page.panel_root.visible and page.auto_shown, "Available bridge opens devices before menu interaction")
	check(page.choices.trainer.item_count == 2 and page.choices.controller.item_count == 2, "Roles filter actual inventory")
	check(page.mapping_link.visible, "Selected controller exposes button mapping link")
	check(page.close_button.text == "Kies deze setup", "Connected devices use Kies deze setup")
	check(page.mapping_link.get_parent() == page.choices.controller.get_parent(), "Mapping belongs directly to controller section")
	check(page.mapping_link.get_index() > page.choices.controller.get_index(), "Mapping follows selected controller")
	check(page.mapping_link.flat and page.mapping_link.text == "Knoptoewijzing aanpassen", "Mapping uses subtle action label")
	page.snapshot.connected = {}
	page._refresh()
	check(page.close_button.text == "Overslaan" and not page.controller_connection.visible, "Selection without a connection still uses Overslaan")
	page.snapshot.connected = {"heart_rate": "hr-1"}
	page._refresh()
	check(page.close_button.text == "Kies deze setup", "Heart-rate-only connection also confirms setup")
	page.snapshot.connected = {"trainer": "bike-1", "controller": "ride-1"}
	page._refresh()
	page.close_page()
	page._process(0.0)
	check(not page.panel_root.visible, "Skip does not immediately reopen page")
	check(page.open_button.is_visible_in_tree(), "Combined status/setup control is visible after closing devices")
	game.start_state = "RACING"
	game.running = true
	game.clock = 123.0
	game.player_lane = 2
	page.open_button.pressed.emit()
	check(game.race_paused, "Opening during race pauses it")
	check(game.clock == 123.0 and game.player_lane == 2, "Opening preserves race time and lane")
	page.open_mapping()
	var settings = game.get_node("GameSettings")
	check(settings.controller_test_active() and settings.return_to_devices, "Link opens Besturing and mapping editor")
	check(settings.layer > game.exit_menu.layer, "Settings stay above paused overlay")
	settings._close_settings()
	check(page.panel_root.visible and game.race_paused, "Closing settings returns to devices and keeps pause")
	game._ride_action("B")
	check(not page.panel_root.visible and game.race_paused, "Ride back closes devices without resuming race")
	check(game.clock == 123.0 and game.player_lane == 2, "Return preserves race status")
	page.open_page()
	page._select("heart_rate", 0)
	check(not page.pending.is_empty(), "Role changes wait for bridge confirmation")
	page.handle_response({"type": "error", "v": 1, "id": page.pending, "ok": false, "message": "Niet beschikbaar"}, Time.get_ticks_msec() / 1000.0)
	check(page.pending.is_empty() and page.error == "Niet beschikbaar", "Selection failure remains visible")
	page.snapshot.selected.controller = "missing-ride"
	page._refresh()
	check(page.choices.controller.get_item_text(page.choices.controller.selected).contains("niet beschikbaar"), "Missing saved device stays explicit")
	page.last_response = -10.0
	page._process(0.0)
	check(page.choices.trainer.disabled and page.status.text.contains("niet bereikbaar"), "Bridge loss disables stale selection")
	check(page.close_button.text == "Overslaan" and not page.controller_connection.visible, "Bridge loss clears connected action and badge")
	if DisplayServer.get_name() != "headless":
		page.last_response = Time.get_ticks_msec() / 1000.0
		page.error = ""
		page.snapshot = state
		page.snapshot.selected.controller = "ride-1"
		page._refresh()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://../.test-user/bridge-devices.png")
		page.close_page()
		page._process(0.0)
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://../.test-user/bridge-status-paused.png")
		game.exit_menu.hide_pause()
		game.start_state = "SETUP"
		game.race_paused = false
		game.setup_panel.show_hub()
		page._process(0.0)
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://../.test-user/bridge-status-menu.png")
	server.close()
	game.queue_free()
	await process_frame
	print("BRIDGE_DEVICES_OK" if failures == 0 else "BRIDGE_DEVICES_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
