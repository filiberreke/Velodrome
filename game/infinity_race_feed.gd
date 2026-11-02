extends RefCounted
## Read-only adapter. Classification, scoring and timing remain in race rules.
const DISCIPLINES := {0: "SCRATCH", 1: "PUNTENKOERS", 2: "AFVALLING", 4: "ACHTERVOLGING", 5: "PLOEGENACHTERVOLGING", 7: "TIJDRIT"}

func sample(game: Node3D) -> Dictionary:
	var mode: int = game.race_mode
	var positions: Array = game._race_positions() if mode in [0, 1] else game.distances.duplicate()
	var finishes: Array = game.finish_times.duplicate()
	var order: Array[int] = []
	for i in game.rider_count: order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return game._race_better(a, b))
	var names: Array[String] = []
	for i in game.rider_count: names.append(game._rider_name(i))
	var data := {"mode": mode, "discipline": DISCIPLINES.get(mode, "VELODROME"),
		"phase": game.start_state, "clock": game.clock, "laps": game.race_laps,
		"length": game._race_length(), "lap_length": game.LAP, "positions": positions,
		"names": names, "order": order, "finishes": finishes, "winner": game._winner_index(),
		"all_finished": game._all_riders_finished(), "lap_times": game.lap_times.duplicate(true),
		"half_splits": game.pursuit_half_crossings.duplicate(true), "events": [], "sprints": [],
		"points": [], "gains": [], "next_sprint": -1, "breakaway": ""}
	if mode == 1:
		data.events = game.points_rules.events.duplicate(true)
		data.sprints = game.points_rules.sprints.duplicate(true)
		data.points = game.points_rules.points.duplicate()
		data.gains = game.points_rules.gains.duplicate()
		data.next_sprint = game.points_rules.next_sprint_lap()
		data.all_finished = game.points_rules.complete()
	elif mode == 0:
		data.events = game.scratch_rules.events.duplicate(true)
		if not game.peloton_info.is_empty() and not positions.is_empty():
			var leader: float = positions.max()
			var gap: float = leader - float(game.peloton_info.front)
			if gap > 12.0: data.breakaway = "ONTSNAPPING  +%.0f m" % gap
	elif mode in [4, 5]:
		if mode == 5:
			data.positions = game.team_race.progress.duplicate()
			data.finishes = game.team_race.times.duplicate()
			data.names = ["JOUW PLOEG", "AI-PLOEG" if game.team_race.replay.is_empty() else str(game.team_race.replay.get("name", "TEGENPLOEG"))]
			data.order = [0, 1] if game.team_race.better(0, 1) else [1, 0]
			data.winner = -1
			for team in data.order:
				if data.finishes[team] >= 0.0:
					data.winner = team
					break
			data.all_finished = data.finishes[0] >= 0.0 and data.finishes[1] >= 0.0
		# Compare the latest checkpoint completed by BOTH, never two distances.
		var common: int = mini(data.half_splits[0].size(), data.half_splits[1].size())
		data.checkpoint_m = common * game.LAP * 0.5
		data.gap_seconds = float(data.half_splits[1][common - 1]) - float(data.half_splits[0][common - 1]) if common > 0 else null
		data.split_times = [data.half_splits[0][-1] if not data.half_splits[0].is_empty() else -1.0, data.half_splits[1][-1] if not data.half_splits[1].is_empty() else -1.0]
	return data
