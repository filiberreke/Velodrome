extends SceneTree
class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var game = TestRace.new(); root.add_child(game)
	game.race_mode = 1; game.rider_count = 16; game.race_laps = 40
	game._configure_peloton(); game.rider_forms.fill(1.0)
	game.x_ai.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
	var seeded := RandomNumberGenerator.new(); seeded.seed = 1001
	for i in range(1,16):
		game.x_ai.cooldown[i] = seeded.randf_range(50.0,120.0)
		game.x_ai.cooperation[i] = seeded.randf_range(0.20,0.70) if game.rider_profiles[i] == 2 else seeded.randf_range(0.35,0.95)
		game.x_ai.aggression[i] = seeded.randf_range(0.25,0.65) + (0.22 if game.rider_profiles[i] == 3 else 0.0)
	game.x_ai.rng.seed = 1001
	game.running = true; game.start_state = "RACING"; game.watts = 300.0
	var actions := {"sprint":0,"abort":0,"skip":0}
	var snapshot35: Array[float] = []
	var dt := 1.0 / 60.0
	for tick in range(120000):
		game.clock += dt; game._advance_race(dt)
		check(game.watts == 300.0,"Tactic changed human watts")
		for i in range(1,16):
			check(game.x_ai.wprime[i] >= 0.0 and game.x_ai.wprime[i] <= game.x_ai.wmax[i],"Nonfinite energy")
			var decision: Dictionary = game.x_ai.intermediate_sprint.last_decisions[i]
			if not decision.is_empty():
				actions[String(decision.action)] += 1
		if snapshot35.is_empty() and game._race_positions().max() >= 35.0 * 250.0:
			snapshot35.assign(game.x_ai.wprime)
		if game._all_riders_finished(): break
	check(game._all_riders_finished() and game.points_rules.complete(),"40-lap race failed to complete at 60 Hz")
	check(game.points_rules.sprints.size() == 4,"Four sprints expected")
	var sprint_points := 0
	for sprint in game.points_rules.sprints:
		check(sprint.order.size() == 16,"Incomplete sprint order")
		for award in sprint.awards: sprint_points += award
	check(sprint_points == 55,"Sprint total changed")
	var net := 0; var total := 0
	for credit in game.points_rules.credits: net += credit
	for points in game.points_rules.points: total += points
	check(total == 55 + 20 * net,"Points not conserved")
	for event in game.points_rules.events:
		check(event.seconds <= game.points_rules.finish_clock,"Lap scoring after finish")
	check(actions.sprint > 0 and actions.skip > 0 and actions.abort > 0,"New tactic not exercised")
	check(snapshot35.size() == 16,"Lap-35 snapshot missing")
	var winner := 0
	for i in range(1,16):
		if game.points_rules.better(i,winner,game.distances): winner = i
	var report := {"engine":Engine.get_version_info().string,"seed":1001,"laps":40,"track_m":250,"riders":16,"ai_riders":15,"human_watts":300.0,"hz":60,"seconds":game.clock,"winner":winner,"winner_profile":game.rider_profiles[winner],"points":game.points_rules.points,"lap_credits":game.points_rules.credits,"wprime35_j":snapshot35,"decision_frames":actions,"aborts":game.x_ai.intermediate_sprint.aborts,"failures":failures}
	var file := FileAccess.open("res://verification/tussensprint/godot_race_smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("INTERMEDIATE_SPRINT_RACE ",JSON.stringify(report))
	game.free()
	print("INTERMEDIATE_SPRINT_RACE_OK" if failures == 0 else "INTERMEDIATE_SPRINT_RACE_FAILED")
	quit(0 if failures == 0 else 1)
