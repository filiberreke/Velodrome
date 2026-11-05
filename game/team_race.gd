extends RefCounted
const MenuSkin := preload("res://menu_theme.gd")
const Train := preload("res://team_pursuit.gd")
const Pacer := preload("res://pursuit_pacer.gd")
const Records := preload("res://pursuit_records.gd")
var ours = Train.new()
var theirs = Train.new()
var pacer = Pacer.new()
var front: Array[float] = [0.0, 0.0]
var progress: Array[float] = [0.0, 0.0]
var velocity: Array[float] = [0.0, 0.0]
var times: Array[float] = [-1.0, -1.0]
var replay: Dictionary = {}
var first_wheel_photo := false
const Badge := preload("res://leader_power_badge.gd")
var badges: Array[Node3D] = []

func prepare(game: Node3D, previous: Dictionary, cp: float) -> void:
	first_wheel_photo = false
	ours.reset(game.team_size)
	theirs.reset(game.team_size, -1)
	front.assign([0.0, 0.0]); progress.assign([0.0, 0.0])
	velocity.assign([0.0, 0.0]); times.assign([-1.0, -1.0])
	replay = Records.first_wheel_record(previous)
	pacer = Pacer.new()
	if replay.is_empty():
		pacer.difficulty_percent = game.pursuit_opponent_percent
		pacer.prepare(game, game._race_length(), cp, game.PURSUIT_START_M + 125.0, game.LANES[0])
	game.pursuit_trace.assign([{"t": 0.0, "d": 0.0, "p": 0.0, "lane": game.LANES[0], "front": 0.0}])
	for i in range(1, game.team_size): game.rider_names[i] = "Ploegmaat %d" % i
	_apply_formation(game)
	_build_badges(game)

static func hold_power(speed: float) -> float:
	var v := maxf(0.0, speed)
	return (0.5 * 1.20 * 0.334 * v * v + 0.004 * 80.0 * 9.81) * v / 0.975

func better(a: int, b: int) -> bool:
	if times[a] >= 0.0 or times[b] >= 0.0:
		if times[a] < 0.0: return false
		if times[b] < 0.0: return true
		return times[a] < times[b]
	return progress[a] > progress[b]

func request_player_exchange() -> bool:
	# A stopped train has no head turn to relinquish and cannot coast backwards.
	return ours.request_exchange() if velocity[0] > 0.5 else false

func _replay_front(seconds: float, fallback: float) -> float:
	var samples: Array = replay["samples"]
	var low := 0
	var high: int = samples.size() - 1
	while low + 1 < high:
		var mid: int = (low + high) / 2
		if float(samples[mid]["t"]) <= seconds: low = mid
		else: high = mid
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[high]
	if not Records._number(a.get("front")) or not Records._number(b.get("front")):
		return fallback
	var fraction := clampf((seconds - float(a["t"])) / maxf(0.000001, float(b["t"]) - float(a["t"])), 0.0, 1.0)
	return lerpf(float(a["front"]), float(b["front"]), fraction)

func step(game: Node3D, dt: float) -> void:
	if dt <= 0.0:
		return
	game.boost_left = 0.0; game.recovery_left = 0.0
	var previous_front: float = front[0]
	var previous_offsets: Array[float] = ours.offsets.duplicate()
	var previous_lanes: Array[float] = ours.lanes.duplicate()
	for team in range(2):
		if times[team] >= 0.0:
			continue
		var prior: float = progress[team]
		var train = ours if team == 0 else theirs
		var prior_offsets: Array[float] = train.offsets.duplicate()
		var prior_lanes: Array[float] = train.lanes.duplicate()
		var power: float
		var finish: float = game.clock
		if team == 1 and not replay.is_empty():
			var sample: Dictionary = Records.at_time(replay, game.clock)
			progress[team] = float(sample["d"])
			front[team] = _replay_front(game.clock, progress[team])
			velocity[team] = float(sample["speed"]) * game._path_metric(game.PURSUIT_START_M + 125.0 + front[team], game.LANES[0])
			power = float(sample["p"])
			theirs.step(dt, power, hold_power(velocity[team]))
			if game.clock >= float(replay["time_s"]): finish = float(replay["time_s"])
		else:
			var forward_m: float = velocity[team] * dt / game._path_metric(game.PURSUIT_START_M + float(team) * 125.0 + front[team], game.LANES[0])
			power = ours.step(dt, game.watts, hold_power(velocity[team]), forward_m) if team == 0 else theirs.step(dt, pacer.power(dt), hold_power(velocity[team]), forward_m)
			var result: Dictionary = Pacer.advance(game, front[team], velocity[team], power, dt, game.LANES[0], game.PURSUIT_START_M + float(team) * 125.0)
			velocity[team] = float(result["speed"])
			var step_m: float = float(result["step"])
			var next_front: float = front[team] + step_m
			var next_first: float = next_front + float(train.offsets.max())
			if next_first >= game._race_length():
				var fraction: float = clampf((game._race_length() - prior) / maxf(0.000001, next_first - prior), 0.0, 1.0)
				finish = game.clock - dt + dt * fraction
				for i in range(game.team_size):
					train.offsets[i] = lerpf(prior_offsets[i], train.offsets[i], fraction)
					train.lanes[i] = lerpf(prior_lanes[i], train.lanes[i], fraction)
				next_front = game._race_length() - float(train.offsets.max())
			front[team] = next_front
			# Distances represent front-wheel tips. Use the physically foremost rider.
			progress[team] = clampf(front[team] + float(train.offsets.max()), 0.0, game._race_length())
		var step_progress: float = maxf(0.0, progress[team] - prior)
		var simulation_clock: float = game.clock
		var active_dt: float = clampf(finish - (simulation_clock - dt), 0.0, dt)
		game.clock = finish
		game._register_pursuit_half_crossings(team, prior, step_progress, active_dt, power)
		if team == 1 and not replay.is_empty():
			while game.lap_times[team].size() < game.race_laps and float(game.lap_times[team].size() + 1) * game.LAP <= progress[team] + 0.000001:
				var crossing: float = Records.time_at_distance(replay, float(game.lap_times[team].size() + 1) * game.LAP)
				game.lap_times[team].append(crossing - game.last_lap_crossing[team])
				game.last_lap_crossing[team] = crossing
		else:
			game._register_lap_crossings(team, prior, step_progress, active_dt)
		game.clock = simulation_clock
		if progress[team] >= game._race_length() - 0.000001:
			progress[team] = game._race_length()
			times[team] = finish
		if team == 0:
			game.baseline_speed = velocity[team]
			var elapsed: float = maxf(0.0, finish - (game.clock - dt)) if times[team] >= 0.0 else dt
			game.player_power_integral += game.watts * elapsed
			game.player_peak_watts = maxf(game.player_peak_watts, game.watts)
			game.player_speed_peak_kmh = maxf(game.player_speed_peak_kmh, velocity[team] * 3.6)
			_record(game, finish if times[team] >= 0.0 else game.clock, power, times[team] >= 0.0)
	_apply_formation(game)
	# Export samples remain the player's actual position and effort, not the head's.
	var sample_clock: float = game.clock
	game.clock = times[0] if times[0] >= 0.0 else sample_clock
	if game.finish_times[0] < 0.0:
		if times[0] >= 0.0: game._capture_player_demo_fit_sample(true)
		else: game._capture_demo_fit_sample()
	game.clock = sample_clock
	for team in range(2):
		if times[team] < 0.0: continue
		for id in range(team * game.team_size, (team + 1) * game.team_size):
			if game.finish_times[id] < 0.0:
				game.finish_times[id] = times[team]
				game.coast_distances[id] = game.distances[id]
				game.coast_speeds[id] = game.speeds[id]
	if not first_wheel_photo:
		var old_first: float = previous_front + float(previous_offsets.max())
		var new_first: float = front[0] + float(ours.offsets.max())
		if old_first < game._race_length() and new_first >= game._race_length():
			var fraction: float = clampf((game._race_length() - old_first) / maxf(0.000001, new_first - old_first), 0.0, 1.0)
			var photo_offsets: Array[float] = []
			var photo_lanes: Array[float] = []
			for i in range(game.team_size):
				photo_offsets.append(lerpf(previous_offsets[i], ours.offsets[i], fraction))
				photo_lanes.append(lerpf(previous_lanes[i], ours.lanes[i], fraction))
			first_wheel_photo = true
			game._take_team_finish_photo(game._race_length() - float(photo_offsets.max()), photo_offsets, photo_lanes, times[0] if times[0] >= 0.0 else game.clock - dt + dt * fraction)
	if times[0] >= 0.0 and not game.finished:
		game._register_performance()
		game.finished = true; game.running = false; game.finish_elapsed = 0.0
		game._save_recording("finish")

func _record(game: Node3D, seconds: float, power: float, force: bool) -> void:
	var last: Dictionary = game.pursuit_trace[-1]
	if seconds <= float(last["t"]) + 0.000001 or (not force and seconds - float(last["t"]) < 0.2):
		return
	game.pursuit_trace.append({"t": seconds, "d": progress[0], "front": front[0], "p": power, "lane": game.LANES[0]})

func _apply_formation(game: Node3D) -> void:
	for team in range(2):
		var train = ours if team == 0 else theirs
		for local in range(game.team_size):
			var id: int = team * game.team_size + local
			if game.finish_times[id] >= 0.0: continue
			game.distances[id] = front[team] + train.offsets[local]
			game.speeds[id] = velocity[team]
			game.lane_offsets[id] = lerpf(game.LANES[0], game.TEAM_EXCHANGE_LANE_M, train.lanes[local])
			game.ai_lane_targets[id] = game.lane_offsets[id]
			game.draft_strengths[id] = 0.0
			game.draft_leaders[id] = -1
			game.ai_power_w[id] = train.leader_power * train.factor(train.order.find(local))

func hud(game: Node3D) -> void:
	if game.race_overlay == null: return
	var positions: Array[float] = []
	var names: Array[String] = []
	var gaps: Array[String] = []
	var colours: Array[Color] = []
	var order: Array[int] = []
	for i in range(game.rider_count):
		positions.append(game._rider_distance(i, game.distances[i]))
		names.append(game._rider_name(i)); order.append(i)
		gaps.append("JIJ" if i == 0 else "%+d m" % roundi(game.distances[i] - game.distances[0]))
		colours.append(Color("f4d46a") if i < game.team_size else Color("54d39b"))
	order.sort_custom(func(a: int, b: int) -> bool: return game._race_better(a, b))
	var pair: Array[float] = [-1.0, -1.0]
	var stats: Array = [{}, {}]
	var live: Variant = null
	var latest: int = maxi(game.pursuit_half_crossings[0].size(), game.pursuit_half_crossings[1].size())
	if latest > 0:
		for team in range(2):
			if game.pursuit_half_crossings[team].size() == latest:
				var prior: float = game.pursuit_half_crossings[team][latest - 2] if latest > 1 else 0.0
				pair[team] = float(game.pursuit_half_crossings[team][latest - 1]) - prior
				stats[team] = game.pursuit_half_stats[team][latest - 1]
		var first: int = 0 if pair[0] >= 0.0 else 1
		live = float(game.pursuit_half_crossings[1][latest - 1]) - float(game.pursuit_half_crossings[0][latest - 1]) if pair[0] >= 0.0 and pair[1] >= 0.0 else maxf(0.0, game.clock - float(game.pursuit_half_crossings[first][latest - 1])) * (1.0 if first == 0 else -1.0)
	var notice := ""
	if game.start_state == "WAIT_STOP": notice = "Stop met trappen om de aftelling te starten."
	elif game.start_state == "COUNTDOWN": notice = "Start over %d" % maxi(1, ceili(game.countdown))
	elif game.trainer_seen and not game.connected and not game.finished: notice = "Trainerverbinding onderbroken"
	var target: float = ours.target_watts()
	game.race_overlay.update_race({"pursuit": true, "pursuit_player": "Jouw ploeg", "pursuit_opponent": "AI-ploeg" if replay.is_empty() else str(replay["name"]), "pursuit_laps": pair, "pursuit_live_gap": live, "pursuit_split_delta": -float(live) if live != null else 0.0, "pursuit_stats": stats, "draft_enabled": false, "watts": game.watts, "speed_kmh": velocity[0] * 3.6, "gear": game.trainer_gear if game.connected else "—", "heart_rate_bpm": game.trainer_heart_rate_bpm, "lap": mini(game.race_laps, int(progress[0] / game.LAP) + 1), "laps": game.race_laps, "seconds": times[0] if times[0] >= 0.0 else game.clock, "position": 1 if better(0, 1) else 2, "count": 2, "leader_gap": "", "order": order, "distances": positions, "names": names, "gaps": gaps, "colours": colours, "notice": notice, "team_mode": true, "team_half_crossings": game.pursuit_half_crossings[0], "opponent_half_crossings": game.pursuit_half_crossings[1], "team_target": target, "team_out": ours.player_is_out(), "team_leading": ours.order[0] == 0, "team_phase": ours.phase, "team_rank": ours.player_rank() + 1, "team_count": game.team_size, "team_active": game.start_state == "RACING" and not game.finished})
	game.minimap.set("start_lines", [game.PURSUIT_START_M, game.PURSUIT_START_M + 125.0])
	game.rankings.text = "PLOEGENACHTERVOLGING\nJouw ploeg: %.1f m\nTegenploeg: %.1f m\nKopvolgorde (0 = speler): %s\nKopbeurt: %.1f s\nOvergenomen beurt: %.1f s / %.1f W\nWissel: %s\nSpelerfactor: %.0f%%\nVermogen op kop: %.1f W" % [progress[0], progress[1], str(ours.order), ours.turn_seconds, ours.copied_seconds, ours.copied_watts, ours.phase, ours.factor(maxi(0, ours.player_rank())) * 100.0, ours.leader_power]

func results(game: Node3D) -> void:
	if game.finish_table == null: return
	game.finish_heading.text = "PLOEGENACHTERVOLGING · %d km" % int(game._race_length() / 1000.0)
	game.finish_subtitle.text = "%d RENNERS PER PLOEG" % game.team_size
	game.finish_badge.text = "%d / 2" % (1 if better(0, 1) else 2)
	game.finish_results.text = "JOUW PLOEG   %.2f s\n%s" % [times[0], "Beide ploegen gefinisht" if times[1] >= 0.0 else "Tegenploeg nog onderweg"]
	game.pursuit_save_box.visible = times[0] >= 0.0
	for child in game.finish_table.get_children():
		game.finish_table.remove_child(child); child.queue_free()
	var bg := MenuSkin.PAPER
	for value in ["PL.", "PLOEG", "EINDTIJD", "VERSCHIL", "RONDETIJDEN"]:
		game._result_cell(value, MenuSkin.INK, bg, 150, false, true)
	var teams: Array[int] = [0, 1]
	if not better(0, 1): teams.reverse()
	for rank in range(2):
		var team: int = teams[rank]
		var laps := ""
		for j in range(game.lap_times[team].size()): laps += "%d: %.2f  " % [j + 1, float(game.lap_times[team][j])]
		var gap := "--"
		if times[0] >= 0.0 and times[1] >= 0.0: gap = "%.2f s" % absf(times[team] - minf(times[0], times[1]))
		for value in [str(rank + 1), "Jouw ploeg" if team == 0 else ("AI-ploeg" if replay.is_empty() else str(replay["name"]).left(20)), "%.2f s" % times[team] if times[team] >= 0.0 else "Onderweg", gap, laps]:
			game._result_cell(value, MenuSkin.INK, bg, 150)
			var label: Label = game.finish_table.get_child(-1).get_child(0)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 150

func _build_badges(game: Node3D) -> void:
	for item in badges:
		if is_instance_valid(item): item.queue_free()
	badges.clear()
	if game.bikes.is_empty(): return
	for team in range(2):
		var badge := Badge.new()
		game.add_child(badge)
		badges.append(badge)

func hide_badges() -> void:
	for badge in badges:
		if is_instance_valid(badge): badge.show_power(-1, 0.0, Vector3.ZERO, false)

func update_badges(game: Node3D) -> void:
	if game.race_mode != 5 or game.start_state != "RACING" or game.setup_panel.visible:
		hide_badges()
		return
	for team in range(badges.size()):
		var train = ours if team == 0 else theirs
		var id: int = team * game.team_size + train.order[0]
		var show: bool = id != 0 and times[team] < 0.0 and id < game.bikes.size()
		badges[team].show_power(id, train.leader_power, game.bikes[id].global_position if show else Vector3.ZERO, show)
