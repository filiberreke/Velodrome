extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _pc_power(_dt: float) -> float: return 300.0
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func fixture():
	var g := Game.new(); root.add_child(g)
	g.race_mode = 3; g.rider_count = 6; g._configure_peloton()
	g.keirin.phase = "FREE"; g.keirin.exit_time = 0.0
	g.distances.assign([900.0, 900.4, 950.0, 960.0, 970.0, 980.0])
	g.speeds.assign([20.0, 5.0, 12.0, 12.0, 12.0, 12.0])
	g.lane_offsets.fill(g.LANES[0]); g.x_ai.lane_targets.fill(g.LANES[0])
	g.player_lane = 0
	return g
func run_test() -> void:
	var g = fixture()
	g.keirin._free_step(g, 0.25, 10.25)
	check(g.distances[0] > g.distances[1], "Human player can pass through a slower rider in the same lane")
	check(g.speeds[0] > 15.0, "Slower rider does not cap human speed")
	g.free()
	g = fixture()
	g.speeds.fill(15.0); g.distances[1] = 900.1
	g.lane_offsets[1] = g.LANES[2]; g.x_ai.lane_targets[1] = g.LANES[2]
	g.player_lane = 2
	g.keirin._free_step(g, 0.1, 10.1)
	check(g.lane_offsets[0] > g.LANES[0], "Human can steer across an occupied passing corridor")
	g.free()
	# A player crossing just ahead must not stop the AI rider behind.
	g = fixture()
	g.distances[0] = 900.4; g.distances[1] = 900.0
	g.speeds[0] = 5.0; g.speeds[1] = 20.0
	g.keirin._free_step(g, 0.25, 10.25)
	check(g.distances[1] > g.distances[0], "AI can pass through the player without a hard boundary")
	check(g.speeds[1] > 15.0, "Overlapping player does not abruptly stop AI")
	g.free()
	# The same freedom applies between AI riders, including diagnostic rider zero.
	g = fixture(); g.x_ai.all_ai = true
	g.keirin._free_step(g, 0.25, 10.25)
	check(g.distances[0] > g.distances[1], "AI diagnostic rider can pass slower traffic")
	check(g.speeds[0] > 15.0, "AI diagnostic rider retains physical speed integration")
	g.free()
	g = fixture()
	g.distances[1] = 900.0; g.distances[2] = 900.4
	g.speeds[1] = 20.0; g.speeds[2] = 5.0
	g.keirin._free_step(g, 0.25, 10.25)
	check(g.distances[1] > g.distances[2], "AI can pass through another AI rider")
	check(g.speeds[1] > 15.0, "Slower AI does not impose a hard speed cap")
	g.free()
	print("KEIRIN_PLAYER_TRAFFIC failures=", failures)
	quit(1 if failures else 0)
