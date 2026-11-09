extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(winner: int) -> void: finish_photo_rider=winner
	func _register_performance() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
var results: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func prepare(s: int, percent: float):
	var g := Game.new(); root.add_child(g)
	g.race_mode=3; g.keirin_percent=percent; g._configure_peloton()
	g.rider_profiles.assign([2,2,2,2,3,3]);g.rider_forms.fill(1.0)
	g.x_ai.all_ai=true;g.x_ai.reset(g.rider_profiles,g.rider_forms,g.lane_offsets)
	g.x_ai.rng.seed=s;g.keirin.rng.seed=s
	g.keirin.order.assign([0,1,2,3,4,5])
	for i in range(5,0,-1):
		var j: int = g.keirin.rng.randi_range(0,i)
		var before: int = g.keirin.order[i];g.keirin.order[i]=g.keirin.order[j];g.keirin.order[j]=before
	g.keirin._place_grid(g);g.keirin.begin(g)
	return g
func simulate(s: int,percent: float,frame_dt: float, box_check: bool) -> Dictionary:
	var g=prepare(s,percent)
	var paced_ok := true; var reserves_ok := true; var finite := true
	var last_paced_speed: float = g.keirin.speed
	var prior_finish: Array[float] = g.finish_times.duplicate()
	var overtake_count := 0; var accelerating_last_lap := false
	var max_kmh := 0.0
	var boxed := 0
	while g.keirin.time<210.0 and not g._all_riders_finished():
		var old: Array[float] = g.distances.duplicate()
		var old_v: Array[float] = g.speeds.duplicate()
		var was_paced: bool = g.keirin.phase=="PACED"
		g._update_race(frame_dt)
		g._update_coasting(frame_dt)
		if was_paced and g.keirin.phase=="PACED":
			paced_ok=paced_ok and g.keirin.speed>=last_paced_speed-1e-8
			paced_ok=paced_ok and g.keirin.speed-last_paced_speed<=.2
			last_paced_speed=g.keirin.speed
			for slot in range(6):
				var i: int = g.keirin.order[slot]
				paced_ok=paced_ok and absf(g.keirin.distance-g.distances[i]-(3.0+2.4*float(slot/2)))<.00001
				paced_ok=paced_ok and absf(g.lane_offsets[i]-(1.18+1.2*float(slot%2)))<.00001
		for i in range(6):
			finite=finite and is_finite(g.distances[i]) and is_finite(g.speeds[i]) and g.speeds[i]>=0.0
			reserves_ok=reserves_ok and g.x_ai.wprime[i]>=-.0001 and g.x_ai.wprime[i]<=g.x_ai.wmax[i]+.0001
			if prior_finish[i]>=0.0: check(g.finish_times[i]==prior_finish[i],"Finish timestamp frozen")
			prior_finish[i]=g.finish_times[i]
			if g.finish_times[i]<0.0:
				max_kmh=maxf(max_kmh,g.speeds[i]*3.6)
				if g.distances[i]>1250.0 and g.speeds[i]>old_v[i]+.001:accelerating_last_lap=true
			for j in range(i+1,6):
				if g.finish_times[i]>=0.0 or g.finish_times[j]>=0.0:continue
				if (old[i]-old[j])*(g.distances[i]-g.distances[j])<0.0 and maxf(old[i],old[j])>1250.0:overtake_count+=1
	check(paced_ok,"No paced gaps, no passing; gradual derny acceleration")
	check(reserves_ok and finite,"Finite native speeds; bounded Wprime")
	check(g._all_riders_finished(),"All six native riders finish seed %d / %.0f%%" %[s,percent])
	check(absf(g.keirin.exit_speed_kmh-g.keirin.target_kmh(percent))<.001,"45/50 km/h derny release")
	check(g.keirin.look_count==3,"One look per paced lap")
	check(g.keirin.pilot.gesture_count.speed_up==0,"No raised-hand animation in keirin")
	var winner: int = g._winner_index()
	var frozen: Array[float] = g.finish_times.duplicate()
	if box_check:
		for step in range(6000):
			g._update_coasting(.05)
			var done := true
			for i in range(6):
				if not g.elimination_exit.has(i) or int(g.elimination_exit[i].stage)!=3:done=false
			if done:break
		for i in range(6):
			if int(g.elimination_exit[i].stage)==3:boxed+=1
		check(boxed==6,"All finishers take safety zone/opposite gate/box")
		check(frozen==g.finish_times,"Exit route leaves result immutable")
	var row: Dictionary={"seed":s,"derny":percent,"winner":winner,"winner_profile":g.rider_profiles[winner],"finish_times":g.finish_times.duplicate(),"boxed":boxed,"exit_time_s":g.keirin.exit_time,"exit_speed_kmh":g.keirin.exit_speed_kmh,"look_count":g.keirin.look_count,"overtakes_last_lap":overtake_count,"acceleration_last_lap":accelerating_last_lap,"peak_kmh":max_kmh,"sprint_starts":g.x_ai.sprint_start_s.duplicate(),"sprint_distances":g.x_ai.sprint_start_remaining_m.duplicate()}
	g.free();return row
func run_test() -> void:
	var seeds := 5 if "--quick" in OS.get_cmdline_user_args() else 100
	for p in [70.0,100.0]:
		for i in range(seeds):
			results.append(simulate(42+i,p,.1,true))
		print("KEIRIN_BATCH derny=",p," races=",seeds," failures=",failures)
	# Fixed-step simulation produces the same finishes at coarse and fine frame rates.
	var a := simulate(17,100.,.1,false)
	var b := simulate(17,100.,1.0/60.0,false)
	for i in range(6):check(absf(a.finish_times[i]-b.finish_times[i])<.00001,"Frame-rate independent finish")
	var destination := "user://keirin_headless.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
	var file := FileAccess.open(destination,FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"races":results},"  "))
	print("KEIRIN_HEADLESS failures=",failures," output=",destination)
	quit(0 if failures==0 else 1)
