extends SceneTree
const Visual := preload("res://rider_visual.gd")
const Game := preload("res://main.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.race_mode = 4
	game._configure_peloton()
	await process_frame
	for bike in game.bikes:
		check(bool(bike.get_child(0).get_meta("pursuit_mode", false)), "Pursuit flag propagated to both riders")
	var pursuit = game.bikes[0].get_child(0)
	check(pursuit.rig_scene.scene_file_path.ends_with("velodrome_pursuit.glb"), "Pursuit uses dedicated Blender export")
	check(pursuit.resolved_poses.size() == 4 and pursuit.animator != null, "Imported clips resolve")
	check(pursuit.rig_scene.find_child("Rider", true, false) != null and pursuit.rig_scene.find_child("Bike", true, false) != null, "Both meshes imported")
	pursuit.pedal(0.25, 90.0, 1200.0)
	check(pursuit.current_pose == 0 and not pursuit.standing_active and pursuit.standing_amount == 0.0, "High pursuit power preserves aero pose and no standing sway")
	check(absf(pursuit.cadence_phase - TAU * 0.375) < 0.00001, "Cadence still drives pedal phase")
	pursuit.set_victory(true)
	pursuit.pedal(0.1, 90.0, 200.0)
	check(pursuit.current_pose == 0, "Pursuit retains cockpit contact after finish")
	pursuit.finish_pose(false)
	check(pursuit.stopped, "Stopping supported")

	game.race_mode = 0
	game._configure_peloton()
	await process_frame
	for bike in game.bikes:
		check(not bool(bike.get_child(0).get_meta("pursuit_mode", false)), "Returning to scratch restores old model")
		var scratch = bike.get_child(0)
		check(scratch.rig_scene.scene_file_path.ends_with("velodrome_rider.glb"), "Scratch keeps original model")
		if bike == game.bikes[0]:
			scratch.pedal(0.25, 90.0, 1200.0)
			check(scratch.current_pose == 2 and scratch.standing_active, "Scratch retains standing sprint")
	game.free()
	print("PURSUIT_MODEL_OK" if failures == 0 else "PURSUIT_MODEL_FAILED")
	quit(0 if failures == 0 else 1)
