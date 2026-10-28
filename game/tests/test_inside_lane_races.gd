extends SceneTree
class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _register_performance() -> void: pass
var failures := 0
var results: Array[Dictionary] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_one(mode: int, seed_value: int, prefer_inside: bool) -> Dictionary:
	var game = TestRace.new();root.add_child(game)
	game.race_mode = mode;game.rider_count = 16;game.race_laps = 20
	game._configure_peloton();game.rider_forms.fill(1.0)
	game.x_ai.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
	var seeded := RandomNumberGenerator.new();seeded.seed = seed_value
	for i in range(1,16):
		game.x_ai.cooldown[i] = seeded.randf_range(50.0,120.0)
		game.x_ai.cooperation[i] = seeded.randf_range(0.20,0.70) if game.rider_profiles[i] == 2 else seeded.randf_range(0.35,0.95)
		game.x_ai.aggression[i] = seeded.randf_range(0.25,0.65) + (0.22 if game.rider_profiles[i] == 3 else 0.0)
	game.x_ai.rng.seed = seed_value
	game.x_ai.prefer_inside_when_free = prefer_inside
	game.watts = 300.0;game.running = true;game.start_state = "RACING"
	var observed := 0.0;var inside := 0.0;var offset_sum := 0.0
	var inner_targets := 0.0
	var per_profile := {1:{"seconds":0.0,"inside":0.0},2:{"seconds":0.0,"inside":0.0},3:{"seconds":0.0,"inside":0.0}}
	var dt := 0.1
	for tick in range(18000):
		game.clock += dt;game._advance_race(dt)
		check(game.watts == 300.0,"Human power changed")
		for i in range(1,16):
			check(game.x_ai.wprime[i] >= 0.0 and game.x_ai.wprime[i] <= game.x_ai.wmax[i],"Energy bounds")
			check(game.lane_offsets[i] >= 1.18 - 0.00001 and game.lane_offsets[i] <= 7.18 + 0.00001,"Lane bounds")
			if game.finish_times[i] >= 0.0 or game.clock < 20.0: continue
			observed += dt;offset_sum += game.lane_offsets[i] * dt
			per_profile[game.rider_profiles[i]].seconds += dt
			if game.lane_offsets[i] <= 1.53:
				inside += dt;per_profile[game.rider_profiles[i]].inside += dt
			if game.x_ai.lane_targets[i] <= 1.53: inner_targets += dt
		if game._all_riders_finished():break
	check(game._all_riders_finished(),"All riders finish lane-preference race")
	if mode == 1:
		check(game.points_rules.complete() and game.points_rules.sprints.size() == 2,"Points jury completes both sprints")
		var sprint_total := 0;var net := 0;var total := 0
		for sprint in game.points_rules.sprints:
			for award in sprint.awards:sprint_total += award
		for credit in game.points_rules.credits:net += credit
		for score in game.points_rules.points:total += score
		check(sprint_total == 33 and total == 33 + 20*net,"Unchanged points accounting")
	var report := {"mode":"scratch" if mode == 0 else "points","seed":seed_value,"prefer_inside":prefer_inside,"laps":20,"riders":16,"ai_riders":15,"dt":dt,"finish_s":game.clock,"ai_rider_seconds":observed,"inside_seconds":inside,"inside_pct":100.0*inside/observed,"inner_target_pct":100.0*inner_targets/observed,"mean_lane_offset_m":offset_sum/observed,"by_profile":per_profile}
	game.free()
	return report
func run_tests() -> void:
	for mode in [0,1]:
		for seed_value in [1001,1002]:
			for enabled in [false,true]:
				var report := run_one(mode,seed_value,enabled)
				results.append(report)
				print("INSIDE_LANE_RACE ",JSON.stringify(report))
	var comparisons: Array[Dictionary] = []
	for mode in ["scratch","points"]:
		var before_inside := 0.0;var before_time := 0.0;var after_inside := 0.0;var after_time := 0.0
		for result in results:
			if result.mode != mode: continue
			if result.prefer_inside:after_inside += result.inside_seconds;after_time += result.ai_rider_seconds
			else:before_inside += result.inside_seconds;before_time += result.ai_rider_seconds
		var before: float = 100.0*before_inside/before_time
		var after: float = 100.0*after_inside/after_time
		check(after > before,"Inside preference should increase actual inner-lane use in %s" % mode)
		comparisons.append({"mode":mode,"before_inside_pct":before,"after_inside_pct":after})
	var file := FileAccess.open("res://verification/inside_lane/races.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"races":results,"comparison":comparisons,"failures":failures},"\t")+"\n");file.close()
	print("INSIDE_LANE_COMPARISON ",JSON.stringify(comparisons))
	print("INSIDE_LANE_RACES_OK" if failures == 0 else "INSIDE_LANE_RACES_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
