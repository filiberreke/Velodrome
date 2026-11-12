extends SceneTree
class Model extends "res://main.gd":
	func _ready() -> void:
		super._ready()
		bridge_devices.set_process(false) # Isolate menu regression from a running local bridge.
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func press(game: Node3D, key: String) -> void:
	game._process_bridge_packet({"type": "button", "button": key})
	await process_frame
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game := Model.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame; await process_frame
	var menu = game.setup_panel
	menu.show_choices()
	await process_frame
	menu.cards[0].grab_focus()
	await press(game, "RIGHT")
	check(root.gui_get_focus_owner() == menu.cards[1], "Bridge RIGHT moves focus to next menu card")
	await press(game, "A")
	check(menu.page == 2 and menu.selected == 1 and game.start_state == "SETUP", "Bridge A selects card without resetting race")
	await press(game, "B")
	check(menu.page == 1, "Bridge B returns to mode gallery")
	await process_frame
	menu.cards[0].grab_focus()
	await press(game, "DOWN")
	check(root.gui_get_focus_owner() == menu.cards[4], "Bridge DOWN navigates grid")
	await press(game, "UP")
	check(root.gui_get_focus_owner() == menu.cards[0], "Bridge UP navigates grid")
	game._process_bridge_packet({"type": "button", "button": "RIGHT", "source_button": "SHIFT_UP_RIGHT"})
	check(root.gui_get_focus_owner() == menu.cards[0], "Gear paddles cannot navigate menus")
	game._process_bridge_packet({"type": "steering", "value": 100})
	check(root.gui_get_focus_owner() == menu.cards[0] and game.player_lane == 0, "Analog paddle does not navigate or move rider in menu")
	await press(game, "A")
	menu.start_button.grab_focus()
	await press(game, "A")
	check(menu.page == 5, "Bridge A opens configured start list")
	menu.startlist_page.start_button.grab_focus()
	await press(game, "A")
	check(game.start_state == "INTRO", "Bridge A can start configured race")
	game.queue_free()
	await process_frame
	print("BRIDGE_NAVIGATION_OK" if failures == 0 else "BRIDGE_NAVIGATION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
