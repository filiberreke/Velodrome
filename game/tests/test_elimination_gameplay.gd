extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_elimination_photo(_rider: int, _line_m: float) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func race(count: int) -> Game:
	var g := Game.new(); root.add_child(g)
	g.race_mode = 2; g.rider_count = count; g.race_laps = (count - 2) * 2 + 2
	g.elimination_notice = Label.new(); g.add_child(g.elimination_notice)
	g._configure_peloton(); g.rider_forms.fill(1.0)
	g.x_ai.reset(g.rider_profiles,g.rider_forms,g.lane_offsets)
	g.x_ai.configure_riders(g.rider_identities,g.rider_forms)
	g.running = true; g.start_state = "RACING"; g.watts = 300.0
	return g
func run_test() -> void:
	# Full 4/12/16-rider elimination races, including the final pair.
	for count in [4,12,16]:
		var g := race(count)
		var cruise_spans: Array[float] = []
		var launch_checked := false
		var invalid := false
		while not g._all_riders_finished() and g.clock < 1800.0:
			g.clock += 0.1; g._update_race(0.1)
			if not launch_checked and g.clock >= 1.0:
				launch_checked = true
				check(g.ai_power_w[1] >= 340.0 and g.ai_power_w[1] <= 451.0,"Launch uses the scratch/points standing-start watts")
			var active: Array[float] = []
			for i in range(count):
				if not is_finite(g.distances[i]) or not is_finite(g.speeds[i]) or g.speeds[i] < 0.0: invalid = true
				if i > 0 and (g.x_ai.wprime[i] < -0.01 or g.x_ai.wprime[i] > g.x_ai.wmax[i] + 0.01): invalid = true
				if i > 0 and g.finish_times[i] < 0.0: active.append(g.distances[i])
			# Measure settled cruising, after the standing start and before
			# the first 200 m elimination positioning/sprint window.
			if g.clock > 30.0 and g.distances.max() < 300.0 and active.size() > 1:
				cruise_spans.append(active.max() - active.min())
		check(not invalid,"Finite physics and bounded W-prime throughout elimination")
		if not g._all_riders_finished():
			print("STALLED line=",g.elimination_rules.next_line_m," active=",g.elimination_rules.active," crossings=",g.elimination_rules.crossing_s," distance=",g.distances," finishes=",g.finish_times)
		check(g._all_riders_finished(),"All riders complete elimination and final sprint")
		check(g.elimination_rules.eliminated.size() == count - 2,"Exactly count minus two unique eliminations")
		var mean_span := 0.0
		for span in cruise_spans: mean_span += span / maxf(1.0,cruise_spans.size())
		print("ELIMINATION_RACE count=%d seconds=%.1f cruise_ai_span_m=%.1f" % [count,g.clock,mean_span])
		# Observe bunch spread without retaining the old elimination-only
		# traffic calibration. The shared scratch/points passing policy changes
		# spacing; pace demand, launch envelope and CP/W-prime remain tested.
		check(not cruise_spans.is_empty(),"Cruising pace is sampled before the first elimination sprint")
		g.free()
	print("ELIMINATION_GAMEPLAY failures=",failures)
	quit(0 if failures == 0 else 1)
