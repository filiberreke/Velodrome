extends SceneTree
const Policy := preload("res://points_intermediate_sprint.gd")
const PointsAI := preload("res://points_ai.gd")
const Rules := preload("res://points_race_rules.gd")
var failures := 0
var decisions_checked := 0

class FixtureJury extends RefCounted:
	var points: Array[int] = []
	var lap := 10
	var finish_clock := -1.0
	func next_sprint_lap() -> int: return lap

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_tests")

func floats(values: Array) -> Array[float]:
	var result: Array[float] = []; result.assign(values); return result

func ints(values: Array) -> Array[int]:
	var result: Array[int] = []; result.assign(values); return result

func compare_policy_to_python() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/intermediate_sprint_policy_cases.json"))
	for fixture in cases:
		var ai = PointsAI.new()
		var profiles: Array[int] = ints(fixture.profiles)
		var forms: Array[float] = []; forms.resize(profiles.size()); forms.fill(1.0)
		var lanes: Array[float] = []; lanes.resize(profiles.size()); lanes.fill(1.18)
		ai.reset(profiles, forms, lanes)
		ai.cp.assign(fixture.cp); ai.wmax.assign(fixture.wmax)
		ai.pmax.assign(fixture.pmax); ai.wprime.assign(fixture.w)
		var finished: Array[float] = []; finished.resize(profiles.size()); finished.fill(-1.0); finished[0] = 0.0
		var jury = FixtureJury.new(); jury.lap = int(fixture.lap); jury.points.assign(fixture.points)
		var policy = Policy.new(); policy.reset(profiles.size())
		for ident in fixture.attempting: policy.attempting[int(ident)] = true
		policy.prepare(ai, floats(fixture.distance), floats(fixture.speed), finished, profiles, 40, float(fixture.leader), jury)
		# Snapshot must remain stable after another rider's Phys step.
		ai.wprime.fill(0.0)
		for expected in fixture.expected:
			var ident: int = int(expected.id)
			var output: float = policy.demand(ident, 300.0, profiles[ident])
			var actual: Dictionary = policy.last_decisions[ident]
			check(actual.action == expected.action, "%s rider %d action differs from Python" % [fixture.name, ident])
			for key in ["p5", "p3", "p2", "p1", "expected_points", "reserve_j", "w_j", "target_w"]:
				check(absf(float(actual[key]) - float(expected[key])) < 0.00001, "%s rider %d %s differs from Python" % [fixture.name, ident, key])
			check(absf(output - float(expected.target_w)) < 0.00001, "Demand differs from fixture")
			decisions_checked += 1
		if fixture.name == "hopeless_abort":
			check(policy.aborts[16] == 1 and not policy.attempting[16], "Hopeless sprint aborts")
		policy.reset(profiles.size())
		check(policy.aborts.count(0) == profiles.size() and not policy.prepared, "Reset clears tactical state")

func equivalent_ai_pair(laps: int, sprint_lap: int, head: float) -> void:
	var profiles: Array[int] = [0,1,2,3,1,2,3,1]
	var forms: Array[float] = [1.,1.,1.,1.,1.,1.,1.,1.]
	var lanes: Array[float] = [1.18,1.18,2.38,3.58,4.78,5.98,7.18,1.18]
	var speeds: Array[float] = [12.,12.,12.,12.,12.,12.,12.,12.]
	var drafts: Array[float] = [0.0,0.7,0.5,0.4,0.6,0.5,0.4,0.3]
	var finished: Array[float] = [-1.,-1.,-1.,-1.,-1.,-1.,-1.,-1.]
	var credits: Array[int] = [0,0,0,0,0,0,0,0]
	var distances: Array[float] = []
	for i in range(profiles.size()): distances.append(head - i * 2.0)
	var a = PointsAI.new(); var b = PointsAI.new()
	a.reset(profiles,forms,lanes); b.reset(profiles,forms,lanes)
	b.cooldown.assign(a.cooldown); b.cooperation.assign(a.cooperation); b.aggression.assign(a.aggression)
	a.rng.seed = 991; b.rng.seed = 991
	a.human_power_w = 300.0; b.human_power_w = 300.0
	a.intermediate_sprint_enabled = false
	for ai in [a,b]:
		ai.jury = Rules.new(); ai.jury.reset(profiles.size(),laps)
		for lap in range(10,sprint_lap,10):
			ai.jury.sprints.append({"lap":lap,"order":range(profiles.size())})
	for tick in range(5):
		var pa: Array[float] = a.step(1.0/60.0,200.0+tick/60.0,distances,speeds,lanes,drafts,finished,profiles,laps,80.0,credits)
		var pb: Array[float] = b.step(1.0/60.0,200.0+tick/60.0,distances,speeds,lanes,drafts,finished,profiles,laps,80.0,credits)
		check(pa == pb and a.wprime == b.wprime and a.fatigue == b.fatigue, "Final or outside-window AI output changed")
		check(pb[0] == 0.0 and b.wprime[0] == 0.0 and b.human_power_w == 300.0,"Human watts/energy untouched")
	check(b.cp[1] == 265.0 and b.cp[2] == 240.0 and b.cp[3] == 250.0,"CP unchanged")
	check(b.wmax[1] == 24120.4 and b.pmax[2] == 1661.88,"Wmax and peak unchanged")

func check_human_and_finished_forecast() -> void:
	var ai = PointsAI.new()
	ai.reset([0,1,2,3],[1.,1.,1.,1.],[1.18,2.38,3.58,4.78])
	ai.human_power_w = 500.0
	var jury = FixtureJury.new(); jury.points.assign([0,0,0,0])
	var policy = Policy.new(); policy.reset(4)
	policy.prepare(ai,[2400.,2398.,2396.,2394.],[13.,12.,12.,12.],[-1.,-1.,0.,-1.],[0,1,2,3],40,2400.,jury)
	check(policy.etas.has(0) and not policy.etas.has(2),"Forecast includes human and excludes finished rider")
	check(policy.demand(0,500.,0) == 500.,"Policy cannot control human")
	policy.demand(1,300.,1)
	check(not policy.last_decisions[1].is_empty(),"AI decision diagnostic available")
	jury.finish_clock = 100.0
	policy.prepare(ai,[2400.,2398.,2396.,2394.],[13.,12.,12.,12.],[-1.,-1.,0.,-1.],[0,1,2,3],40,2400.,jury)
	check(not policy.prepared and policy.demand(1,300.,1) == 300.,"No intermediate sprint after finish")

func run_tests() -> void:
	compare_policy_to_python()
	equivalent_ai_pair(40,40,9900.0)
	equivalent_ai_pair(10,10,2400.0)
	equivalent_ai_pair(40,10,1200.0)
	check_human_and_finished_forecast()
	print("INTERMEDIATE_SPRINT_POLICY ", JSON.stringify({"python_decisions":decisions_checked,"failures":failures}))
	print("INTERMEDIATE_SPRINT_OK" if failures == 0 else "INTERMEDIATE_SPRINT_FAILED")
	quit(0 if failures == 0 else 1)
