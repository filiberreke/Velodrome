extends "res://x_scratch_ai.gd"
## Native port of the tested Python elimination policy. No minimum-speed rule.
const Motion := preload("res://elimination_motion.gd")
const CONTROL_SECONDS := 0.2
const GRID := [1.18,1.78,2.38,2.98,3.58,4.18,4.78,5.38,5.98,6.58,7.18]
var elimination_line_m := 500.0
var final_line_m := 7500.0
var rear_reference_offset := 0.0
var position_metrics: Array[float] = []
var metric_predictor := Callable()
var speed_predictor := Callable()
var requested_power_w: Array[float] = []
var planned_distances: Array[float] = []
var planned_speeds: Array[float] = []
var motion_ready := false
var last_motion: Dictionary = {}
var _control_bucket := -1
var _power_limits := 0
var _speed_caps := 0
var _wheel_ids: Array[int] = []

func reset(profiles: Array[int], forms: Array[float], initial_lanes: Array[float]) -> void:
	super.reset(profiles,forms,initial_lanes)
	requested_power_w.resize(profiles.size()); requested_power_w.fill(0.0)
	_wheel_ids.resize(profiles.size()); _wheel_ids.fill(-1)
	_control_bucket=-1; _power_limits=0; _speed_caps=0; motion_ready=false

static func cycle_urgency(progress: float) -> float:
	# Prepare a route 50m before the bell; full positional effort at 200m to go.
	return clampf((fposmod(maxf(0.0,progress),500.0)-200.0)/100.0,0.0,1.0)

func _metric(i: int, lane: float, lanes: Array[float]) -> float:
	if metric_predictor.is_valid(): return maxf(0.5,float(metric_predictor.call(i,lane)))
	return position_metrics[i] if i<position_metrics.size() else 1.0

func _predict(i: int, power: float, dt: float, speeds: Array[float], drafts: Array[float]) -> float:
	if speed_predictor.is_valid(): return maxf(0.0,float(speed_predictor.call(i,power,dt)))
	var v: float=speeds[i]
	var aero: float=maxf(0.31,1.0-0.69*drafts[i])
	return maxf(0.0,v+(power*DRIVETRAIN/maxf(v,2.5)-0.5*AIR_RHO*CDA*v*v*aero-CRR*MASS*G)/MASS*dt)

static func tracking_power(v: float, desired: float, aero: float) -> float:
	return (road_power(v,aero)+MASS*maxf(v,2.5)*clampf((desired-v)/1.25,-1.5,1.5))/DRIVETRAIN

static func position_risk(rank: int, count: int) -> float:
	# The Python calibration is for 16 riders. Its two-place buffer must not
	# turn EVERY rider into the endangered rear in a 3-5 rider field.
	if count<=5: return 1.0 if rank==count-1 else 0.0
	var third: int=maxi(1,int(count/3))
	return clampf(float(rank-(count-maxi(3,third)-2))/third,0.0,1.0)

func _wheel(i: int, active: Array[int], distances: Array[float], lanes: Array[float]) -> Dictionary:
	var best:=-1;var best_gap:=0.0;var cost:=INF
	for j in active:
		if j==i: continue
		var gap: float=distances[j]-distances[i]
		var lateral: float=absf(lanes[j]-lanes[i])
		var candidate: float=gap+2.5*float(j!=_wheel_ids[i])+lateral
		if gap>1.8 and gap<60.0 and lateral<1.35 and candidate<cost:
			best=j;best_gap=gap;cost=candidate
	return {"id":best,"gap":best_gap}

func _lane_safe(i: int, candidate: float, active: Array[int], distances: Array[float], speeds: Array[float], lanes: Array[float], reserved: Dictionary) -> bool:
	for j in active:
		if j==i: continue
		var other: float=float(reserved.get(j,lanes[j]))
		if Motion.laterally_separate(lanes[i],candidate,lanes[j],other): continue
		var gap: float=Motion.signed_gap(distances[i],distances[j])
		var relative: float=speeds[j]/_metric(j,other,lanes)-speeds[i]/_metric(i,candidate,lanes)
		var departure: float=absf(candidate-lanes[i])/INSIDE_LANE_CHANGE_MPS+0.05
		var existing_horizon: float=1.8 if absf(candidate-other)<Motion.LATERAL_CLEARANCE else departure
		if absf(lanes[i]-lanes[j])<Motion.LATERAL_CLEARANCE and Motion.leaves_safely(gap,relative,existing_horizon):
			continue
		var future: float=gap+relative*1.8
		if gap*future<=0.0 or minf(absf(gap),absf(future))<Motion.MERGE_GAP: return false
	return true

func _plan_lines(active: Array[int], distances: Array[float], speeds: Array[float], lanes: Array[float], clock: float, urgency: float, final_pair: bool) -> void:
	var reserved: Dictionary={0:lane_targets[0]}
	var head: float=distances[active[0]]
	var remaining: float=500.0-fposmod(maxf(0.0,head-rear_reference_offset),500.0)
	for rank in range(active.size()):
		var i: int=active[rank]
		if i==0: continue
		if clock<lane_lock[i]: reserved[i]=lane_targets[i]; continue
		var cur: float=lanes[i]
		var grid_index:=0
		for k in range(GRID.size()):
			if absf(float(GRID[k])-cur)<absf(float(GRID[grid_index])-cur): grid_index=k
		var nearest:=INF;var front:=-1
		for j in active:
			var gap: float=distances[j]-distances[i]
			if j!=i and gap>0.0 and gap<8.0 and absf(lanes[j]-cur)<Motion.LATERAL_CLEARANCE and gap<nearest:
				nearest=gap;front=j
		var choices: Array[float]=[]
		if absf(lane_targets[i]-cur)>0.02: choices.append(lane_targets[i])
		# A stopped or visibly dropping wheel is not useful shelter to retain.
		if front>=0 and (speeds[front]<0.5 and clock>1.0):
			if grid_index+1<GRID.size(): choices.append(GRID[grid_index+1])
			if grid_index>0: choices.append(GRID[grid_index-1])
		if grid_index>0 and (remaining>220.0 or grid_index>=5): choices.append(GRID[grid_index-1])
		var lane_danger: int=active.size()-1 if active.size()<=5 else active.size()-maxi(3,int(active.size()/4))
		if not final_pair and urgency>0.35 and rank>=lane_danger:
			if grid_index+1<GRID.size(): choices.append(GRID[grid_index+1])
		if grid_index>=4 and remaining<220.0: choices.append(GRID[grid_index-1])
		var target: float=cur
		for candidate in choices:
			if nearest<7.0 and candidate<cur and grid_index<5 and not (front>=0 and speeds[front]<0.5): continue
			if _lane_safe(i,candidate,active,distances,speeds,lanes,reserved): target=candidate;break
		lane_targets[i]=target;reserved[i]=target
		if absf(target-cur)>0.05: lane_lock[i]=clock+2.0

func step(dt: float, clock: float, distances: Array[float], speeds: Array[float], lanes: Array[float], drafts: Array[float], finished: Array[float], profiles: Array[int], laps: int, difficulty: float, credits: Array[int]) -> Array[float]:
	var output: Array[float]=[];output.resize(distances.size());output.fill(0.0)
	motion_ready=false
	if not initialized or cp.size()!=distances.size() or dt<=0.0: return output
	var active: Array[int]=[]
	for i in range(distances.size()):
		if finished[i]<0.0: active.append(i)
	if active.is_empty(): return output
	active.sort_custom(func(a: int,b: int)->bool: return a<b if absf(distances[a]-distances[b])<0.000000001 else distances[a]>distances[b])
	var final_pair: bool=active.size()<=2
	var bucket: int=floori((clock-dt+0.000001)/CONTROL_SECONDS)
	if bucket!=_control_bucket:
		_control_bucket=bucket
		var head: float=distances[active[0]]
		var urgency: float=cycle_urgency(head-rear_reference_offset) if not final_pair else clampf((220.0-maxf(0.0,final_line_m-head))/170.0,0.0,1.0)
		_plan_lines(active,distances,speeds,lanes,clock,urgency,final_pair)
		for rank in range(active.size()):
			var i: int=active[rank]
			if i==0: continue
			modes[i]=MODE_DRAFT
			var wheel: Dictionary=_wheel(i,active,distances,lanes)
			var j: int=int(wheel.id);var gap: float=float(wheel.gap)
			_wheel_ids[i]=j
			var aero: float=maxf(0.31,1.0-0.69*drafts[i])
			var target: float=cp[i]*(0.76 if drafts[i]>0.12 else 0.92)
			if j>=0:
				var desired: float=maxf(0.0,speeds[j]*_metric(i,lanes[i],lanes)/_metric(j,lanes[j],lanes)+clampf((gap-3.2)*0.24,-0.65,1.1))
				target=clampf(tracking_power(speeds[i],desired,aero),0.0,cp[i]+minf(200.0,wprime[i]/19.0))
				var upstream:=INF
				for other in active:
					var ahead: float=distances[other]-distances[j]
					# Inspect the nearest real wheel first. Filtering out its close
					# neighbours would invent a >8m hole in an intact 3m-spaced train.
					if other!=j and ahead>1.8 and ahead<35.0 and absf(lanes[other]-lanes[j])<1.35: upstream=minf(upstream,ahead)
				if is_finite(upstream) and upstream>8.0 and gap<8.0:
					desired=maxf(desired,speeds[j]*_metric(i,lanes[i],lanes)/_metric(j,lanes[j],lanes)+0.35)
					target=maxf(target,minf(tracking_power(speeds[i],desired,aero),cp[i]+minf(160.0,wprime[i]/22.0)))
			if not final_pair and urgency>0.0:
				var risk: float=position_risk(rank,active.size())
				if risk>0.0:
					var seconds: float=maxf(6.0,(elimination_line_m-distances[i])/maxf(speeds[i],7.0))
					var kick: float=pcurve(seconds,cp[i],wprime[i],pmax[i])
					target=maxf(target,lerpf(target,kick*0.82,urgency*risk))
			if final_pair:
				var remaining: float=maxf(0.0,final_line_m-distances[i])
				var u: float=clampf((220.0-remaining)/170.0,0.0,1.0)
				var kick: float=pcurve(maxf(6.0,remaining/maxf(speeds[i],7.0)),cp[i],wprime[i],pmax[i])
				target=maxf(target,lerpf(target,kick*0.98,u))
			if clock<14.0 and speeds[i]<11.0 and distances[i]<170.0:
				var weight: float=clampf((14.0-clock)/7.0,0.0,1.0)*clampf((11.0-speeds[i])/3.0,0.0,1.0)
				target=maxf(target,lerpf(cp[i]*(0.76 if drafts[i]>0.12 else 0.91),minf(450.0,maxf(350.0,cp[i]*1.65)),weight))
			requested_power_w[i]=maxf(0.0,target)
	_deliver_motion(active,distances,speeds,lanes,drafts,dt,output)
	motion_ready=true
	return output

func _deliver_motion(active: Array[int], distances: Array[float], speeds: Array[float], lanes: Array[float], drafts: Array[float], dt: float, output: Array[float]) -> void:
	planned_distances=distances.duplicate();planned_speeds=speeds.duplicate()
	last_motion.clear()
	var physical: Dictionary=Motion.physical_order(distances,active)
	var order: Array[int]=physical.order
	var coordinates: Dictionary=physical.coordinates
	var proposed: Dictionary={}
	var done: Array[int]=[]
	for i in order:
		var metric: float=_metric(i,lanes[i],lanes)
		var safe_v:=INF
		var safety_leader:=-1
		for j in done:
			var gap: float=float(coordinates[j])-float(coordinates[i])
			if gap<40.0 and absf(lanes[j]-lanes[i])<Motion.LATERAL_CLEARANCE:
				var allowed: float=maxf(0.0,(float(proposed[j])-Motion.MIN_GAP-float(coordinates[i]))*metric/dt)
				if allowed<safe_v: safe_v=allowed;safety_leader=j
		var request: float=human_power_w if i==0 else minf(requested_power_w[i],power_limit(i,dt))
		request=maxf(0.0,request)
		if i>0 and is_finite(safe_v) and _predict(i,request,dt,speeds,drafts)>safe_v:
			var low:=0.0;var high:=request
			for iteration in range(12):
				var middle: float=(low+high)*0.5
				if _predict(i,middle,dt,speeds,drafts)<=safe_v: low=middle
				else: high=middle
			request=low;_power_limits+=1
		var actual: float=request if i==0 else _phys_power(i,request,dt)
		var speed: float=_predict(i,actual,dt,speeds,drafts)
		if speed>safe_v+0.0000001: speed=safe_v;_speed_caps+=1
		planned_speeds[i]=speed
		planned_distances[i]=distances[i]+speed*dt/metric
		proposed[i]=float(coordinates[i])+speed*dt/metric
		last_motion[i]={"old_d":distances[i],"coordinate":coordinates[i],"metric":metric,"leader":safety_leader,"safe_v":safe_v,"speed":speed,"proposed":proposed[i],"requested":human_power_w if i==0 else requested_power_w[i],"actual":actual,"lane":lanes[i]}
		if i>0: output[i]=actual;power_w[i]=actual
		done.append(i)

func motion_statistics() -> Dictionary:
	return {"power_limits":_power_limits,"speed_caps":_speed_caps}
