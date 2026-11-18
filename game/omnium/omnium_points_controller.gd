extends "res://omnium/omnium_race_controller.gd"
var seen_events := 0
var seen_sprints := {}
var bonuses := {}
var bonus_clock: Callable
func discipline() -> String: return "points"
func stage() -> int: return 3
func mode() -> int: return 1
func milliseconds() -> int:
	return int(bonus_clock.call()) if bonus_clock.is_valid() else Time.get_ticks_msec()
func collect_awards(game: Node) -> void:
	var groups := {}
	for i in range(seen_events, game.points_rules.events.size()):
		var event: Dictionary = game.points_rules.events[i]
		add_award(groups, float(event.seconds), String(game.rider_identities[int(event.rider)].id), int(event.points))
	seen_events = game.points_rules.events.size()
	for sprint in game.points_rules.sprints:
		for place in range(int(seen_sprints.get(int(sprint.lap),0)), sprint.order.size()):
			var slot: int = int(sprint.order[place])
			var award: int = int(sprint.awards[place])
			if award != 0: add_award(groups, float(sprint.times[place]), String(game.rider_identities[slot].id), award)
		seen_sprints[int(sprint.lap)] = sprint.order.size()
	var times: Array = groups.keys(); times.sort()
	for at in times:
		for id in groups[at]: bonuses[id] = {"value":int(groups[at][id]), "until":milliseconds() + 10000}
func add_award(groups: Dictionary, at: float, id: String, amount: int) -> void:
	if not groups.has(at): groups[at] = {}
	groups[at][id] = int(groups[at].get(id, 0)) + amount
func sample(game: Node) -> void:
	if enabled(): collect_awards(game)
	super.sample(game)
func standings(game: Node) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not enabled(): return rows
	collect_awards(game)
	var result := result_data(game)
	var results: Array = context.results.duplicate(); results.append(result)
	var totals := Scores.totals(context.riders, results)
	var indices := order(game)
	indices.sort_custom(func(a: int, b: int): return Scores.compare(String(game.rider_identities[a].id), String(game.rider_identities[b].id), totals, results) < 0)
	var previous := ""; var rank := 0
	for place in range(indices.size()):
		var i: int = indices[place]; var rider: Dictionary = game.rider_identities[i]; var id := String(rider.id)
		if previous.is_empty() or Scores.compare(previous, id, totals, results) != 0: rank = place + 1
		previous = id
		var bonus: Dictionary = bonuses.get(id, {})
		rows.append({"id":id,"name":rider.name,"country":rider.country,"score":int(totals[id]),"player":i == 0,"laps":game.points_rules.credits[i],"rank":rank,"bonus":int(bonus.get("value",0)) if milliseconds() < int(bonus.get("until",0)) else 0})
	return rows
func result_data(game: Node) -> Dictionary:
	var result := super.result_data(game)
	var points := {}; var gains := {}; var losses := {}; var sprints: Array = []
	var final_order: Array = []; var final_times := {}
	for i in range(game.rider_count):
		var id := String(game.rider_identities[i].id)
		points[id] = game.points_rules.points[i]; gains[id] = game.points_rules.gains[i]; losses[id] = game.points_rules.losses[i]
	for sprint in game.points_rules.sprints:
		var ids: Array = []
		for place in range(sprint.order.size()):
			var id := String(game.rider_identities[int(sprint.order[place])].id); ids.append(id)
			if int(sprint.lap) == game.race_laps: final_times[id] = float(sprint.times[place])
		if int(sprint.lap) == game.race_laps: final_order = ids.duplicate()
		sprints.append({"lap":sprint.lap,"seconds":sprint.seconds,"order":ids,"times":sprint.times.duplicate(),"awards":sprint.awards.duplicate()})
	result.merge({"points":points,"gains":gains,"losses":losses,"sprints":sprints,"final_sprint_order":final_order,"final_sprint_times":final_times,"laps":game.race_laps})
	return result
func clear() -> void:
	super.clear(); seen_events = 0; seen_sprints.clear(); bonuses.clear()
