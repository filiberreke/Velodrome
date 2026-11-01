extends SceneTree
const Traffic = preload("res://elimination_traffic.gd")
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var done: Array[float] = [-1.0,-1.0]
	var scales: Array[float] = [1.0,1.0]
	# Rider 0 is slightly ahead in another corridor and tries to cut across
	# rider 1's wheel. The incumbent must retain speed and position.
	for direction in [-1.0,1.0]:
		for mover in [0,1]:
			var d: Array[float] = [100.0,100.0]; d[mover] += 0.5
			var v: Array[float] = [15.0,15.0]
			var old: Array[float] = [2.38,2.38]; old[mover] -= direction * 1.2
			var requested: Array[float] = old.duplicate(); requested[mover] = 2.38
			var lanes: Array[float] = Traffic.constrain_lanes(d,v,old,requested,done,scales,0.1)
			check(absf(lanes[0]-lanes[1]) >= 0.67-0.00001,"Merging rider yields laterally in either direction and index order")
			var next: Array[float] = [d[0]+1.5,d[1]+1.5]
			check(Traffic.resolve(d,next,v,lanes,done,0.1,scales)==0,"Cut-in cannot impose a speed clamp on incumbent")
			check(is_equal_approx(v[1-mover],15.0) and is_equal_approx(next[1-mover],d[1-mover]+1.5),"Incumbent keeps its full physical step")
	# Simultaneous opposing merges cannot cross/swap corridors.
	var d: Array[float] = [100.0,100.0]
	var v: Array[float] = [12.0,12.0]
	var old: Array[float] = [1.18,2.38]
	var requested: Array[float] = [2.38,1.18]
	var lanes: Array[float] = Traffic.constrain_lanes(d,v,old,requested,done,scales,0.1)
	check(lanes[1]-lanes[0] >= 0.67-0.00001,"Simultaneous merges preserve lateral order and clearance")
	# Fast traffic behind must have room to maintain its speed as we merge.
	d.assign([100.0,96.0]); v.assign([10.0,18.0]); requested.assign([2.38,2.38])
	lanes = Traffic.constrain_lanes(d,v,old,requested,done,scales,0.1)
	check(lanes[1]-lanes[0] >= 0.67-0.00001,"Closing rear traffic prevents cutting in")
	# A rider already just inside the safety margin cannot use another
	# steering step to cross the narrower physical contact threshold.
	d.assign([100.5,100.0]); v.fill(12.0); old.assign([1.72,2.38]); requested.assign([1.84,2.38])
	lanes=Traffic.constrain_lanes(d,v,old,requested,done,scales,1.0/60.0)
	check(is_equal_approx(lanes[0],old[0]),"Safety-margin rounding cannot permit a last cut-in step")
	# The screenshot case: 0.70 m offset is free on a straight; 0.52 m
	# horizontal offset is also free when banking makes it 0.68 m physically.
	for scenario in [[0.70,1.0],[0.52,1.31]]:
		d.assign([100.0,100.5]); v.assign([15.0,15.0])
		lanes.assign([1.18,1.18+scenario[0]]); scales.assign([scenario[1],scenario[1]])
		var next: Array[float] = [101.5,102.0]
		check(Traffic.resolve(d,next,v,lanes,done,0.1,scales)==0,"Visibly separate neighbouring lines can ride alongside")
		check(is_equal_approx(next[0],101.5) and is_equal_approx(v[0],15.0),"No false braking or blockage in adjacent line")
	# Same-line tailgating still enforces the existing following distance.
	d.assign([100.0,102.2]); v.assign([15.0,10.0]); lanes.assign([1.18,1.18])
	var next: Array[float] = [101.5,103.2]
	check(Traffic.resolve(d,next,v,lanes,done,0.1)==1,"Same-line obstruction remains physical")
	# Main.gd: held manual steering waits alongside the incumbent, then
	# finishes the requested merge once the longitudinal gap is clear.
	var g := Game.new(); root.add_child(g)
	g.race_mode=2; g.rider_count=4; g._configure_peloton()
	g.running=true; g.start_state="RACING"
	g.distances.assign([50.5,50.0,20.0,10.0]); g.speeds.fill(12.0)
	g.lane_offsets.assign([1.18,2.38,5.98,7.18]); g.x_ai.lane_targets=g.lane_offsets.duplicate()
	g._steer_player(1)
	for tick in range(25): g._move_lanes(0.1)
	check(g.elimination_lane_blocked,"Main prevents unsafe manual cut-in")
	check(g.lane_offsets[1]-g.lane_offsets[0] >= Traffic.lateral_clearance(0,1,g._elimination_lane_scales()),"Main leaves an actual side-by-side corridor")
	check(is_equal_approx(g.speeds[1],12.0) and is_equal_approx(g.lane_offsets[1],2.38),"Manual steering never moves or stops the incumbent")
	g.distances[0]=55.0
	for tick in range(25): g._move_lanes(0.1)
	check(not g.elimination_lane_blocked and is_equal_approx(g.lane_offsets[0],2.38),"Pending manual lane request completes when a safe gap opens")
	# Actual main physics: neighbouring lines neither clamp the player nor
	# generate a false longitudinal blockage warning.
	g.distances.assign([50.0,50.5,20.0,10.0]); g.speeds.fill(12.0)
	g.lane_offsets.assign([1.18,1.88,5.98,7.18]); g.x_ai.lane_targets=g.lane_offsets.duplicate()
	g.player_lane=0; g.baseline_speed=12.0; g.watts=300.0; g.clock=30.0
	g.elimination_assist.reset()
	g._advance_race(1.0/60.0)
	check(g.elimination_assist.notice(g.clock).is_empty(),"Actual adjacent-line physics has no false blockage HUD warning")
	check(g.speeds[0]>11.5 and g.speeds[1]>11.5,"Actual adjacent-line physics does not suddenly stop either rider")
	g.free()
	print("ELIMINATION_MERGING failures=",failures)
	quit(0 if failures==0 else 1)
