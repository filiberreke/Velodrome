extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _save_recording(_reason: String) -> void: pass
	func _load_rider_config() -> void: rider_config_ready = true
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
var game
var baseline

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func frame(dt: float = 1.0 / 60.0) -> void:
	game._update_visuals(dt)
	baseline.pedal(dt, clampf(game.speeds[0] * 6.0, 0.0, 120.0), game.watts)
	await process_frame

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.camera = Camera3D.new(); game.add_child(game.camera)
	game.race_mode = 6; game.madison_advanced = true
	game.madison_progress = preload("res://madison_progress.gd").new("user://animation_test_progress.cfg")
	game._configure_peloton()
	game.running = true; game.start_state = "RACING"; game.clock = 10.0; game.watts = 250.0
	baseline = preload("res://rider_visual.gd").new()
	root.add_child(baseline)
	for scenario in [[90.0,2.38], [90.0,2.98], [90.0,1.84], [20.0,2.38]]:
		game.madison_animation = null
		game.madison.reset()
		game.distances.assign([scenario[0],scenario[0]])
		game.lane_offsets.assign([scenario[1],3.58])
		game.speeds.assign([12.0,10.0]); game.baseline_speed = 12.0
		for tick in range(90):
			game.madison.step(game, 1.0/60.0)
			await frame()
		check(game.madison.can_grab, "Gameplay approach reaches grab window: %s" % str(scenario))
		var a: Node3D = game.bikes[0].get_child(0)
		var b: Node3D = game.bikes[1].get_child(0)
		check(baseline.exchange_overlay == null, "Unrelated rider has no tree or IK")
		game._madison_button("test", true)
		for tick in range(12):
			game.madison.step(game, 1.0/60.0)
			await frame()
		check(game.madison.phase == game.MadisonExchange.Phase.SLING, "Button starts real animated sling")
		var worst := 0.0
		for t in [0.0,0.2,0.6,0.95]:
			game.madison.sling_t = t
			game.madison.efficiency = game.madison.precision * game.madison.envelope(t)
			await frame()
			var adapter = game.madison_animation
			check(is_equal_approx(adapter.rig_g.sling_t, t) and is_equal_approx(adapter.rig_r.sling_t, t), "Both animations sample the HUD sling_t")
			var err: float = adapter.rig_g.anchor_world().distance_to(adapter.rig_r.anchor_world())
			worst = maxf(worst, err)
			check(err < 0.005, "Actual track hand contact below 5 mm (%s t=%.2f: %.3f mm)" % [str(scenario),t,err*1000.0])
			var sk: Skeleton3D = a.rig_scene.find_child("Skeleton3D",true,false)
			var normal: Skeleton3D = baseline.rig_scene.find_child("Skeleton3D",true,false)
			for bone in ["crank","upper_leg.L","lower_leg.L","upper_leg.R","lower_leg.R"]:
				var idx := sk.find_bone(bone)
				if idx >= 0: check(sk.get_bone_pose_rotation(idx).angle_to(normal.get_bone_pose_rotation(normal.find_bone(bone))) < 0.002, "Pedal bones keep their crank phase")
		print("GAME_CONTACT ",scenario," max_mm=",worst*1000.0)
		game._madison_button("test", false)
		for tick in range(110):
			game.madison.step(game, 1.0/60.0)
			await frame()
		check(a.exchange_overlay == null and b.exchange_overlay == null, "Separation removes overlays")
		check(not a.animator.has_animation_library("madison") and not b.animator.has_animation_library("madison"), "Separation removes both temporary libraries")
		check(a.rig_scene.position.is_zero_approx() and b.rig_scene.position.is_zero_approx(), "Visual model offsets restore after release")
		game.madison_animation.clear()
		game.madison_animation.queue_free()
		game.madison_animation = null
		await process_frame
	# Real force/banking/lane integration during a held exchange.
	game.madison.reset()
	game.player_lane = 2
	game.distances.assign([90.0,90.0]); game.lane_offsets.assign([2.38,3.58])
	game.speeds.assign([12.0,11.0]); game.baseline_speed = 12.0
	for tick in range(70):
		game.madison.step(game,1.0/60.0)
		await frame()
	game._madison_button("test",true)
	var saw_sling := false
	var moving_error := 0.0
	for tick in range(240):
		game.clock += 1.0/60.0
		game._update_race(1.0/60.0)
		await frame()
		if game.madison.phase == game.MadisonExchange.Phase.SLING:
			saw_sling = true
			var adapter = game.madison_animation
			moving_error = maxf(moving_error, adapter.rig_g.anchor_world().distance_to(adapter.rig_r.anchor_world()))
			if game.madison.sling_t >= 0.6: game._madison_button("test",false)
		if not game.madison.active: break
	check(saw_sling and game.madison.active_rider == 1, "Live physics and A input complete an animated exchange")
	check(moving_error < 0.005, "Moving gameplay contact below 5 mm: %.3f mm" % (moving_error*1000.0))
	print("MOVING_GAME_CONTACT max_mm=",moving_error*1000.0," reason=",game.madison.release_reason," efficiency=",game.madison.efficiency)
	# Steering out of reach is a controlled early release rather than a stretched arm.
	game.madison.active = true
	game.madison.phase = game.MadisonExchange.Phase.SLING
	game.madison.sling_t = 0.2
	game.madison.release_for_reach()
	check(game.madison.phase == game.MadisonExchange.Phase.RELEASE and game.madison.release_reason == "reach", "Reach limit requests controlled release")
	game.madison.reset()
	await frame()
	baseline.queue_free(); game.queue_free()
	await process_frame
	await process_frame
	print("MADISON_GAME_ANIMATION_OK" if failures == 0 else "MADISON_GAME_ANIMATION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
