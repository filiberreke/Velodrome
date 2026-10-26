extends SceneTree
const Rules := preload("res://points_race_rules.gd")
class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var jury = Rules.new()
	jury.reset(4)
	var ends: Array[float] = [-1.,-1.,-1.,-1.]
	jury.advance([2498.,2248.,2497.,2497.], [2502.,2251.,2501.,2500.5], 12.,2.,ends)
	check(jury.sprints.size() == 1 and jury.sprints[0].order == [0,1,2,3], "Physical sprint order includes a lapped rider")
	check(jury.sprints[0].awards == [5,3,2,1], "Intermediate points")
	var total: int = jury.points.reduce(func(a: int, b: int) -> int: return a+b,0)
	jury.advance([2502.,2251.,2501.,2500.5], [2502.,2251.,2501.,2500.5],14.,2.,ends)
	check(total == jury.points.reduce(func(a: int, b: int) -> int: return a+b,0), "No repeated score without new passages")
	jury.reset(5)
	jury._judge_laps([1002.,1004.,1006.,1008.,1252.],10.)
	check(jury.gains[4] == 1, "Catch bunch rear wins a lap")
	jury._judge_laps([1002.,1004.,1006.,1008.,1252.],11.)
	check(jury.gains[4] == 1, "Same catch cannot be repeated")
	jury._judge_laps([1002.,1004.,1006.,1008.,1502.],12.)
	check(jury.gains[4] == 2, "Second lap gain supported")
	jury._judge_laps([1002.,1004.,1006.,1008.,1250.],13.)
	check(jury.losses[4] == 1 and jury.points[4] == 20, "Lap loss and net points")
	jury.reset(4)
	jury._judge_laps([1246.,1249.,1252.,1496.],10.)
	check(jury.gains[3] == 1,"Bunch wraps the start line")
	jury.reset(4)
	jury._judge_laps([1000.,1060.,1120.,1430.],10.)
	check(jury.events.is_empty(), "No invented main bunch in dispersed field")
	jury.reset(4)
	ends.fill(-1.)
	jury.advance([9998.,9499.,9748.,9997.], [10002.,9503.,9752.,10000.5],22.,2.,ends)
	check(jury.finish_clock == 21. and jury.sprints[-1].order == [0,2,3], "Common finish and exclude earlier lapped passage")
	check(jury.sprints[-1].awards == [10,6,4], "Doubled finish points")
	jury.advance([10002.,9503.,9752.,10000.5], [10002.,9752.,9752.,10000.5],52.,30.,ends)
	check(jury.complete() and ends[1] > ends[0], "Lapped rider finishes next line, not own 40 laps")
	jury.points.assign([10,10,0,0])
	check(jury.better(0,1,[10002.,9752.,9752.,10000.5]), "Final sprint breaks equal points")
	var game = TestRace.new()
	root.add_child(game)
	game.race_mode = 1; game.rider_count = 16; game.race_laps = 40
	game._configure_peloton()
	game.rider_forms.fill(1.0)
	game.x_ai.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
	game.x_ai.rng.seed = 1001
	check(game.points_rules.points.size() == 16,"Jury covers entire field including player")
	check(game.x_ai.cp[1] == 265. and game.x_ai.cp[2] == 240.,"Accepted CP values")
	check(game.x_ai.wmax[1] == 24120.4 and game.x_ai.pmax[2] == 1661.88,"Wprime and peak unchanged")
	check(game.distances[12] < game.distances[6] and game.distances[6] < game.distances[0],"Three-row 16-rider grid")
	game.running=true; game.start_state="RACING"; game.watts=300.
	var dt := 0.1
	for tick in range(18000):
		game.clock += dt
		game._advance_race(dt)
		if game._all_riders_finished(): break
	check(game._all_riders_finished() and game.points_rules.complete(),"Entire 40-lap race completes")
	check(game.points_rules.sprints.size() == 4,"Exactly four sprints")
	var sprint_total := 0
	for sprint in game.points_rules.sprints:
		check(sprint.order.size() == 16,"Every rider appears once per sprint")
		for award in sprint.awards: sprint_total += award
	check(sprint_total == 55,"Correct total sprint points")
	var net := 0
	var score := 0
	for value in game.points_rules.credits: net += value
	for value in game.points_rules.points: score += value
	check(score == 55 + 20 * net,"Conserved points including lap events")
	for event in game.points_rules.events:
		check(event.seconds <= game.points_rules.finish_clock,"No lap scoring after common finish")
	for i in range(game.rider_count):
		check(game.x_ai.wprime[i] >= 0. and game.x_ai.wprime[i] <= game.x_ai.wmax[i],"Finite energy reserve")
	var locked: Array[float] = game.distances.duplicate()
	game.clock += dt; game._advance_race(dt)
	check(game.distances == locked,"Finished riders remain frozen")
	print("POINTS_GAMEPLAY ",JSON.stringify({"seconds":game.clock,"points":game.points_rules.points,"laps":game.points_rules.credits}))
	game.free()
	var realtime = TestRace.new()
	root.add_child(realtime)
	realtime.race_mode = 1; realtime.rider_count = 16; realtime.race_laps = 10
	realtime._configure_peloton()
	realtime.x_ai.rng.seed = 1002
	realtime.running = true; realtime.start_state = "RACING"; realtime.watts = 315.
	for tick in range(36000):
		realtime.clock += 1.0 / 60.0
		realtime._advance_race(1.0 / 60.0)
		if realtime._all_riders_finished(): break
	check(realtime._all_riders_finished() and realtime.points_rules.complete(), "Sixteen-rider race finishes at normal 60 Hz")
	check(realtime.points_rules.sprints.size() == 1 and realtime.points_rules.sprints[0].awards.slice(0,4) == [10,6,4,2], "Ten-lap race has one double final")
	realtime.free()
	print("POINTS_RACE_OK" if failures == 0 else "POINTS_RACE_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
