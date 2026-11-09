extends SceneTree
const AI = preload("res://elimination_ai.gd")
const Motion = preload("res://elimination_motion.gd")
const Game = preload("res://main.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void:
	check(AI.cycle_urgency(199.0)==0.0,"No early pacing command")
	check(AI.cycle_urgency(250.0)>0.0 and AI.cycle_urgency(300.0)==1.0,"Position before the cut")
	check(AI.cycle_urgency(500.0)==0.0,"Reset urgency in recovery lap")
	check(AI.position_risk(0,4)==0.0 and AI.position_risk(2,4)==0.0 and AI.position_risk(3,4)==1.0,"Small fields do not make every rider sprint for survival")
	check(Motion.leaves_safely(3.2,0.0,0.6),"A legal wheel can be left without a new merge buffer")
	check(not Motion.leaves_safely(3.2,-4.0,0.6),"Unsafe closing during departure is rejected")
	check(Motion.laterally_separate(1.18,1.78,1.78,2.38),"Parallel trajectories remain separate")
	check(not Motion.laterally_separate(1.18,1.78,1.78,1.18),"Crossing trajectories require longitudinal clearance")
	var close_d: Array[float]=[-12.0,-23.6475373,-23.6463535,-25.6475373]
	var ids: Array[int]=[0,1,2,3]
	var physical: Dictionary=Motion.physical_order(close_d,ids)
	var coordinates: Array=physical.coordinates.values()
	check(coordinates.max()-coordinates.min()<20.0,"Near-equal positions cannot create a false lap-sized unwrap gap")
	var ai=AI.new()
	var profiles: Array[int]=[0,1,1,1]
	var forms: Array[float]=[1.0,1.0,1.0,1.0]
	var lanes: Array[float]=[1.18,1.18,2.38,4.78]
	var speeds: Array[float]=[10.0,10.0,10.0,10.0]
	var drafts: Array[float]=[0.0,0.6,0.0,0.0]
	var done: Array[float]=[-1.0,-1.0,-1.0,-1.0]
	var distances: Array[float]=[450.0,448.0,449.0,449.5]
	var credits: Array[int]=[0,0,0,0]
	ai.reset(profiles,forms,lanes)
	ai.human_power_w=AI.road_power(10.0,1.0)/AI.DRIVETRAIN
	var before: float=ai.wprime[1]
	ai.step(0.05,40.0,distances,speeds,lanes,drafts,done,profiles,30,80.0,credits)
	check(ai.requested_power_w[1]>ai.cp[1],"Rear rider genuinely requests positional effort")
	check(ai.power_w[1]<ai.cp[1] and ai.wprime[1]>=before-0.00001,"An occupied wheel limits power before W-prime is spent")
	check(ai.planned_distances[0]-ai.planned_distances[1]>=2.0-0.00001,"Traffic preserves following distance")
	ai=AI.new();ai.reset(profiles,forms,lanes)
	distances.assign([96.8,100.0,80.0,60.0]);drafts.fill(0.0)
	ai.step(0.05,20.0,distances,speeds,lanes,drafts,done,profiles,30,80.0,credits)
	check(is_equal_approx(ai.requested_power_w[1],ai.cp[1]*0.92),"Uncontested head uses cruise watts, no minimum speed")
	print("ELIMINATION_NATIVE_CORE failures=",failures)
	quit(0 if failures==0 else 1)
