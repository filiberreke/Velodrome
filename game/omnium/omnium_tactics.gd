extends RefCounted
## Supplemental demand policy; discipline AI, power limits and Wprime remain authoritative.
const Scores := preload("res://omnium/omnium_scoring.gd")
var previous := {}
var discipline := ""
var plans := {}
var last_key := ""
func configure(context: Dictionary, kind: String) -> void:
	previous = Scores.totals(context.riders, context.results); discipline = kind
	plans.clear(); last_key = ""
func update(game: Node) -> void:
	var jury_points: Array = game.points_rules.points if discipline == "points" else (game.tempo_rules.points if discipline == "tempo" else [])
	var key := str([floori(game.clock * 2.0), jury_points])
	if key == last_key: return
	last_key = key; plans.clear()
	var positions: Array[float] = game._race_positions()
	var active_positions: Array[float] = []
	for i in range(game.rider_count):
		if game.finish_times[i] < 0.0: active_positions.append(positions[i])
	active_positions.sort()
	var pack_front: float = float(game.peloton_info.get("front",active_positions[active_positions.size()/2] if not active_positions.is_empty() else 0.0))
	var pack_ids: Array = game.peloton_info.get("ids",[])
	var order: Array[int] = game.omnium_race.order(game)
	var totals := {}
	for i in range(game.rider_count):
		var id := String(game.rider_identities[i].id)
		totals[i] = int(previous.get(id, 0)) + (int(jury_points[i]) if discipline == "points" else Scores.place_points(order.find(i)+1))
	var lead := -1000000
	for value in totals.values(): lead = maxi(lead, int(value))
	var remaining := maxf(0.0, game._race_length() - positions.max())
	for i in range(1, game.rider_count):
		if game.finish_times[i] >= 0.0: continue
		var ai = game.x_ai
		var reserve: float = ai.wprime[i] / maxf(1.0, ai.wmax[i])
		var plan := {"scale":1.0,"attack":1.0,"chase":false,"rival":-1,"gap":lead-int(totals[i])}
		if discipline == "points":
			var sprint_lap: int = game.points_rules.next_sprint_lap()
			var sprints_left := maxi(0, (game.race_laps - maxi(10, sprint_lap))/10 + 1) if sprint_lap > 0 else 0
			var sprint_capacity := float(sprints_left * 5 + (5 if sprints_left > 0 else 0)) * clampf(ai.pmax[i]/1100.0,0.35,1.0)
			# Large score deficits invite lap attempts; small deficits reward sprints.
			plan.attack = 1.75 if plan.gap > sprint_capacity and remaining > 500.0 else (0.85 if plan.gap == 0 else 1.05)
			if reserve < 0.22: plan.attack *= 0.45
			var threat := -1000000.0
			for j in range(game.rider_count):
				if j == i or game.finish_times[j] >= 0.0: continue
				var separation: float = positions[j] - positions[i]
				if separation < 8.0 or pack_ids.has(j) or positions[j] <= pack_front+8.0: continue
				# Outsiders are threats too if one lap could put them ahead.
				var possible: float = float(totals[j]) + 20.0 + minf(10.0, sprint_capacity)
				var reachable := separation < minf(240.0, remaining)
				if possible >= float(totals[i]) and possible > threat and reachable:
					threat = possible; plan.rival = j
			plan.chase = plan.rival >= 0 and reserve > 0.20 and plan.gap <= 30
			if plan.chase: plan.scale = 1.18
			elif plan.gap > 20 and reserve > 0.35: plan.scale = 1.05
			elif reserve < 0.25 and remaining > 750.0: plan.scale = 0.96
		elif discipline == "elimination":
			# Never save energy in the danger zone or on approach to a cut.
			var to_cut: float = game.elimination_rules.next_line_m - positions[i]
			if order.find(i) < maxi(1, game.elimination_rules.remaining_count()/3) and to_cut > 150.0 and reserve < 0.55: plan.scale = 0.97
		elif discipline == "tempo":
			var place: int = order.find(i)
			if place > 0 and int(jury_points[order[place-1]]) - int(jury_points[i]) <= 1 and reserve > 0.20: plan.scale = 1.08
			elif remaining > 750.0: plan.scale = 0.97
		else:
			if remaining > 750.0: plan.scale = 0.97
			else:
				for j in range(game.rider_count):
					if j != i and game.finish_times[j] < 0.0 and absf(float(totals[j])-float(totals[i])) <= 4.0 and positions[j]-positions[i] > 0 and positions[j]-positions[i] < 15.0 and reserve > 0.20:
						plan.scale = 1.08; plan.rival = j
		plans[i] = plan
func attack_factor(i: int) -> float: return float(plans.get(i, {}).get("attack", 1.0))
func should_chase(i: int) -> bool: return bool(plans.get(i, {}).get("chase", false))
func demand(ai: RefCounted, i: int, wanted: float) -> float:
	var scale := float(plans.get(i, {}).get("scale", 1.0))
	# Don't blunt existing attacks/sprints, or boost behind the elimination safety planner.
	if wanted > float(ai.cp[i])*1.1: return wanted
	return wanted * scale
