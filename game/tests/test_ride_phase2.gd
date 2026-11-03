extends SceneTree
class Game extends "res://main.gd":
	var quit_requested := false
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _quit_application() -> void: quit_requested = true
var failures := 0
var g
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func raw(key: String, down: bool) -> void:
	g._process_bridge_packet({"type":"controller_button", "source_button":key, "pressed":down})
func mapped(key: String, source: String = "") -> void:
	g._process_bridge_packet({"type":"button", "button":key, "source_button":key if source.is_empty() else source})
func press(key: String) -> void:
	raw(key, true); mapped(key); raw(key, false)
	await process_frame
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	g = Game.new()
	root.add_child(g)
	g.set_physics_process(false)
	await process_frame; await process_frame
	var menu = g.setup_panel
	var settings = g.get_node("GameSettings")
	await press("B")
	check(g.exit_menu.quitting_application and not g.quit_requested, "Gallery B asks before quitting")
	await press("B")
	check(not g.exit_menu.quitting_application, "B cancels application exit")
	await press("Z")
	check(settings.panel_root.visible and g.start_state == "SETUP", "Z opens settings without starting/resetting")
	await press("RIGHT")
	check(settings.appearance_tabs.current_tab == 1, "Ride changes settings tabs")
	settings.scale_slider.grab_focus()
	var scale: float = settings.scale_slider.value
	await press("LEFT")
	check(settings.scale_slider.value < scale, "Ride adjusts display slider")
	settings.appearance_tabs.current_tab = 0
	settings.rider_weight_input.get_line_edit().grab_focus()
	var weight: float = settings.rider_weight_input.value
	await press("RIGHT")
	check(settings.rider_weight_input.value == weight + 0.5, "Ride adjusts SpinBox")
	await press("DOWN")
	check(root.gui_get_focus_owner() != settings.rider_weight_input.get_line_edit(), "Controller can leave numeric field")
	settings.rider_name_input.grab_focus()
	await press("A")
	check(is_instance_valid(g.ride_navigation.keyboard), "A opens text keyboard")
	await press("A")
	check(g.ride_navigation.draft.text.ends_with("A"), "Controller types a character")
	await press("B")
	check(not is_instance_valid(g.ride_navigation.keyboard) and settings.panel_root.visible, "B cancels keyboard inside settings")
	settings.appearance_tabs.current_tab = settings.controller_test.get_index()
	await process_frame
	for button in ["A", "B", "Y", "UP", "DOWN", "LEFT", "RIGHT"]: await press(button)
	check(settings.controller_test_active() and g.start_state == "SETUP" and not g.look_back_held, "Test mode isolates all gameplay actions")
	await press("Z")
	check(not settings.controller_test_active() and settings.panel_root.visible, "Z leaves diagnostics without closing settings")
	await press("B")
	check(not settings.panel_root.visible, "B closes settings")
	menu.cards[0].grab_focus()
	await press("A")
	check(menu.page == 2, "A chooses scratch")
	menu.start_button.grab_focus()
	await press("A")
	check(menu.page == 5, "A opens start list")
	menu.startlist_page.start_button.grab_focus()
	await press("A")
	check(g.start_state == "INTRO", "A launches intro")
	await press("B")
	check(g.start_state == "SETUP" and menu.visible, "B leaves intro safely")
	menu.cards[0].grab_focus(); await press("A")
	menu.start_button.grab_focus(); await press("A")
	menu.startlist_page.start_button.grab_focus(); await press("A")
	await press("A")
	check(g.start_state == "WAIT_STOP", "A skips intro into staging")
	for state in ["WAIT_STOP", "COUNTDOWN", "NEUTRAL", "RUN_UP", "RACING"]:
		g.start_state = state
		g.running = state in ["NEUTRAL", "RUN_UP", "RACING"]
		var clock: float = g.clock
		await press("Z")
		check(g.race_paused, "Z pauses " + state)
		g._physics_process(0.5)
		check(g.clock == clock, "Pause freezes clocks")
		await press("A")
		check(not g.race_paused and g.start_state == state, "A resumes same state")
	g.start_state = "RACING"; g.running = true
	for mode in range(4):
		g.camera_mode = mode
		raw("B", true); mapped("B")
		check(g.look_back_held and g.camera_mode == mode, "B holds rear view preserving camera")
		raw("B", false)
		check(not g.look_back_held and g.camera_mode == mode, "Release restores camera")
	await press("DOWN")
	check(g.camera_mode == 0, "DOWN cycles camera")
	raw("Z", true); mapped("Z"); mapped("Z")
	check(g.race_paused, "Repeated held Z cannot immediately resume")
	raw("Z", false)
	await press("DOWN")
	await press("A")
	check(settings.panel_root.visible and g.race_paused, "Pause opens settings while race stays frozen")
	await press("B"); await press("B")
	check(not g.race_paused, "B closes settings then resumes pause")
	await press("Z")
	g.exit_menu.settings_button.pressed.emit()
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	g._input(escape)
	check(not settings.panel_root.visible and g.race_paused, "Keyboard Escape closes settings before resuming")
	await press("B")
	raw("B", true); mapped("B")
	g._process_bridge_packet({"type":"controller_connection", "connected":true, "buttons":[]})
	check(not g.look_back_held, "Heartbeat repairs lost release")
	raw("B", true); mapped("B")
	g._expire_bridge_optional_fields(g.last_controller_signal + 2.1)
	check(not g.look_back_held, "Bridge silence clears rear view")
	raw("B", true); mapped("B")
	g._process_bridge_packet({"type":"controller_connection", "connected":false})
	check(not g.look_back_held, "Disconnect clears rear view")
	raw("A", true); mapped("B", "A"); raw("A", false)
	check(not g.look_back_held, "Custom mapped rear-view source also releases")
	var before: int = g.camera_mode
	for source in ["SHIFT_UP_LEFT", "SHIFT_DOWN_LEFT", "SHIFT_UP_RIGHT", "SHIFT_DOWN_RIGHT", "POWER_LEFT", "POWER_RIGHT"]: mapped("A", source)
	check(g.start_state == "RACING" and g.camera_mode == before, "Shift and arcade keys cannot invoke game actions")
	await press("Z")
	g.exit_menu.leave_button.grab_focus()
	await press("A")
	check(g.exit_menu.confirming_leave and g.race_paused, "Leaving race needs explicit second confirmation")
	await press("B")
	check(not g.exit_menu.confirming_leave and g.race_paused, "B cancels leave confirmation")
	await press("Z")
	g.finished = true
	g.finish_overlay.show()
	g.finish_overlay.find_child("ReplayRaceButton", true, false).grab_focus()
	await press("A")
	check(g.start_state == "WAIT_STOP" and not g.finished, "A on replay repeats same race")
	g.finished = true; g.start_state = "RACING"; g.finish_overlay.show()
	g.finish_overlay.find_child("MainMenuButton", true, false).grab_focus()
	await press("A")
	check(g.start_state == "SETUP" and menu.visible, "A returns from results to gallery")
	# Keyboard fallback shares rear view without Ride release cancelling it.
	g._set_menu_visible(false); g.start_state = "RACING"; g.finished = false
	var event := InputEventKey.new(); event.keycode = KEY_B; event.pressed = true
	g._unhandled_key_input(event)
	raw("B", true); mapped("B"); raw("B", false)
	check(g.look_back_held, "Ride release preserves keyboard B hold")
	event.pressed = false; g._input(event)
	check(not g.look_back_held, "Keyboard release restores view")
	g._reset(); await process_frame
	await press("B")
	await press("DOWN")
	await press("A")
	check(g.quit_requested, "Controller confirms application exit")
	g.free()
	await process_frame
	print("RIDE_PHASE2_OK failures=%d" % failures)
	quit(0 if failures == 0 else 1)
