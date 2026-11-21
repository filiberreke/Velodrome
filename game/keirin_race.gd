extends RefCounted
## Six riders, three paced laps and three free laps. Fixed 120 Hz physics.
const Visual := preload("res://derny_visual.gd")
const STEP := 1.0 / 120.0
const EXIT_M := 750.0
const FINISH_M := 1500.0
const SAFETY_LANE := -0.8

var percent := 80.0
var phase := "IDLE"
var distance := 0.0
var speed := 25.0 / 3.6
var lane := 1.78
var order: Array[int] = []
var rng := RandomNumberGenerator.new()
var pilot: Node3D
var accumulator := 0.0
var time := 0.0
var exit_time := -1.0
var exit_speed_kmh := 0.0
var look_lap := 0
var look_count := 0
var pilot_exit_start := 0.0
var events: Array[Dictionary] = []

static func target_kmh(p: float) -> float:
	return 45.0 + (clampf(p, 40.0, 120.0) - 70.0) / 6.0

func configure(g) -> void:
	phase = "READY"; time = 0.0; accumulator = 0.0; exit_time = -1.0
	distance = 0.0; speed = 25.0/3.6; lane = 1.78; look_lap = 0; look_count = 0
	events.clear(); order.clear(); rng.randomize()
	for i in range(6): order.append(i)
	# Shuffle this RNG, not global state used by other disciplines.
	for i in range(5, 0, -1):
		var j := rng.randi_range(0, i)
		var previous: int = order[i]; order[i] = order[j]; order[j] = previous
	_place_grid(g)
	if is_instance_valid(pilot): pilot.queue_free()
	pilot = Visual.new(); pilot.name = "KeirinDerny"; g.add_child(pilot)
	_present_pilot(g)

func _place_grid(g) -> void:
	for slot in range(order.size()):
		var i: int = order[slot]
		g.distances[i] = -3.0 - 2.4 * float(slot / 2)
		g.lane_offsets[i] = 1.18 + 1.2 * float(slot % 2)
		g.ai_lane_targets[i] = g.lane_offsets[i]
		g.x_ai.lane_targets[i] = g.lane_offsets[i]
		g.speeds[i] = 0.0
	# Keep the rider's normal controls centred on their drawn starting corridor.
	g.player_lane = roundi((g.lane_offsets[0] - g.LANES[0]) / g.PLAYER_LANE_STEP_M)

func begin(g) -> void:
	phase = "PACED"
	g.start_state = "RACING"
	for i in range(6): g.speeds[i] = speed
	g.baseline_speed = speed

func advance(g, dt: float) -> void:
	if phase not in ["PACED", "FREE"]: return
	accumulator += maxf(dt, 0.0)
	while accumulator + 0.00000001 >= STEP:
		_tick(g, STEP)
		accumulator -= STEP
	g.clock = time
	_present_pilot(g)

func _tick(g, dt: float) -> void:
	var next_time := time + dt
	g.clock = next_time
	if phase == "PACED":
		speed = lerpf(25.0, target_kmh(percent), clampf(distance / 625.0, 0.0, 1.0)) / 3.6
		distance += speed * dt / g._path_metric(distance, lane)
		for slot in range(order.size()):
			var i: int = order[slot]
			var previous: float = g.distances[i]
			g.distances[i] = distance - 3.0 - 2.4 * float(slot / 2)
			g.speeds[i] = speed
			g.draft_strengths[i] = 0.82 if slot < 2 else 0.88
			g._register_lap_crossings(i, previous, g.distances[i]-previous, dt)
			if i > 0 or g.x_ai.all_ai:
				var required: float = g.x_ai.road_power(speed,1.0-g.draft_strengths[i])/0.975
				g.ai_power_w[i] = g.x_ai._phys_power(i, required, dt)
				g.ai_energy_j[i] = g.x_ai.wprime[i]
		g.baseline_speed = speed
		var measured_power: float = g._pc_power(dt) if not g.x_ai.all_ai else g.ai_power_w[0]
		g.player_power_integral += measured_power*dt
		g.player_peak_watts=maxf(g.player_peak_watts,measured_power)
		g.player_speed_peak_kmh=maxf(g.player_speed_peak_kmh,speed*3.6)
		if g.player_samples.is_empty() or absf(g.player_samples[-1].x-g.distances[0])>=2.5:
			g.player_samples.append(Vector2(maxf(0.0,g.distances[0]),measured_power))
		if not g.trainer_seen: g._capture_demo_fit_sample()
		var completed_lap := int(distance / 250.0)
		if completed_lap > look_lap:
			look_lap = completed_lap; look_count += 1
			if is_instance_valid(pilot): pilot.gesture("look_back")
		if distance >= EXIT_M:
			phase = "FREE"; exit_time = next_time; exit_speed_kmh = speed*3.6; pilot_exit_start = distance
			events.append({"kind":"derny_exit","time":next_time,"kmh":exit_speed_kmh})
			g._announce_race_event("DERNY UIT · VRIJE WEDSTRIJD", false)
	else:
		_free_step(g, dt, next_time)
		# The pilot keeps rolling and leaves through the inside; no hand signal.
		lane = move_toward(lane, SAFETY_LANE, 1.3*dt)
		speed = move_toward(speed, 5.0, 0.6*dt)
		distance += speed*dt/g._path_metric(distance,lane)
		if distance-pilot_exit_start>250.0 and is_instance_valid(pilot): pilot.hide()
	time = next_time
	g.clock = time

func _free_step(g, dt: float, next_time: float) -> void:
	var old: Array[float] = g.distances.duplicate()
	var old_speeds: Array[float] = g.speeds.duplicate()
	var prior_lanes: Array[float] = g.lane_offsets.duplicate()
	g._update_drafting(dt)
	var reductions: Array[float] = []
	for i in range(6): reductions.append(g._draft_drag_reduction(i))
	var powers: Array[float] = g.x_ai.step_keirin(dt,next_time-exit_time,FINISH_M,old,old_speeds,prior_lanes,reductions,g.finish_times,g.ai_difficulty)
	if not g.x_ai.all_ai: powers[0] = g._pc_power(dt)
	# AI riders reserve passing corridors; the human player can ride through others.
	for i in range(6):
		if g.finish_times[i]>=0.0: continue
		var human_player: bool = i == 0 and not g.x_ai.all_ai
		var target: float = g.LANES[clampi(g.player_lane,0,2)] if human_player else g.x_ai.lane_targets[i]
		if not human_player and absf(target-prior_lanes[i])>.01 and not g.x_ai.corridor_clear(i,target,old,old_speeds,prior_lanes,g.finish_times): target=prior_lanes[i]
		g.lane_offsets[i] = move_toward(prior_lanes[i],target,g.LANE_CHANGE_MPS*dt)
		var metric: float = g._path_metric(old[i],g.lane_offsets[i])
		var v: float = g._next_speed(old_speeds[i],powers[i],dt,g._effective_draft_strength(i))
		var side: Vector3 = g._at(old[i],g.lane_offsets[i])
		var forward: Vector3 = g._at(old[i]+v*dt/metric,g.lane_offsets[i])
		v = g._banked_speed(v,forward.y-side.y,side.y-g._at(old[i],prior_lanes[i]).y,absf(g.lane_offsets[i]-prior_lanes[i]),dt,powers[i])
		var nd: float = old[i] + v*dt/metric
		# Moving obstacle boundary, never the frozen finishing-line position.
		for j in range(6):
			if human_player or j==i or g.finish_times[j]>=0.0: continue
			if old[j]>old[i] and absf(g.lane_offsets[i]-g.lane_offsets[j])<0.85:
				nd = minf(nd, maxf(old[i],old[j]+old_speeds[j]*dt/metric-1.8))
		v = minf(v,maxf(0.0,(nd-old[i])*metric/dt))
		g.speeds[i]=v; g.distances[i]=minf(FINISH_M,nd)
		g.ai_power_w[i]=powers[i]; g.ai_energy_j[i]=g.x_ai.wprime[i]
		g._register_lap_crossings(i,old[i],nd-old[i],dt)
		if i==0:
			g.baseline_speed=v
			g.player_power_integral += powers[i]*dt
			g.player_peak_watts=maxf(g.player_peak_watts,powers[i])
			g.player_speed_peak_kmh=maxf(g.player_speed_peak_kmh,v*3.6)
			if g.player_samples.is_empty() or absf(g.player_samples[-1].x-g.distances[i])>=2.5 or nd>=FINISH_M:
				g.player_samples.append(Vector2(g.distances[i],powers[i]))
			if not g.trainer_seen: g._capture_demo_fit_sample()
		if nd>=FINISH_M:
			g.finish_times[i]=next_time-dt+dt*clampf((FINISH_M-old[i])/maxf(nd-old[i],0.000001),0.0,1.0)
			g.coast_distances[i]=FINISH_M; g.coast_speeds[i]=v
			g.elimination_exit[i]={"stage":0,"start_d":FINISH_M,"elapsed":0.0,"position":Vector3.ZERO,"heading":Vector3.FORWARD,"target":g._elimination_box_target(i)}
			events.append({"kind":"finish","rider":i,"time":g.finish_times[i]})
	var champion: int = g._winner_index()
	if champion>=0 and champion!=g.finish_photo_rider: g._take_finish_photo(champion)
	if g.finish_times[0]>=0.0 and not g.finished:
		g.finished=true; g.running=false; g.finish_elapsed=0.0
		g._register_performance(); g._save_recording("finish")

func update_finish_exit(g, i: int, dt: float) -> void:
	var route: Dictionary = g.elimination_exit[i]
	var stage: int = route.stage
	if stage==3: g.coast_speeds[i]=0.0; return
	route.elapsed=float(route.get("elapsed",0.0))+dt
	if stage==0:
		var before: float = g.coast_distances[i]
		var previous: float = g.coast_speeds[i]
		var target_speed := previous if route.elapsed<3.0 else 4.0
		g.coast_speeds[i]=move_toward(previous,target_speed,0.55*dt)
		# Wait for the entire inward corridor, including approaching racing riders.
		var clear := true
		for j in range(6):
			if j==i: continue
			var other: float = g.coast_distances[j] if g.finish_times[j]>=0.0 else g.distances[j]
			if g.elimination_exit.has(j) and int(g.elimination_exit[j].stage)>0: continue
			if g.lane_offsets[j] >= g.lane_offsets[i]-.05: continue
			var gap: float = fposmod(other-before+125.0,250.0)-125.0
			var other_speed: float = g.coast_speeds[j] if g.finish_times[j]>=0.0 else g.speeds[j]
			var horizon: float = absf(g.lane_offsets[i]-SAFETY_LANE)/g.LANE_CHANGE_MPS+.5
			var future: float = gap+(other_speed-previous)*horizon
			if gap*future<=0.0 or minf(absf(gap),absf(future))<3.0: clear=false
		if route.elapsed>=3.0 and previous<=10.0 and clear:
			g.lane_offsets[i]=move_toward(g.lane_offsets[i],SAFETY_LANE,.65*dt)
		g.coast_distances[i]+=(previous+g.coast_speeds[i])*.5*dt/g._path_metric(before,g.lane_offsets[i])
		# Detect crossing, not a narrow proximity window that could be skipped.
		var next_gate: float = before+fposmod(g.OPPOSITE_STRAIGHT_GATE_M-before,250.0)
		if absf(g.lane_offsets[i]-SAFETY_LANE)<.01 and g.coast_distances[i]>=next_gate:
			route.stage=1
			route.position=g._at(next_gate-g.FRONT_WHEEL_TIP_M,SAFETY_LANE)
			route.position.y=.15
			route.heading=g._direction(next_gate,SAFETY_LANE)
	else:
		var current: Vector3 = route.position
		var destination: Vector3 = Vector3(-14.1,.15,0.0) if stage==1 else Vector3(route.target)
		var delta := destination-current; delta.y=0.0
		var target_speed := minf(3.0,sqrt(2.0*.8*delta.length()))
		g.coast_speeds[i]=move_toward(g.coast_speeds[i],target_speed,.8*dt)
		if delta.length()>.001:
			route.heading=delta.normalized()
			route.position=current.move_toward(destination,g.coast_speeds[i]*dt)
		if current.distance_to(destination)<.03:
			if stage==1: route.stage=2
			elif g.coast_speeds[i]<.1: route.stage=3; g.coast_speeds[i]=0.0
	g.elimination_exit[i]=route

func _present_pilot(g) -> void:
	if not is_instance_valid(pilot): return
	pilot.position=g._at(distance,lane)
	pilot.position.y=maxf(.015,pilot.position.y)
	var forward: Vector3 = g._direction(distance,lane)
	pilot.rotation.y=atan2(forward.x,forward.z)
	# Same inward, speed-dependent corner lean as the riders. Fade out when
	# the derny leaves the banked lane for the flat infield safety strip.
	pilot.rotation.z = g._corner_lean(distance, speed) * clampf((lane - SAFETY_LANE) / (1.18 - SAFETY_LANE), 0.0, 1.0)
	pilot.visible=g.start_state!="SETUP" and (phase in ["READY","PACED"] or (phase=="FREE" and distance-pilot_exit_start<=250.0))

func hide() -> void:
	if is_instance_valid(pilot): pilot.hide()
	phase="IDLE"
