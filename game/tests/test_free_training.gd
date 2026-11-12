extends SceneTree
const Exercise := preload("res://piste_exercise_session.gd")
const Pacers := preload("res://free_training_pacers.gd")
class Flat extends RefCounted:
	func _path_metric(_at: float,_lane: float) -> float: return 2.0
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func shot(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/derny-captures/"+name+".png"))
func run_test() -> void:
	root.size = Vector2i(1920,1080); root.content_scale_size = Vector2i(1920,1080); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var session := Exercise.new(); session.start("free_ride",0,30,0)
	session.observe(100,0,625,10,10,200,0,0)
	check(session.running() and session.laps.size() == 2 and is_equal_approx(float(session.laps[0].seconds),40) and is_equal_approx(float(session.laps[1].elapsed_s),80),"Each finish crossing is interpolated, including multiple laps in one update")
	session.observe(20,625,750,10,10,200,0,0)
	session.observe(1000,750,750,0,0,0,0,0)
	check(session.running() and session.laps.size() == 3 and is_equal_approx(float(session.laps[2].seconds),40),"Free riding has no time limit and does not count stationary or repeated crossings")
	var rng := RandomNumberGenerator.new(); rng.seed = 123
	var pacers := Pacers.new(); pacers.reset(rng)
	var before := pacers.distances.duplicate(); pacers.advance(Flat.new(),2)
	for i in range(4): check(is_equal_approx((pacers.distances[i]-before[i])*2/2*3.6,float(Pacers.SPEEDS[i])),"Each independent pacer maintains its own physical speed")
	check(Pacers.COLOURS[0] == Color("268cd3") and Pacers.COLOURS[1] == Color("35ad77") and Pacers.COLOURS[2] == Color("ff922e") and Pacers.COLOURS[3] == Color("df504b"),"Speed colours run blue, green, orange, red")
	var alternate := Pacers.new(); rng.seed = 456; alternate.reset(rng)
	check(before != alternate.distances,"Pacer starting locations vary between sessions")
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	var menu = game.setup_panel; menu.training_store.folder = "user://test_free_training"
	for item in menu.training_store.recent(100): DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(item.id)))
	for row in [["slow",42.0,250,600],["fast",46.0,400,900],["middle",44.0,300,800]]:
		menu.training_store.save({"version":1,"id":row[0],"kind":"flying_start","exercise_success":true,"entry_speed_kmh":row[1],"mean_power_w":row[2],"peak_power_w":row[3],"started_local":"2026-11-10 10:00:00","samples":[]})
	menu.training_store.save({"version":1,"id":"aborted","kind":"flying_start","exercise_success":false,"entry_speed_kmh":99,"samples":[]})
	menu.show_piste_exercise("flying_start")
	var page = menu.exercise_page; var table = page.records_table
	check(table.visible and table.entries.size() == 3 and table.entries[0].id == "fast" and table.entries[2].id == "slow","Setup shows saved best flying starts sorted by highest speed and excludes aborted attempts")
	check(table.rows.get_child(0).get_child(3).text == "400" and table.rows.get_child(0).get_child(4).text == "900","Each performance row displays its average and maximum watts")
	check(not page.detail.text.contains("plafond"),"Flying setup has no target-power control")
	await shot("flying_best_setup")
	menu.show_piste_training(); await shot("piste_tiles")
	check(menu.piste_tiles.size() == 5,"Four existing piste sessions and Madison have their own image tile")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		for i in range(3): await process_frame
		for tile in menu.piste_tiles.values(): check(root.get_visible_rect().encloses(tile.get_global_rect()),"Every piste tile fits the screen")
	root.size = Vector2i(1920,1080)
	menu.piste_tiles["free_ride"].pressed.emit(); page.begin()
	var scene = game.piste_training
	check(scene.active and scene.session.kind == "free_ride" and scene.player_speed == 0 and scene.pacer_bikes.size() == 4,"Free ride starts from rest with four independent pacers")
	check(scene.hud.laps_panel.visible and not scene.hud.mission_panel.visible and not scene.pack_markers.visible,"Free-ride lap table replaces the exercise-goal card under standard measurements")
	for i in range(4):
		var bike = scene.pacer_bikes[i]
		check(bike.get_child(1).text == Pacers.rider_name(i),"Every pacer has its fixed-speed name label")
		var body = bike.get_child(0).body_mesh; var found := false
		for surface in range(body.mesh.get_surface_count()):
			var material = body.mesh.surface_get_material(surface)
			if str(material.resource_name).to_lower().begins_with("suit"):
				found = true
				check(body.get_surface_override_material(surface).albedo_color == Pacers.COLOURS[i],"Actual jersey material matches that pacer's intensity colour")
		check(found,"Pacer jersey surface was verified")
	# Position one pacer ahead on the player's line and keep the others far away.
	for i in range(4): scene.pacers.distances[i] = scene.distance+50+i*30
	scene.pacers.distances[0] = scene.distance+3/game._path_metric(scene.distance,scene.player_lane_offset); scene.pacers.lanes[0] = scene.player_lane_offset; scene._update_pack_state()
	check(scene._draft_at(scene.distance) > .49,"Free rider can shelter behind an individual pacer")
	scene.pacers.lanes[0] = scene.player_lane_offset+1.2
	check(scene._draft_at(scene.distance) == 0,"No shelter is granted beside the pacer")
	scene.pacers.lanes[0] = scene.player_lane_offset; scene.pacers.distances[0] = scene.distance-2
	check(scene._draft_at(scene.distance) == 0,"Passing the pacer removes its wake")
	scene.demo_power = 1000; game.camera_mode = 1
	for i in range(380):
		scene.advance(.25)
		if i == 220: await shot("free_training_laps")
	check(scene.active and scene.session.laps.size() >= 3 and scene.total_distance > 750,"Free ride keeps running after multiple laps and accumulates actual ridden distance")
	check(scene.hud.lap_rows.get_child_count() == scene.session.laps.size() and scene.hud.totals_label.text.contains("km"),"HUD lists completed lap times and keeps time and distance visible")
	var id: String = scene.activity.id; page.finish("Handmatig gestopt")
	var saved: Dictionary = menu.training_store.load_activity(id)
	check(saved.get("final",false) and saved.laps.size() >= 3 and saved.kind == "free_ride","Free training and lap times are saved on stop")
	menu.show_training_history()
	for button in menu.training_history_page.rows.get_children():
		if button.text.contains("Vrije training"): button.pressed.emit(); break
	check(page.kind == "free_ride" and page.selected_activity.id == id,"Saved free training opens its matching result screen")
	menu.show_piste_exercise("flying_start"); page.begin(); scene = game.piste_training; scene.demo_power = 300
	for i in range(300):
		if not scene.active: break
		scene.advance(.25)
	check(page.selected_activity.get("exercise_success",false) and table.visible and table.entries.size() == 4,"New flying attempt is immediately included in the same sorted result table")
	check(page.result.text.contains("Gemiddeld vermogen") and page.result.text.contains("maximaal vermogen"),"Flying result displays actual average and maximum watts")
	await shot("flying_best_result")
	var reload_table := preload("res://flying_start_table.gd").new(); reload_table.store = menu.training_store; root.add_child(reload_table); reload_table.refresh()
	check(reload_table.entries.size() == table.entries.size() and reload_table.entries[0].id == table.entries[0].id,"Flying best performances survive a fresh table instance")
	reload_table.free()
	for i in range(1,table.entries.size()): check(float(table.entries[i-1].entry_speed_kmh) >= float(table.entries[i].entry_speed_kmh),"Best performances remain sorted by speed")
	for item in menu.training_store.recent(100): DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(item.id)))
	game.free()
	print("FREE_TRAINING failures=",failures)
	quit(0 if failures == 0 else 1)
