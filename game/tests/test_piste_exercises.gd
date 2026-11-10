extends SceneTree
const Exercise := preload("res://piste_exercise_session.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class UploadCapture extends Node:
	var working := false
	var path := ""
	var title := ""
	var description := ""
	func begin_export(p: String,t: String,d: String) -> void: path = p; title = t; description = d
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func shot(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/derny-captures/"+name+".png"))
func run_test() -> void:
	root.size = Vector2i(1920,1080)
	var session := Exercise.new()
	session.start("flying_start",1000,30,600)
	session.elapsed = 10; session.energy_j = 2000
	session.observe(.2,1249,1251,10,12,350,0,0)
	check(session.successful and is_equal_approx(session.elapsed,10.1) and is_equal_approx(session.entry_kmh,39.6),"Flying result interpolates the exact pursuit-line crossing")
	check(session.peak_w == 350 and is_equal_approx(session.result().mean_power_w,(2000+350*.1)/10.1),"Result keeps actual maximum and average power")
	session.start("take_lap",76,30,600)
	session.observe(1,76,126,8,8,150,100,150)
	check(session.gained_m == 0 and not session.successful,"Moving with the pack earns no lap even across visual wrap")
	session.observe(1,126,151,8,10,400,150,150)
	check(session.gained_m == 25 and session.running(),"Passing the pack front is not a whole lap")
	session.observe(.2,375,377,10,12,400,150,150)
	check(session.successful and is_equal_approx(session.gained_m,250),"Win only after gaining a full unwrapped lap and catching the rear wheel")
	session.start("take_lap",76,30,.1)
	session.observe(.2,76,326,8,8,500,100,100)
	check(not session.successful and session.reason == "Tijdslimiet bereikt","A crossing after the time limit cannot count as success")
	var server := PacketPeerUDP.new(); server.bind(0,"127.0.0.1")
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	game.trainer_control.port = server.get_local_port()
	for i in range(3): await process_frame
	var menu = game.setup_panel; var page = menu.exercise_page
	menu.training_store.folder = "user://test_piste_exercises"
	menu.show_piste_training()
	check(menu.piste_tiles.has("flying_start") and menu.piste_tiles.has("take_lap") and menu.piste_tiles.has("free_ride"),"Both fixed exercises are selectable under piste training")
	await shot("piste_training_choices")
	menu.piste_tiles["flying_start"].pressed.emit()
	await shot("flying_training_setup")
	page.begin()
	var scene = game.piste_training
	check(scene.active and scene.demo and game.start_state == "SETUP" and not game.broadcast_intro.active,"Flying exercise starts independently of the race state machine")
	check(is_equal_approx(scene.distance,Exercise.pursuit_line(game)) and is_equal_approx(scene.player_speed*3.6,30),"Every flying attempt starts at the painted pursuit line at the same rolling speed")
	check(not scene.hud.lap_label.text.contains("/"),"Exercise minimap displays elapsed time, not a race lap counter")
	check(not scene.line_marker.text.is_empty() and scene.pack_bikes.is_empty(),"Flying start has a visible line marker and no opponents")
	for i in range(6): game._ride_action("RIGHT")
	scene.demo_power = 300
	var climbed := false; var descended := false; var peak_height := 0.0; var old_height: float = game._at(scene.distance,scene.player_lane_offset).y
	for i in range(400):
		if not scene.active: break
		if scene.session.gained_m > 145: scene.player_lane_target = 0
		scene.advance(.25)
		var height: float = game._at(scene.distance,scene.player_lane_offset).y
		climbed = climbed or height > old_height+.001; descended = descended or height < old_height-.001; peak_height = maxf(peak_height,height); old_height = height
		if i == 45: await shot("flying_training_ride")
	check(climbed and descended and peak_height > 1,"Rider can climb and descend the actual banked piste")
	check(page.selected_activity.get("exercise_success",false) and page.selected_activity.entry_speed_kmh > 0 and page.selected_activity.peak_power_w == 300,"Completed flying attempt records entry speed and true peak power")
	check(not page.selected_activity.has("power_budget_w") and scene.samples.size() > 3,"Flying result has actual measurements and no target-power guidance")
	var flying_id: String = page.selected_activity.id
	check(menu.training_store.load_activity(flying_id).get("final",false) and not scene.active and menu.menu_margin.visible,"Flying result is locally persisted and restores menu")
	await shot("flying_training_result")
	menu.show_training_history()
	check(menu.training_history_page.rows.get_child(0).text.contains("Vliegende start"),"History identifies flying sessions instead of labelling them Derny")
	menu.training_history_page.rows.get_child(0).pressed.emit()
	check(page.kind == "flying_start" and page.selected_activity.id == flying_id,"Opening flying history shows its correct result screen")
	menu.show_piste_exercise("take_lap"); page.tempo_input.value = 30; page.limit_input.value = 10
	await shot("take_lap_setup")
	page.begin(); scene = game.piste_training
	check(scene.pack_bikes.size() == 8 and scene.active and scene.session.kind == "take_lap","Lap exercise creates an independent eight-rider peloton")
	check(scene.pack_markers.visible and scene.pack_markers.strips.size() == 2,"Training uses the same front and rear marker strips as scratch")
	if "--capture" in OS.get_cmdline_user_args():
		game.camera_mode = 1
		scene._present(1)
		await shot("take_lap_bunch")
	var draft: float = scene.reduction
	check(draft > .4 and draft <= .5,"Ordinary peloton wake is weaker than derny shelter")
	scene.demo_power = 1000
	var initial_lane: int = scene.player_lane_target
	for i in range(24): scene.advance(.25)
	check(scene.session.running() and not scene.too_close and scene.session.gained_m > 3 and scene.player_speed > scene.session.target_kmh/3.6,"High power can pass riders in the same corridor, as in scratch")
	check(scene.player_lane_target == initial_lane,"Passing does not require a lane change")
	check(not scene.hud.status_panel.visible,"No wheel-distance limiter warning appears during lap training")
	var state = scene.pack_state
	check(is_equal_approx(float(scene.hud.map.peloton.front),float(state.front)) and is_equal_approx(float(scene.hud.map.peloton.tail),float(state.tail)),"Minimap bounds follow the actual multi-row bunch")
	check(scene.pack_markers.captions[0].position.distance_to(game._at(float(state.front),8.5)+Vector3.UP*2.8) < .001,"Scratch's front strip is aligned with the training rider poses")
	for i in range(480):
		if not scene.active: break
		scene.advance(.25)
		if i == 40: await shot("take_lap_attack")
	check(page.selected_activity.get("exercise_success",false) and is_equal_approx(float(page.selected_activity.get("gained_m",0)),250),"An attack through the non-solid peloton still needs one full relative lap")
	check(page.selected_activity.duration_s > 10 and scene.samples.size() > 10 and not scene.active,"Lap effort has a full time series and ends in results")
	await shot("take_lap_result")
	var uploader := UploadCapture.new(); game.add_child(uploader); game.strava_client = uploader
	page.upload_button.pressed.emit()
	check(FileAccess.file_exists(uploader.path) and uploader.title.contains("Neem een ronde") and uploader.description.contains("Peloton"),"New exercises use the existing Strava export with their own title and context")
	page.leave(); menu.show_derny(); menu.derny_page.begin()
	check(game.piste_training == game.derny_training_environment and game.piste_training.active and not scene.active,"Returning to derny reuses the existing isolated exercise")
	menu.derny_page.finish("Regression check"); menu.derny_page.leave()
	game.trainer_seen = true; menu.show_piste_exercise("flying_start"); page.begin()
	check(not scene.active and page.session.reason.contains("verse"),"A stale real trainer cannot start or silently fall back to a demo")
	game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":175.0,"speed_kmh":25.0,"cadence_rpm":87.0,"sample_id":1,"power_sample_id":1,"power_age_s":0.0,"heart_rate_bpm":148})
	page.begin(); scene = game.piste_training
	check(scene.active and not scene.demo,"Fresh real trainer measurements start the selected exercise")
	for pair in [[2,700.0],[3,175.0]]:
		game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":pair[1],"speed_kmh":25.0,"cadence_rpm":87.0,"sample_id":pair[0],"power_sample_id":pair[0],"power_age_s":0.0,"heart_rate_bpm":148})
	check(scene.session.peak_w == 700,"Short measured power peak is retained when several UDP packets arrive before a physics frame")
	for i in range(5): scene.advance(.25)
	check(scene.samples[-1].power_w == 175 and scene.samples[-1].heart_rate_bpm == 148 and scene.samples[-1].cadence_rpm == 87,"New exercises preserve real power, pulse and cadence")
	menu.ftp_page.telemetry_ok = false; scene.advance(.1)
	check(scene.active and page.session.running() and not game.trainer_control.enabled_before,"Signal loss pauses the exercise and releases trainer control")
	page.finish("Test stop")
	for item in menu.training_store.recent(100): DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(item.id)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://training_upload.fit"))
	game.free(); server.close()
	print("PISTE_EXERCISES failures=",failures)
	quit(0 if failures == 0 else 1)
