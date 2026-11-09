extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in range(5): await process_frame
func shot(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://").path_join("../.test-user/derny-captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(filename + ".png"))
func run_test() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var menu = game.setup_panel
	await shot("main_menu")
	check(menu.hub_page.get_child(0).get_child_count() == 2 and menu.hub_page.get_child(1).get_child_count() == 2, "Four main tiles in two rows")
	menu.show_piste_training()
	menu.piste_page.get_child(0).pressed.emit()
	check(menu.page == 12, "Derny opens under piste training")
	menu.derny_page.begin()
	await settle()
	var scene = game.piste_training
	var page = menu.derny_page
	check(scene != null and scene.active and page.session.phase == "RUNUP", "Starts isolated approach lap")
	check(game.start_state == "SETUP" and not game.broadcast_intro.active, "Never enters race state machine")
	check(scene.demo and menu.session_panel.visible and not menu.menu_margin.visible, "PC trial is explicit and compact HUD leaves piste visible")
	check(not game.arena.get_node("LevendigMiddenterrein").visible, "Training venue replaces race-day infield")
	check(scene.pilot.animator != null, "Real derny asset has imported animations")
	for action in ["DP_DernyRide","DP_DernyLookBack","DP_DernySpeedUp","DP_DernySlowDown"]:
		check(scene.pilot.animator.has_animation(action), "GLB animation available: " + action)
	game.camera_mode = 2
	game._refresh_look_back()
	check(game.bikes[0].visible, "Training chase view remains visible after controller update")
	scene.advance(.1)
	check(scene.reduction > .7, "Physical drafting is stronger than ordinary rider")
	await shot("approach")
	var lane: int = scene.player_lane_target
	game._process_steering(40)
	check(scene.player_lane_target == lane + 1, "Controller steering changes lane during training")
	game._process_steering(0)
	game._ride_action("LEFT")
	check(scene.player_lane_target == lane, "Mapped left steering returns to wheel")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	check(scene.player_lane_target == lane + 1, "Keyboard steering works while Stop button has focus")
	game._ride_action("LEFT")
	game._ride_action("B","SHIFT_UP_RIGHT")
	check(page.session.running(), "Physical gear paddle cannot stop training")
	scene.session.phase = "PACE"
	scene.session.elapsed = 58.45
	for i in range(4): scene.advance(.25)
	var gestures: int = scene.pilot.gesture_count.speed_up
	check(gestures == 1, "One thumbs-up anticipates next minute")
	scene.advance(.25)
	check(scene.pilot.gesture_count.speed_up == gestures, "Thumb is not retriggered each frame")
	scene.session.elapsed = 59.99
	scene.advance(.03)
	check(scene.session.target_kmh == 31 and scene.popup.text == "DERNY  ·  31 km/u", "New speed appears centrally at minute boundary")
	await settle()
	await shot("speed_31")
	scene.pilot.gesture("speed_up")
	scene.pilot.animator.advance(2.0)
	check(scene.pilot.animator.current_animation == "DP_DernyRide", "One-shot gesture returns to riding automatically")
	scene.pilot.gesture("look_back")
	check(scene.pilot.last_gesture == "look_back", "Look-back action plays without slowing signal")
	scene.pilot.animator.seek(.5, true)
	await shot("look_back")
	page.finish("Test stop")
	check(page.session.phase == "RESULT" and not game.trainer_control.enabled_before, "Stop releases trainer client")
	menu.show_piste_training()
	check(not scene.active and not scene.popup.visible and menu.page == 11 and menu.menu_margin.visible, "Back restores piste menu and clears popup")
	check(game.arena.get_node("LevendigMiddenterrein").visible, "Original race venue is restored")
	# A real trainer with invalid/stale power must not start or silently become a demo.
	game.trainer_seen = true
	menu.show_derny()
	page.begin()
	check(not page.session.running() and not scene.active and menu.menu_margin.visible, "Stale real trainer blocks start")
	game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":150.0,"speed_kmh":25.0,"cadence_rpm":85.0,"sample_id":1,"power_sample_id":1,"power_age_s":0.0})
	page.begin()
	check(scene.active and not scene.demo, "Fresh validated power starts real trainer mode")
	menu.ftp_page.telemetry_ok = false
	scene.advance(.1)
	check(page.session.phase == "RESULT" and page.session.reason == "Vermogenssignaal verloren" and not game.trainer_control.enabled_before, "Lost power stops and releases trainer immediately")
	page.leave()
	game.queue_free()
	await process_frame
	print("DERNY_TRAINING failures=", failures)
	quit(0 if failures == 0 else 1)
