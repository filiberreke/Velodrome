extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	var menu = game.setup_panel
	menu.training_store.folder = "user://test_madison_v02"
	menu.madison_page.progress.path = "user://test_madison_v02_progress.cfg"
	menu.madison_page.progress.advanced_unlocked = false
	menu.show_piste_training()
	check(menu.page == 11 and menu.piste_tiles.size() == 5,"Five piste exercises including the original four")
	for key in ["free_ride","derny","flying_start","take_lap","madison"]:
		check(menu.piste_tiles.has(key),"Existing piste tile retained: "+key)
	for i in range(3): await process_frame
	for tile in menu.piste_tiles.values(): check(root.get_visible_rect().encloses(tile.get_global_rect()),"Piste tiles fit the viewport")
	menu.select_mode(4)
	check(menu.start_button.disabled and 4 not in menu.PLAYABLE,"Ploegkoers competition remains unavailable")
	var before := {"mode":game.race_mode,"count":game.rider_count,"distances":game.distances.duplicate(),"speeds":game.speeds.duplicate(),"laps":game.race_laps}
	menu.show_madison_training()
	var page = menu.madison_page
	page._refresh()
	check(menu.page == 16 and page.difficulty.is_item_disabled(1),"Training settings lock Advanced")
	check(page.count.item_count == 2 and page.count.get_item_id(0) == 10 and page.count.get_item_id(1) == 20,"10/20 attempts available")
	page.difficulty.select(1); page.begin()
	check(game.madison_training_environment == null,"A forced selection cannot start locked Advanced")
	page.difficulty.select(0)
	page.begin()
	var scene = game.madison_training_environment
	check(scene != null and scene.active,"Dedicated Madison training environment starts")
	check(game.start_state == "SETUP" and not game.broadcast_intro.active,"Training has no race intro or countdown")
	check(scene.bikes.size() == 2 and not game.bikes[0].visible,"Two dedicated training riders")
	check(not game.arena.get_node("LevendigMiddenterrein").visible,"Quiet training venue retained")
	check(not scene.partner_present and not scene.madison.active and scene.page.progress.attempts == 0,"Training starts with an unscored settling-in half-lap")
	check(is_equal_approx(scene.next_spawn_player_distance-scene.start_distance,125.0),"First exchange is scheduled after 125 player metres")
	scene.grab_button("warmup",true); scene.grab_button("warmup",false)
	check(scene.page.progress.attempts == 0,"A during settling-in never scores a failed attempt")
	var keyboard_profile: String = game._keyboard_profile()
	check(keyboard_profile == "madison_simulator", "Madison has its own simulator keyboard profile")
	check(game.keyboard_mapping.assign(keyboard_profile,"madison_grab",KEY_G).is_empty(), "Madison grab can be reassigned")
	var custom_grab := InputEventKey.new(); custom_grab.keycode = KEY_G; custom_grab.pressed = true
	game._input(custom_grab)
	check(scene.input_sources.has("keyboard"), "Custom Madison key holds grab input")
	custom_grab.pressed = false; game._input(custom_grab)
	check(not scene.input_sources.has("keyboard"), "Custom Madison key releases grab input")
	check(game.keyboard_mapping.assign(keyboard_profile,"madison_grab",KEY_A).is_empty(), "Default Madison A binding can be restored")
	scene._spawn_partner() # Start the separate input/IK fixture explicitly.
	# An aligned fixture exercises the actual A routing, clips and world hand IK.
	scene.distances[1] = scene.distances[0]
	scene.speeds.assign([12.0,10.0])
	for tick in range(70):
		scene.madison.step(scene,1.0/60.0); scene._present(1.0/60.0)
		await process_frame
	game.bridge_devices.close_page()
	var grab := InputEventKey.new(); grab.keycode = KEY_A; grab.pressed = true
	game._input(grab); grab.pressed = false; game._input(grab)
	var max_hand_error := 0.0
	var saw_sling := false
	for tick in range(100):
		scene.madison.step(scene,1.0/60.0); scene._present(1.0/60.0)
		await process_frame
		if scene.madison.phase == scene.madison.Phase.SLING:
			saw_sling = true
			max_hand_error = maxf(max_hand_error,scene.animation.rig_g.anchor_world().distance_to(scene.animation.rig_r.anchor_world()))
	check(saw_sling and scene.madison.efficiency > .65 and max_hand_error < .005,"Training A input completes Easy sling with sub-5-mm hand contact")
	print("V02_HAND_CONTACT max_mm=",max_hand_error*1000)
	scene.enter() # Verify the real half-lap start and recurring 250 m schedule.
	var spawns: Array[float] = []
	var despawns: Array[float] = []
	scene.partner_despawned.connect(func():
		despawns.append(scene.distances[0])
		check(not scene.bikes[1].visible,"Partner hidden before repositioning"))
	scene.partner_spawned.connect(func():
		spawns.append(scene.distances[0])
		check(not scene.bikes[1].visible,"Spawn remains hidden until new pose is placed")
		check(absf(absf(scene.distances[1]-scene.distances[0])-10.0) < .001,"Next partner enters at approach distance"))
	var previous_player: float = scene.distances[0]
	for tick in range(9600):
		scene._step(1.0/120.0,300)
		if scene.distances[0] < scene.start_distance+125:
			check(not scene.partner_present and scene.page.progress.attempts == 0,"No partner or attempt before half a player lap")
		check(scene.distances[0] >= previous_player and scene.distances[0]-previous_player < .5,"Partner spawn never teleports the player")
		previous_player = scene.distances[0]
		if tick % 120 == 0:
			scene._present(1.0/60.0)
			await process_frame
	check(spawns.size() >= 2 and despawns.size() >= 2,"Partner despawns and respawns between attempts")
	check(absf(spawns[0]-(scene.start_distance+125)) < .5 if not spawns.is_empty() else false,"First spawn occurs after half a player lap")
	for i in range(1,spawns.size()): check(absf(spawns[i]-spawns[i-1]-250.0) < .5,"Exactly one partner spawn each player lap")
	check(spawns.size() == floori((scene.distances[0]-scene.start_distance+125.0)/250.0),"Every completed player lap offers a fresh attempt")
	print("PARTNER_RESPAWNS at=",spawns," despawns=",despawns)
	game.bridge_devices.close_page()
	var lane: int = scene.player_lane_target
	var a := InputEventKey.new(); a.keycode = KEY_A; a.pressed = true
	game._input(a)
	check(scene.player_lane_target == lane,"A is grab, not steering")
	a.pressed = false; game._input(a)
	game._process_steering(0); game._process_steering(50)
	check(scene.player_lane_target == lane+1,"Player keeps steering control (%s %d -> %d, running=%s)" % [game._ride_context(),lane,scene.player_lane_target,str(scene.session.running())])
	game.player_appearance.suit_id = "portugal"; scene._sync_kit()
	for bike in scene.bikes: check(bike.get_child(0).skinsuit_png.ends_with("portugal/skinsuit.png"),"Both teammates share the selected kit")
	check(game.race_mode == before.mode and game.rider_count == before.count and game.distances == before.distances and game.speeds == before.speeds and game.race_laps == before.laps,"All race arrays/settings remain unchanged by training")
	page.progress.reset_session(10)
	scene.pending_trial = false
	for i in range(10):
		scene.pending_trial = true
		scene._score(i < 7)
	scene.madison.cancel("Einde reeks")
	for tick in range(8):
		if scene.active: scene.advance(.25)
	check(not scene.active and menu.page == 16 and page.progress.advanced_unlocked,"7/10 ends the training in its own result page and unlocks Advanced")
	check(page.selected_activity.get("successes",0) == 7 and page.selected_activity.get("attempts",0) == 10,"Saved result includes training score")
	page._refresh(); check(not page.difficulty.is_item_disabled(1),"Unlocked Advanced becomes selectable")
	page.leave()
	check(not scene.active and menu.page == 11 and menu.menu_margin.visible,"Leaving restores Pistetraining")
	check(scene.bikes[0].get_child(0).exchange_overlay == null and scene.bikes[1].get_child(0).exchange_overlay == null,"Leaving removes animation overlays")
	check(menu.training_store.recent().size() >= 1 and menu.training_store.recent()[0].kind == "madison","Training saved in existing history")
	menu.show_training(); check(menu.training_page.visible,"ERG-training retained")
	menu.show_ftp(); check(menu.ftp_page.visible,"FTP training retained")
	menu.show_piste_exercise("free_ride"); check(menu.exercise_page.kind == "free_ride","Free training retained")
	menu.show_derny(); check(menu.derny_page.visible,"Derny training retained")
	menu.show_choices(); check(menu.choice_page.visible,"Existing competitions retained")
	game.queue_free(); await process_frame; await process_frame
	print("MADISON_V02_TRAINING_OK" if failures == 0 else "MADISON_V02_TRAINING_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
