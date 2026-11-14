extends SceneTree

class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var g := Game.new()
	root.add_child(g)
	for mode in [0, 1, 2, 3, 8]:
		g.race_mode = mode; g.rider_count = 4; g.race_laps = 40; g._configure_peloton()
		g.speeds.fill(14.0); g.lane_offsets.fill(1.18)
		# Test both the player and AI as follower, on a straight, bend and finish wrap.
		for follower in [0, 1]:
			var wheel: int = 1 - follower
			for position in [50.0, 100.0, 248.0]:
				g.distances.fill(position + 100.0)
				g.distances[follower] = position + 750.0
				g.distances[wheel] = g.distances[follower] + 3.0
				var reference: float = g._draft_target(follower)
				check(reference > 0.0, "Same-lap wheel gives shelter, mode %d" % mode)
				# Positive: wheel lapped follower. Negative: follower lapped wheel.
				for lap_delta in [-2, -1, 1, 2]:
					g.distances[wheel] = g.distances[follower] + 3.0 + lap_delta * g.LAP
					g._lap_credits()[follower] = -lap_delta
					var before: Array[float] = g.distances.duplicate()
					var credits: Array[int] = g._lap_credits().duplicate()
					check(is_equal_approx(g._draft_target(follower), reference) and g.draft_leaders[follower] == wheel,
						"Lap difference preserves wheel shelter: mode %d follower %d laps %d position %.0f" % [mode, follower, lap_delta, position])
					g.draft_strengths.fill(0.0)
					g._update_drafting(1.0)
					check(g._draft_drag_reduction(follower) > 0.0, "Shelter reaches physics/HUD")
					check(g.distances == before and g._lap_credits() == credits, "Drafting preserves progress and lap loss/gain")
					g.distances[wheel] -= 6.0
					check(is_zero_approx(g._draft_target(follower)), "Wheel physically behind gives no shelter")
					g.distances[wheel] += 6.0; g.lane_offsets[wheel] += 3.0
					check(is_zero_approx(g._draft_target(follower)), "Separate lane gives no shelter")
					g.lane_offsets[wheel] -= 3.0; g.finish_times[wheel] = 1.0
					check(is_zero_approx(g._draft_target(follower)), "Finished wheel gives no shelter")
					g.finish_times[wheel] = -1.0
				g._lap_credits().fill(0)
	# Pursuit and solo events still disable drafting even with a nearby wheel.
	for mode in [4, 5, 7]:
		g.race_mode = mode
		check(is_zero_approx(g._draft_target(0)), "No drafting in pursuit/solo mode %d" % mode)
	g.free()
	print("LAPPED_DRAFTING failures=", failures)
	quit(0 if failures == 0 else 1)
