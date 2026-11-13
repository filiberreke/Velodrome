extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var g := Game.new(); root.add_child(g); g.set_physics_process(false)
	await process_frame
	g.bridge_devices.set_process(false); g.bridge_devices.panel_root.hide()
	g.setup_panel.show_piste_training(); g.setup_panel.piste_tiles["derny"].pressed.emit(); g.setup_panel.derny_page.begin()
	await process_frame
	g.trainer_seen = true; g.connected = true
	g.keyboard_mapping.enabled = false; g.keyboard_mapping.apply_ui()
	var mode: int = g.camera_mode
	for pressed in [true, false]:
		var key := InputEventKey.new(); key.keycode = KEY_C; key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
	check(g.camera_mode == mode and g.piste_training.active, "Disabled C leaves trainer derny session unchanged")
	var scene = g.piste_training
	g.camera_mode = 2
	for d in [65.0, 190.0]:
		scene.distance = d
		g.camera_roll = 0.0
		scene._present(1.0)
		var inward: Vector3 = (g._at(d, scene.player_lane_offset - 0.1) - g._at(d, scene.player_lane_offset)).normalized()
		inward.y = 0.0
		print("CAMERA d=",d," dot=",g.camera.global_basis.y.dot(inward)," roll=",g.camera_roll)
		check(is_equal_approx(absf(g.camera_roll), absf(g.visual_rolls[0])), "POV follows full rider bank")
		check(g.camera.global_basis.y.dot(inward) > 0.05, "POV leans toward infield on both bends")
	g.connected = false; g.trainer_seen = false
	scene.finish_session("Test", false); scene.page.environment_requested.emit(false)
	g._set_menu_visible(false); g.race_mode = 3; g.rider_count = 6; g._configure_peloton()
	g.keirin.speed = 45.0 / 3.6
	for d in [65.0, 190.0]:
		g.keirin.distance = d; g.keirin.lane = 1.78; g.keirin._present_pilot(g)
		var inward: Vector3 = g._at(d, 1.68) - g._at(d, 1.78)
		inward.y = 0.0
		check(g.keirin.pilot.basis.y.dot(inward.normalized()) > 0.1, "Keirin derny leans inward on both bends")
	for d in [0.0, 125.0]:
		g.keirin.distance = d; g.keirin._present_pilot(g)
		check(absf(g.keirin.pilot.rotation.z) < 0.001, "Keirin derny upright on straights")
	g.keirin.distance = 65.0; g.keirin.lane = g.keirin.SAFETY_LANE; g.keirin._present_pilot(g)
	check(absf(g.keirin.pilot.rotation.z) < 0.001, "Keirin derny upright after leaving the track")
	g.finished = true; g.finish_overlay.hide()
	g._ride_action("B")
	check(g.finished and not g.setup_panel.visible, "Back during coast cannot discard result")
	g.finish_overlay.show()
	g._ride_action("B")
	check(g.exit_menu.returning_to_menu and g.finished and not g.setup_panel.visible, "Back on results requires confirmation")
	g.exit_menu.cancel_or_resume()
	check(g.finished and g.finish_overlay.visible and not g.exit_menu.backdrop.visible, "Cancel preserves result")
	var menu_button: Button = g.finish_overlay.find_child("MainMenuButton", true, false)
	menu_button.pressed.emit()
	check(g.exit_menu.returning_to_menu, "Mouse main menu also requires confirmation")
	g.exit_menu.cancel_or_resume()
	g.exit_menu.exit_button.pressed.emit()
	check(g.exit_menu.quitting_application and g.exit_menu.backdrop.visible, "Exit icon requires confirmation")
	g.exit_menu.cancel_or_resume()
	g._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(g.exit_menu.quitting_application, "Window close requires confirmation")
	g.exit_menu.cancel_or_resume()
	g.race_mode = 2; g.rider_count = 12; g._configure_peloton(); g.finished = false
	g.start_state = "RACING"; g._set_menu_visible(false); g.finish_overlay.hide()
	g.elimination_rules.eliminated.assign([11, 0, 8])
	g._update_hud()
	var hud = g.race_overlay
	check(hud.eliminated_panel.visible and hud.eliminated_rows.get_child_count() == 3, "Separate elimination classification")
	check(hud.eliminated_rows.get_child(0).text.begins_with("10."), "Latest elimination first with final rank")
	check(hud.eliminated_rows.get_child(2).text.begins_with("12."), "First elimination at bottom")
	for row in hud.rider_rows:
		if row.shell.visible: check(not g.elimination_rules.eliminated.has(int(row.shell.get_meta("rider_id"))), "Nearby excludes eliminated riders including player")
	check(hud.nearby_others.visible and hud.nearby_others.text == "+ 3 anderen", "Nearby counts all undisplayed active riders")
	if "--capture" in OS.get_cmdline_user_args():
		g.camera_mode = 1; g.camera_roll = 0.0; g._update_visuals(1.0)
		root.size = Vector2i(1920, 1080)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/bugs-elimination.png"))
	g.exit_menu.show_results_leave(); g.exit_menu._leave_pressed()
	check(g.setup_panel.visible and not g.finished, "Explicit confirmation returns to menu")
	g.free(); await process_frame
	print("V02_BUGS failures=", failures); quit(1 if failures else 0)
