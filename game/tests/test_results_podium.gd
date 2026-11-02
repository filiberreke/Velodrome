extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func complete(game) -> void:
	for i in game.rider_count: game.finish_times[i] = 100.0 + i
func run_test() -> void:
	var game := Game.new();root.add_child(game);game.set_physics_process(false)
	for i in range(3):await process_frame
	game.setup_panel.select_mode(0);game._confirm_start();game.broadcast_intro.finish()
	complete(game)
	game.scratch_rules.credits[3] = 1
	var positions: Array[Vector3] = []
	for bike in game.bikes: positions.append(bike.position)
	var identities: Array = game.rider_identities.duplicate(true)
	var podium := game.find_child("Podium",true,false) as Node3D
	game.results_podium.update(game,podium)
	check(game.results_podium.riders == [3,0,1], "Scratch podium follows credited laps rather than raw finish times")
	var actor_root = game.results_podium.root
	for place in range(3):
		var holder = actor_root.get_node("Place%d" % (place+1))
		var index: int = [3,0,1][place]
		check(holder.get_meta("rider_index") == index and holder.position == game.results_podium.STEPS[place], "Correct actual rider is placed on the correct physical step")
		var visual = holder.get_child(0)
		var source = game.bikes[index].get_child(0)
		check(not visual.rig_scene.find_child("Bike",true,false).visible, "Podium athletes stand without a bicycle")
		for key in preload("res://player_appearance.gd").KEYS:
			check(visual.get(key) == source.get(key), "Podium retains actual race outfit: " + key)
		check(visual.get_meta("body_shapes") == game.rider_identities[index].get("morphs",{}), "Podium keeps selected rider's body profile")
		var skeleton = visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		check(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin.y > 1.5, "Podium pose has an upright torso")
	for i in range(4): game.results_podium.update(game,podium)
	check(game.results_podium.root == actor_root and actor_root.get_child_count() == 6, "Repeated result refreshes reuse the podium actors")
	check(game.rider_identities == identities, "Podium does not mutate racing identities")
	for i in game.rider_count: check(game.bikes[i].position == positions[i], "Actual racers remain in place for coasting and finish photos")
	game.finish_times[7] = -1.0;game.results_podium.update(game,podium)
	check(game.results_podium.root == null, "Incomplete results never award provisional podium places")
	game.race_mode = 1;game.rider_count = 8;game._configure_peloton();complete(game)
	game.points_rules.points.assign([1,9,3,8,2,4,5,6])
	game.results_podium.update(game,podium)
	check(game.results_podium.riders == [1,3,7], "Points podium uses the points jury's classification")
	game.race_mode = 2;game.rider_count = 4;game._configure_peloton();complete(game)
	game.elimination_rules.eliminated.assign([2,0])
	game.finish_times.assign([60.0,89.0,50.0,90.0])
	game.results_podium.update(game,podium)
	check(game.results_podium.riders == [1,3,0], "Elimination podium uses final sprint and reverse elimination order")
	game.race_mode = 4;game._configure_peloton();complete(game)
	game.results_podium.update(game,podium)
	check(game.results_podium.riders.size() == 2 and not game.results_podium.root.has_node("Place3"), "A two-rider pursuit never invents a third finisher")
	game.race_mode = 5;game.team_size = 3;game._configure_peloton();complete(game)
	game.team_race.times.assign([72.0,70.0])
	game.results_podium.update(game,podium)
	check(game.results_podium.riders == [3,0], "Team results show representatives of the two classified teams")
	game._reset()
	check(game.results_podium.root == null, "Restart removes the previous ceremony")
	game.free()
	print("RESULTS_PODIUM failures=",failures)
	quit(0 if failures == 0 else 1)
