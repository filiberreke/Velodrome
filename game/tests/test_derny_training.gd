extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class UploadCapture extends Node:
	var working := false
	var path := ""
	var title := ""
	var description := ""
	func begin_export(p: String,t: String,d: String) -> void:
		path = p; title = t; description = d
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
	menu.training_store.folder = "user://test_derny_archive"
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
	check(scene.demo and scene.hud.visible and not menu.session_panel.visible and not menu.menu_margin.visible, "PC trial is explicit and compact HUD leaves piste visible")
	check(not game.arena.get_node("LevendigMiddenterrein").visible, "Training venue replaces race-day infield")
	check(scene.pilot.animator != null, "Real derny asset has imported animations")
	for action in ["DP_DernyRide","DP_DernyLookBack","DP_DernySpeedUp","DP_DernySlowDown"]:
		check(scene.pilot.animator.has_animation(action), "GLB animation available: " + action)
	game.camera_mode = 2
	game._refresh_look_back()
	check(not game.bikes[0].visible, "POV hides own rider just as in races")
	scene.advance(.1)
	check(scene.reduction > .7, "Physical drafting is stronger than ordinary rider")
	await shot("approach")
	scene.demo_power = 0
	for i in range(400):
		if scene.session.phase != "RUNUP": break
		scene.advance(.25)
		check(scene.gap() > 2.7 and scene.gap() < 3.3, "Assisted approach cannot overtake or lose wheel: gap %.3f phase %s distance %.3f" % [scene.gap(),scene.session.phase,scene.distance])
	check(scene.session.phase == "PACE" and absf(scene.player_speed * 3.6-30) < .2, "Assisted lap delivers player to 30 km/h")
	scene.demo_power = 1000
	for i in range(20): scene.advance(.25)
	check(scene.gap() >= 2.79 and scene.too_close and scene.player_speed*3.6 <= 30.01, "Excess watts are capped behind derny with warning")
	check(scene.hud.phase_label.text.contains("TE DICHT"), "Closing warning is visible")
	check(scene.hud.power_meter.target_visible and scene.required_power() > 0, "Race power bar shows estimated watt target")
	check(scene.samples.size() > 20 and scene.store.load_activity(scene.activity.id).samples.size() > 1, "Time series is periodically persisted while riding")
	scene.player_lane_target += 2
	for i in range(28): scene.advance(.25)
	check(scene.gap() < 0 and scene.reduction == 0, "Deliberate lateral overtake remains possible in full wind")
	scene.player_lane_target = 2
	scene.player_lane_offset = scene.LANE
	scene.distance = scene._behind_derny(3)
	scene.player_speed = 30.0/3.6
	var mode: int = game.camera_mode
	game._ride_action("DOWN")
	check(game.camera_mode == (mode+1)%4 and game._ride_profile() == "race", "Mapped race camera buttons work during piste training")
	game._ride_action("B")
	check(game.look_back_held and scene.session.running(), "Race look-back button does not leave training")
	game.ride_look_back = false
	game._refresh_look_back()
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
	var initial_gestures: int = scene.pilot.gesture_count.speed_up
	scene.session.elapsed = 58.45
	for i in range(4): scene.advance(.25)
	var gestures: int = scene.pilot.gesture_count.speed_up
	check(gestures == initial_gestures + 1, "One thumbs-up anticipates next minute")
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
	await shot("live_hud")
	var saved_id: String = scene.activity.id
	page.finish("Test stop")
	check(page.session.phase == "RESULT" and not game.trainer_control.enabled_before, "Stop releases trainer client")
	check(not scene.active and menu.menu_margin.visible and page.upload_button.visible, "Finish opens Strava option and saved results")
	var saved: Dictionary = menu.training_store.load_activity(saved_id)
	check(saved.get("final",false) and saved.samples.size() > 20 and saved.assisted_seconds > 0, "Final activity survives reload including assistance metadata")
	check(not preload("res://training_store.gd").fit_payload(saved).is_empty(), "Saved training yields FIT bytes for existing Strava client")
	var uploader := UploadCapture.new()
	game.add_child(uploader)
	game.strava_client = uploader
	page.upload_button.pressed.emit()
	check(FileAccess.file_exists(uploader.path) and uploader.title.contains("Dernytraining") and uploader.description.contains("automatisch"), "Strava button hands this saved training and assistance disclosure to existing upload flow")
	await settle()
	await shot("training_result")
	menu.show_training_history()
	check(menu.training_history_page.rows.get_child_count() > 0, "Saved training is accessible in-game")
	menu.show_piste_training()
	check(not scene.active and not scene.popup.visible and menu.page == 11 and menu.menu_margin.visible, "Back restores piste menu and clears popup")
	check(game.arena.get_node("LevendigMiddenterrein").visible, "Original race venue is restored")
	# A real trainer with invalid/stale power must not start or silently become a demo.
	game.trainer_seen = true
	menu.show_derny()
	page.begin()
	check(not page.session.running() and not scene.active and menu.menu_margin.visible, "Stale real trainer blocks start")
	game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":150.0,"speed_kmh":25.0,"cadence_rpm":85.0,"sample_id":1,"power_sample_id":1,"power_age_s":0.0,"heart_rate_bpm":152})
	page.begin()
	check(scene.active and not scene.demo, "Fresh validated power starts real trainer mode")
	for i in range(5): scene.advance(.25)
	check(scene.samples[-1].power_w == 150 and scene.samples[-1].heart_rate_bpm == 152 and scene.samples[-1].cadence_rpm == 85, "Real power, heart rate and cadence reach graph and recording")
	check(scene.hud.heart_label.text == "152 bpm" and scene.hud.cadence_label.text == "85 rpm", "Race metrics panel displays actual sensor values")
	menu.ftp_page.telemetry_ok = false
	scene.advance(.1)
	check(page.session.phase == "RESULT" and page.session.reason == "Vermogenssignaal verloren" and not game.trainer_control.enabled_before, "Lost power stops and releases trainer immediately")
	page.leave()
	game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":160.0,"speed_kmh":26.0,"cadence_rpm":86.0,"sample_id":2,"power_sample_id":2,"power_age_s":0.0})
	menu.show_derny()
	page.begin()
	var reset_id: String = scene.activity.id
	game._reset()
	check(not scene.active and menu.training_store.load_activity(reset_id).get("final",false), "Returning through game reset also finalises local training")
	for activity in menu.training_store.recent(100):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store.folder.path_join(str(activity.id)+".json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://training_upload.fit"))
	game.queue_free()
	await process_frame
	print("DERNY_TRAINING failures=", failures)
	quit(0 if failures == 0 else 1)
