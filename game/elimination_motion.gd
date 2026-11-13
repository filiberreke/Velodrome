extends RefCounted
## Elimination-only reservation and longitudinal safety, in reference metres.
const LAP := 250.0
const MIN_GAP := 2.0
const LATERAL_CLEARANCE := 0.55 # Adjacent 0.60 m lines remain separate.
const MERGE_GAP := MIN_GAP + 0.05

static func signed_gap(a: float, b: float) -> float:
	return fposmod(b-a+LAP*0.5,LAP)-LAP*0.5

static func leaves_safely(gap: float, relative_speed: float, duration: float) -> bool:
	var future := gap+relative_speed*duration
	return gap*future>0.0 and minf(absf(gap),absf(future))>=MIN_GAP-0.00001

static func laterally_separate(a: float, a_next: float, b: float, b_next: float) -> bool:
	var first := a-b; var last := a_next-b_next
	return first*last>0.0 and minf(absf(first),absf(last))>=LATERAL_CLEARANCE-0.00001

static func moving_apart(a: float, a_next: float, b: float, b_next: float) -> bool:
	# Recover from existing overlap without permitting a crossing through a rider.
	var first := a-b; var last := a_next-b_next
	return absf(first)<LATERAL_CLEARANCE and first*last>=0.0 and absf(last)>absf(first)+0.000001

static func constrain_lanes(distances: Array[float], speeds: Array[float], previous: Array[float], requested: Array[float], done: Array[float], metrics: Array[float], dt: float) -> Array[float]:
	var result: Array[float] = requested.duplicate()
	for iteration in range(3):
		for a in range(previous.size()):
			if done[a]>=0.0: continue
			for b in range(a+1,previous.size()):
				if done[b]>=0.0 or laterally_separate(previous[a],result[a],previous[b],result[b]): continue
				if moving_apart(previous[a],result[a],previous[b],result[b]): continue
				var gap := signed_gap(distances[a],distances[b])
				var relative := speeds[b]/metrics[b]-speeds[a]/metrics[a]
				var future := gap+relative*dt
				if gap*future>0.0 and minf(absf(gap),absf(future))>=MERGE_GAP: continue
				# Existing legal followers may move apart without a new-merge buffer.
				var first: float = previous[a]-previous[b]; var last: float = result[a]-result[b]
				if absf(first)<LATERAL_CLEARANCE and leaves_safely(gap,relative,dt): continue
				if absf(last)>absf(first) and leaves_safely(gap,relative,dt): continue
				var delta: float = last-first
				if absf(delta)<0.000001: continue
				var fraction := clampf((absf(first)-LATERAL_CLEARANCE)/absf(delta),0.0,1.0)
				result[a]=lerpf(previous[a],result[a],fraction)
				result[b]=lerpf(previous[b],result[b],fraction)
	return result

static func physical_order(distances: Array[float], active: Array[int]) -> Dictionary:
	# Unwrap at the largest empty piece of track, including lapped traffic.
	var order: Array[int]=active.duplicate()
	order.sort_custom(func(a: int,b: int)->bool:
		var pa:=fposmod(distances[a],LAP);var pb:=fposmod(distances[b],LAP)
		return a>b if absf(pa-pb)<0.000000001 else pa<pb)
	var front:=0;var biggest:=-1.0
	for index in range(order.size()):
		var next: int=order[(index+1)%order.size()]
		var gap: float=fposmod(distances[next],LAP)-fposmod(distances[order[index]],LAP)
		if index==order.size()-1: gap+=LAP
		gap=maxf(0.0,gap)
		if gap>biggest: biggest=gap;front=index
	var sorted: Array[int]=[];var coordinates: Dictionary={};var previous:=0.0
	for k in range(order.size()):
		var rider: int=order[posmod(front-k,order.size())]
		var coordinate:=fposmod(distances[rider],LAP)
		if k>0:
			while coordinate>previous+0.00001: coordinate-=LAP
		coordinates[rider]=coordinate;previous=coordinate;sorted.append(rider)
	return {"order":sorted,"coordinates":coordinates}
