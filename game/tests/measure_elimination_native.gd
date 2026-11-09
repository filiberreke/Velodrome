extends SceneTree
## Runs the real main.gd physics without rendering or modifying user records.
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_elimination_photo(_rider: int, _line_m: float) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _register_performance() -> void: pass
	func _load_rider_config() -> void: rider_config = ConfigFile.new()

var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func make_race(count: int, seed_value: int) -> Game:
	var g := Game.new(); root.add_child(g)
	g.race_mode = 2; g.rider_count = count; g.race_laps = (count - 1) * 2
	g.elimination_notice = Label.new(); g.add_child(g.elimination_notice)
	g._configure_peloton()
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i in range(1, count): g.rider_forms[i] = rng.randf_range(0.94, 1.06)
	g.x_ai.reset(g.rider_profiles, g.rider_forms, g.lane_offsets)
	g.x_ai.configure_riders(g.rider_identities, g.rider_forms)
	g.running = true; g.start_state = "RACING"; g.watts = 300.0; g.trainer_seen = true
	return g

func run_case(count: int, seed_value: int, frame_dt: float, attack: bool) -> Dictionary:
	var g := make_race(count, seed_value)
	var span_sum := 0.0; var ai_span_sum := 0.0; var speed_sum := 0.0; var draft_sum := 0.0; var samples := 0
	var max_span := 0.0; var min_reserve := 1.0; var valid := true
	var lap := 1; var lap_start := 0.0; var lap_integral := 0.0; var lap_elapsed := 0.0; var laps: Array[Dictionary] = []
	var next_sample := 0.5
	while not g._all_riders_finished() and g.clock < 2400.0:
		var old_d: Array[float] = g.distances.duplicate(); var old_v: Array[float] = g.speeds.duplicate()
		var before_clock: float = g.clock
		if attack: g.watts = 650.0 if g.clock >= 35.0 and g.clock < 60.0 else 250.0
		g.clock += frame_dt; g._update_race(frame_dt)
		var active: Array[int] = []; var ai_d: Array[float] = []; var all_d: Array[float] = []
		var speed := 0.0; var old_speed := 0.0; var draft := 0.0
		for i in range(count):
			valid = valid and is_finite(g.distances[i]) and is_finite(g.speeds[i]) and g.speeds[i] >= 0.0 and g.distances[i] >= old_d[i] - 0.00001
			if i > 0:
				valid = valid and g.x_ai.wprime[i] >= -0.00001 and g.x_ai.wprime[i] <= g.x_ai.wmax[i] + 0.00001
				min_reserve = minf(min_reserve, g.x_ai.wprime[i] / g.x_ai.wmax[i])
			if g.finish_times[i] >= 0.0: continue
			active.append(i); all_d.append(g.distances[i]); speed += g.speeds[i] * 3.6; old_speed += old_v[i] * 3.6
			draft += g._effective_draft_strength(i)
			if i > 0: ai_d.append(g.distances[i])
		if not active.is_empty(): speed /= active.size(); old_speed /= active.size(); draft /= active.size()
		var fraction := 1.0; var crosses := false
		for i in range(count):
			if old_d[i] < lap * 250.0 and g.distances[i] >= lap * 250.0:
				fraction = minf(fraction, (lap * 250.0 - old_d[i]) / maxf(0.000001, g.distances[i] - old_d[i])); crosses = true
		lap_integral += frame_dt * (fraction * old_speed + 0.5 * fraction * fraction * (speed - old_speed))
		lap_elapsed += frame_dt * fraction
		if crosses:
			var crossing: float = before_clock + frame_dt * fraction
			laps.append({"lap":lap,"mean_field_kmh":lap_integral / maxf(0.0001, lap_elapsed),"leader_reference_kmh":900.0 / maxf(0.0001,crossing-lap_start),"crossing_s":crossing})
			lap += 1; lap_start = crossing
			lap_integral = frame_dt * ((1.0-fraction)*old_speed+0.5*(1.0-fraction*fraction)*(speed-old_speed)); lap_elapsed = frame_dt * (1.0-fraction)
		if all_d.size() > 2:
			max_span = maxf(max_span, all_d.max() - all_d.min())
			if g.clock >= next_sample:
				span_sum += all_d.max() - all_d.min(); ai_span_sum += ai_d.max() - ai_d.min() if ai_d.size()>1 else 0.0
				speed_sum += speed; draft_sum += draft; samples += 1; next_sample += 0.5
	check(valid,"Finite motion and bounded W-prime")
	check(g._all_riders_finished(),"Complete elimination including finalists")
	check(g.elimination_rules.eliminated.size()==count-2,"Exactly one elimination per cut")
	var result := {"riders":count,"seed":seed_value,"frame_dt":frame_dt,"attack":attack,"finished":g._all_riders_finished(),"seconds":g.clock,"mean_span_m":span_sum/maxi(1,samples),"mean_ai_span_m":ai_span_sum/maxi(1,samples),"max_span_m":max_span,"mean_speed_kmh":speed_sum/maxi(1,samples),"mean_draft":draft_sum/maxi(1,samples),"min_wprime_fraction":min_reserve,"laps":laps,"distances":g.distances.duplicate(),"speeds":g.speeds.duplicate(),"energy":g.x_ai.wprime.duplicate(),"finish_times":g.finish_times.duplicate(),"eliminated":g.elimination_rules.eliminated.duplicate()}
	if g.x_ai.has_method("motion_statistics"): result["traffic"] = g.x_ai.motion_statistics()
	g.free()
	return result

func run_test() -> void:
	var rows: Array[Dictionary] = []
	for count in [4,12,16]:
		for seed_value in [17,23]:
			var row := run_case(count,seed_value,0.1,false); rows.append(row)
			print("NATIVE_RACE ",JSON.stringify(row))
	for seed_value in [17,23]:
		var row := run_case(16,seed_value,0.1,true); rows.append(row)
		print("NATIVE_ATTACK ",JSON.stringify(row))
	var file := FileAccess.open("res://verification/elimination_native/measurement.json",FileAccess.WRITE)
	if file == null:
		DirAccess.make_dir_recursive_absolute("res://verification/elimination_native")
		file = FileAccess.open("res://verification/elimination_native/measurement.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"races":rows,"failures":failures},"  "));file.close()
	print("NATIVE_MEASUREMENT races=",rows.size()," failures=",failures)
	quit(0 if failures==0 else 1)
