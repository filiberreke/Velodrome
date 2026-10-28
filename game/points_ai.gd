extends "res://x_scratch_ai.gd"
## Points-only tactical adaptation; shared CP/Wprime physiology is inherited.
## Scratch retains its original CP and tactical step unchanged.
var jury
const IntermediateSprint := preload("res://points_intermediate_sprint.gd")
var intermediate_sprint = IntermediateSprint.new()
var intermediate_sprint_enabled := true # Diagnostic baseline switch; enabled in gameplay.

func reset(profiles: Array[int], forms: Array[float], initial_lanes: Array[float]) -> void:
	super.reset(profiles, forms, initial_lanes)
	intermediate_sprint.reset(profiles.size())
	for i in range(profiles.size()):
		if profiles[i] == 1: cp[i] = 265.0 * forms[i]
		elif profiles[i] == 2: cp[i] = 240.0 * forms[i]

func step(dt: float, clock: float, distances: Array[float], speeds: Array[float], lanes: Array[float], drafts: Array[float], finished: Array[float], profiles: Array[int], laps: int, difficulty: float, credits: Array[int]) -> Array[float]:
	var count: int = distances.size()
	var output: Array[float] = []
	output.resize(count); output.fill(0.0)
	if not initialized or count != cp.size():
		return output
	var active: Array[int] = []
	for i in range(1, count):
		if finished[i] < 0.0:
			active.append(i)
	if active.is_empty():
		return output
	var sorted: Array[int] = active.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool: return distances[a] < distances[b])
	var median_d: float = distances[sorted[sorted.size() / 2]]
	var head_d: float = distances[sorted[-1]]
	intermediate_sprint.prepare(self, distances, speeds, finished, profiles, laps, maxf(head_d, distances[0]), jury)
	var finish_d: float = float(laps) * LAP
	var remaining_group: float = finish_d - median_d
	var final_stage: bool = false
	var main: Array[int] = []
	for i in active:
		if absf(distances[i] - median_d) <= 13.0:
			main.append(i)
	if main.size() < 3:
		main = sorted.duplicate()
	var main_front: float = -100000.0
	var front_i := -1
	for i in main:
		if distances[i] > main_front:
			main_front = distances[i]
			front_i = i
	# Stable breakaway clusters are based on race progress; drafting instead uses modulo track position.
	var leading: Array[int] = _escape_group_order(active, distances, finished)
	leading.reverse()
	var clusters: Array = []
	for i in leading:
		if clusters.is_empty() or distances[int(clusters[-1][-1])] - distances[i] > 13.0:
			clusters.append([i])
		else:
			clusters[-1].append(i)
	var largest: Array = []
	for group in clusters:
		if group.size() > largest.size():
			largest = group
		elif group.size() == largest.size() and group.size() > 0:
			if absf(distances[int(group[0])] - median_d) < absf(distances[int(largest[0])] - median_d):
				largest = group
	var breaks: Array = []
	var escape_member: Dictionary = {}
	for group in clusters:
		if group == largest or group.size() > 4:
			continue
		var min_d: float = distances[int(group[-1])]
		if min_d > main_front + 10.0:
			var all_lapped := true
			for member in group:
				if credits[int(member)] <= 0:
					all_lapped = false
			if all_lapped:
				continue
			breaks.append(group)
			for member in group:
				escape_member[int(member)] = group
	# Group leader rotates; identity is preserved as long as membership stays similar.
	var active_keys: Dictionary = {}
	for group in breaks:
		if group.size() < 2:
			continue
		var member_keys: Array[int] = []
		for value in group:
			member_keys.append(int(value))
		member_keys.sort()
		var key: String = str(member_keys)
		active_keys[key] = true
		if not turns.has(key):
			turns[key] = {"leader": int(group[0]), "until": clock + 8.0}
		var state: Dictionary = turns[key]
		if clock >= float(state["until"]) or not member_keys.has(int(state["leader"])):
			var available: Array[int] = []
			for i in member_keys:
				if i == 0:
					# A human turn is observed, never forced: only while actually leading.
					if human_power_w > 200.0 and distances[0] >= distances[int(group[0])] - 1.5: available.append(0)
				elif wprime[i] / maxf(wmax[i], 1.0) > 0.22 and cooperation[i] > 0.32:
					available.append(i)
			if not available.is_empty():
				var last: int = int(state["leader"])
				var next_pos: int = (available.find(last) + 1) % available.size() if available.has(last) else 0
				var chosen: int = available[next_pos]
				state["leader"] = chosen
				rotation_events.append({"seconds":clock,"leader":chosen,"members":member_keys.duplicate()})
				state["until"] = clock + rng.randf_range(6.0, 12.0) if profiles[chosen] == 2 else clock + rng.randf_range(10.0, 20.0)
			else:
				state["until"] = clock + 6.0
		turns[key] = state
	for key in turns.keys():
		if not active_keys.has(key):
			turns.erase(key)
	var break_front: float = -10000.0
	for group in breaks:
		break_front = maxf(break_front, distances[int(group[0])])
	# The human can also escape: AI must chase a real player attack, rather
	# than treating the player as absent from tactical decisions.
	var player_escape: bool = finished[0] < 0.0 and credits[0] == 0 and distances[0] > main_front + 15.0
	if player_escape:
		break_front = maxf(break_front, distances[0])
	var active_escape: bool = not breaks.is_empty() or player_escape
	for rider_index in active:
		if modes[rider_index] in [MODE_ATTACK, MODE_SOLO, MODE_CHASE, MODE_BREAK_PULL, MODE_BREAK_DRAFT]:
			active_escape = true
	# Godot begins from a standing start (the Python benchmark starts rolling).
	# Do not impose tactical coasting before the peloton has reached riding speed.
	var idle: bool = false
	# Detect a human acceleration immediately, before a 12-15 m escape exists.
	# A short hysteresis window prevents frame-to-frame mode flicker.
	if finished[0] < 0.0:
		var player_accel: float = 0.0
		if previous_player_speed >= 0.0 and dt > 0.0001:
			player_accel = (speeds[0] - previous_player_speed) / dt
		previous_player_speed = speeds[0]
		var close_to_bunch: bool = distances[0] >= median_d - 9.0 and distances[0] <= main_front + 18.0
		var speed_advantage: bool = false
		if front_i >= 0:
			speed_advantage = speeds[0] > 8.0 and speeds[0] > speeds[front_i] + 0.9
		if close_to_bunch and ((player_accel > 0.42 and speeds[0] > 7.5) or speed_advantage):
			player_attack_until = clock + 3.5
	else:
		previous_player_speed = -1.0
	var early_player_attack: bool = clock < player_attack_until and finished[0] < 0.0
	# Physical decisions occur in watts, not imposed speed changes.
	for i in active:
		sprint_started[i] = false
		var kind: int = profiles[i]
		var reserve: float = wprime[i] / maxf(wmax[i], 1.0)
		var m: int = modes[i]
		var in_escape: bool = escape_member.has(i)
		var escape_group: Array = escape_member[i] if in_escape else []
		if credits[i] > 0 and m != MODE_DRAFT:
			_set_mode(i, MODE_DRAFT, 90.0, clock)
			cooldown[i] = clock + 90.0
			m = MODE_DRAFT
		if m == MODE_ATTACK and clock >= mode_until[i]:
			if in_escape and reserve > 0.18:
				_set_mode(i, MODE_SOLO, 30.0, clock)
			else:
				_set_mode(i, MODE_DRAFT, 0.0, clock)
				cooldown[i] = clock + rng.randf_range(20.0, 65.0)
			m = modes[i]
		if m == MODE_CHASE and (clock >= mode_until[i] or reserve < 0.22 or in_escape):
			_set_mode(i, MODE_DRAFT, 0.0, clock)
			cooldown[i] = clock + rng.randf_range(15.0, 45.0)
			m = MODE_DRAFT
		if m == MODE_PULL and clock >= mode_until[i]:
			_set_mode(i, MODE_DRAFT, 0.0, clock)
			pull_off_until[i] = clock + 8.0
			cooldown[i] = clock + 30.0
			m = MODE_DRAFT
		if in_escape and not (m in [MODE_ATTACK, MODE_CHASE]):
			if escape_group.size() >= 2:
				var leader_i: int = int(escape_group[0])
				var ids: Array[int] = []
				for id_value in escape_group:
					ids.append(int(id_value))
				ids.sort()
				var key: String = str(ids)
				if turns.has(key):
					leader_i = int(turns[key]["leader"])
				m = MODE_BREAK_PULL if i == leader_i else MODE_BREAK_DRAFT
			else:
				m = MODE_SOLO
			modes[i] = m
		elif m in [MODE_SOLO, MODE_BREAK_PULL, MODE_BREAK_DRAFT] and not in_escape:
			_set_mode(i, MODE_DRAFT, 0.0, clock)
			cooldown[i] = clock + 25.0
			m = MODE_DRAFT
		# React to a human launch while the player is still within the bunch.
		# Only nearby, capable riders can respond; efforts still consume W-prime.
		if early_player_attack and m == MODE_DRAFT and credits[i] == 0 and reserve > 0.27:
			var player_delta: float = distances[0] - distances[i]
			if player_delta > -3.0 and player_delta < 19.0 and speeds[0] > speeds[i] + 0.35:
				if cooperation[i] > 0.36 and (player_delta < 8.0 or cooperation[i] > 0.65):
					_set_mode(i, MODE_CHASE, 7.0 + 7.0 * cooperation[i], clock)
					m = MODE_CHASE
		# Separate counterattack from an initial demarrage: chase is a costly temporary effort.
		if break_front > main_front + 12.0 and main.has(i) and m == MODE_DRAFT and reserve > 0.38 and cooperation[i] > 0.38 and clock > cooldown[i]:
			if rng.randf() < 0.065 * dt:
				_set_mode(i, MODE_CHASE, rng.randf_range(10.0, 26.0), clock)
				m = MODE_CHASE
		if m == MODE_DRAFT and not in_escape and clock > cooldown[i] and reserve > 0.56 and not final_stage and credits[i] == 0:
			var opportunity: float = 1.35 * dt * aggression[i] * 2.0
			if jury.last_sprint_clock >= 0.0 and clock - jury.last_sprint_clock < 16.0: opportunity *= 2.5
			var next_lap: int = jury.next_sprint_lap()
			if next_lap > 0 and next_lap * LAP - maxf(head_d, distances[0]) < LAP: opportunity *= 0.18
			if jury.points[i] < jury.points.max(): opportunity *= 1.25
			var probability: float = (0.031 if kind == 3 else (0.016 if kind == 1 else 0.004)) * opportunity
			if distances[i] < median_d - 13.0:
				probability *= 0.1
			if rng.randf() < probability:
				_set_mode(i, MODE_ATTACK, rng.randf_range(10.0, 19.0), clock)
				m = MODE_ATTACK
				attacks[i] += 1
		# Discover wheels independent of lateral lane: the rider must first SEE a
		# potential wheel before being able to steer behind it. The human rider
		# (index 0) is a normal draftable target, including in a breakaway.
		var wheel_i := -1
		var gap := 1000.0
		var wheel_score := 1000.0
		var economical: bool = economical_sprinter_wheels and kind == 2 and m == MODE_DRAFT and not sprint_started[i]
		var retained_wheel := -1
		var sheltered_wheel := -1
		var sheltered_score := 1000.0
		for j in range(count):
			if i == j or finished[j] >= 0.0:
				continue
			var forward: float = physical_ahead(distances[i], distances[j])
			if forward < 1.0 or forward > 30.0:
				continue
			var lateral_gap: float = absf(lanes[j] - lanes[i])
			var score: float = forward + 0.8 * lateral_gap
			if economical:
				# The simulator's economy selection uses a 21 m acquisition range.
				if forward >= 21.0:
					continue
				score = absf(forward - 2.5) + 2.0 * lateral_gap + (0.0 if j == shelter_wheel[i] else 0.9)
				if j == shelter_wheel[i] and forward > 1.4 and forward < 8.0 and lateral_gap < 0.95:
					retained_wheel = j
				if forward < 8.5 and lateral_gap < 1.15 and score < sheltered_score:
					sheltered_wheel = j
					sheltered_score = score
			# When chasing a human escape, do not ignore their wheel just because
			# another rider happens to be one or two metres closer.
			if j == 0 and player_escape and distances[0] > distances[i] and distances[0] - distances[i] < 30.0:
				score -= 4.0
			if score < wheel_score:
				wheel_score = score
				gap = forward
				wheel_i = j
		if economical:
			if retained_wheel >= 0:
				wheel_i = retained_wheel
			elif sheltered_wheel >= 0:
				wheel_i = sheltered_wheel
			if wheel_i >= 0:
				gap = physical_ahead(distances[i], distances[wheel_i])
			shelter_wheel[i] = wheel_i
		else:
			shelter_wheel[i] = -1
		var draft_factor: float = clampf(1.0 - 0.69 * drafts[i], 0.31, 1.0)
		var target: float = cp[i] * (0.76 if drafts[i] > 0.12 else 0.91)
		match m:
			MODE_ATTACK:
				target = cp[i] + 0.39 * (pmax[i] - cp[i])
			MODE_SOLO:
				target = cp[i] * (1.03 if reserve > 0.28 else 0.94)
			MODE_BREAK_PULL:
				target = _break_pull_power(i, escape_group, distances, speeds, draft_factor)
			MODE_BREAK_DRAFT:
				target = cp[i] * (0.77 if drafts[i] > 0.12 else 1.01)
				var partner_i := -1
				var partner_gap := 1000.0
				for partner in escape_group:
					var j: int = int(partner)
					if j == i:
						continue
					var pgap: float = distances[j] - distances[i]
					if pgap > 0.3 and pgap < 28.0 and pgap < partner_gap:
						partner_i = j
						partner_gap = pgap
				if partner_i >= 0:
					var wanted_v: float = maxf(5.5, speeds[partner_i] + clampf(0.34 * (partner_gap - 2.5), -1.0, 1.8))
					target = clampf(road_power(wanted_v, draft_factor) / DRIVETRAIN, 0.65 * cp[i], cp[i] + minf(150.0, 80.0 + 100.0 * reserve))
			MODE_CHASE:
				target = cp[i] * 1.18
			MODE_PULL:
				target = cp[i] * 1.12
			MODE_RECOVER:
				target = cp[i] * 0.65
		# Chasers and solitary attackers should ALSO settle onto a wheel once
		# it comes within reach, not continue a self-paced effort beside it.
		# No speed teleport: the power needed to close the gap is calculated and
		# still limited by this rider's finite CP/W' and peak power.
		if m in [MODE_DRAFT, MODE_CHASE, MODE_SOLO, MODE_BREAK_DRAFT] and wheel_i >= 0 and gap < 23.0:
			var closing: float = clampf(0.34 * (gap - 1.7), -1.4, 2.0)
			if economical:
				closing = economical_closing(gap, reserve)
			var wanted_v: float = maxf(5.5, speeds[wheel_i] + closing)
			var needed: float = road_power(wanted_v, draft_factor) / DRIVETRAIN
			var reserve_allowance: float = 90.0 if reserve < 0.28 else (165.0 if m == MODE_DRAFT else 220.0)
			if economical:
				reserve_allowance = economical_overhead(gap, reserve)
			target = clampf(needed, 0.0 if economical else cp[i] * 0.65, cp[i] + reserve_allowance)
		# Standing-start launch: use available W-prime to accelerate before
		# wheel-following speed control takes over. No free speed or extra W-prime:
		# _phys_power and the normal profile power curve still limit this demand.
		# Keep the subsequent collision-speed cap active for blocked corridors.
		if clock < 14.0 and speeds[i] < 11.0 and distances[i] < 170.0:
			var launch_time_weight: float = clampf((14.0 - clock) / 7.0, 0.0, 1.0)
			var launch_speed_weight: float = clampf((11.0 - speeds[i]) / 3.0, 0.0, 1.0)
			var launch_watts: float = minf(450.0, maxf(350.0, cp[i] * 1.65))
			var steady_watts: float = cp[i] * (0.76 if drafts[i] > 0.12 else 0.91)
			var launch_target: float = lerpf(steady_watts, launch_watts, launch_time_weight * launch_speed_weight)
			target = maxf(target, launch_target)
		# Collision anticipation: if the same lateral corridor is occupied,
		# reduce the requested speed until a legal passing corridor is reached.
		# No position teleport, and attacks may still pass in another lane.
		var blocked_speed: float = 1000.0
		for j in range(count):
			if j == i or finished[j] >= 0.0:
				continue
			var ahead_m: float = distances[j] - distances[i]
			if ahead_m > -0.4 and ahead_m < 4.2 and absf(lanes[j] - lanes[i]) < 0.88:
				blocked_speed = minf(blocked_speed, maxf(2.0, speeds[j] + 0.55 * (ahead_m - 2.0)))
		if blocked_speed < 900.0 and speeds[i] > blocked_speed:
			var safe_watts: float = road_power(blocked_speed, draft_factor) / DRIVETRAIN
			target = minf(target, safe_watts)
		# No incentive to pull: decrease quickly to below 50% CP.
		if idle and main.has(i) and m in [MODE_DRAFT, MODE_PULL]:
			if distances[i] >= main_front - 1.5:
				if idle_since[i] < 0.0:
					idle_since[i] = clock
				var elapsed: float = maxf(0.0, clock - idle_since[i])
				target = minf(target, cp[i] * maxf(0.43, 0.77 - 0.085 * elapsed))
				if elapsed >= 10.0 and clock >= pull_off_until[i]:
					pull_off_until[i] = clock + 8.0
					idle_since[i] = clock + 8.0
			else:
				idle_since[i] = -1.0
				target = minf(target, cp[i] * 0.62)
		else:
			idle_since[i] = -1.0
		# FINAL_750: position, stay in the bunch and choose an individual kick.
		var remaining: float = finish_d - distances[i]
		if final_stage and absf(distances[i] - median_d) < 32.0 and m in [MODE_DRAFT, MODE_PULL]:
			var rank := 1
			for j in active:
				if distances[j] > distances[i]:
					rank += 1
			var phase: float = clampf((750.0 - remaining) / 520.0, 0.0, 1.0)
			var preferred_rank := 3 if kind != 3 else 4
			var lag: int = maxi(0, rank - preferred_rank)
			var gap_front: float = maxf(0.0, head_d - distances[i])
			var ratio: float = clampf(0.82 + 0.19 * phase + 0.018 * float(mini(5, lag)) + 0.010 * minf(20.0, gap_front), 0.0, 1.20 if reserve > 0.23 else 1.03)
			if rank <= preferred_rank and drafts[i] > 0.12:
				ratio -= 0.13
			if remaining < 350.0 and gap_front > 9.0:
				ratio = maxf(ratio, 1.09)
			if remaining > 100.0 and not sprint_started[i]:
				target = maxf(target, cp[i] * ratio)
			var onset: float = (235.0 if kind == 1 else (195.0 if kind == 2 else 200.0))
			onset *= 1.0 + 0.08 * float(mini(3, maxi(0, rank - 3)))
			if reserve < 0.16:
				onset *= 0.85
			if remaining <= onset and reserve > 0.055:
				var seconds: float = maxf(5.0, remaining / maxf(speeds[i], 5.0))
				var effort: float = pcurve(seconds, cp[i], wmax[i], pmax[i]) * (0.75 if kind == 1 else (0.99 if kind == 2 else 0.87))
				var budget: float = cp[i] + 0.88 * wprime[i] / maxf(6.0, seconds)
				target = maxf(target, minf(effort, budget))
				sprint_started[i] = true
		# Continue moving toward a useful wheel, but avoid oscillating every frame.
		if clock < pull_off_until[i]:
			lane_targets[i] = TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1]
		elif m == MODE_BREAK_PULL:
			lane_targets[i] = _takeover_lane(i, escape_group, distances, lanes, finished)
		elif m == MODE_ATTACK:
			lane_targets[i] = TRACK_LANE_POSITIONS[0]
		elif m in [MODE_CHASE, MODE_SOLO, MODE_BREAK_DRAFT] and wheel_i >= 0 and gap < 25.0:
			# Urgent wheel capture overrides the usual 35 s lane lock.
			# Otherwise a chaser can spend a whole escape beside the player.
			var wheel_lane: float = lanes[wheel_i]
			if gap < 1.5 and absf(wheel_lane - lanes[i]) < 0.4:
				# Already alongside: move outside to complete a safe pass rather
				# than steering through the bicycle in front.
				wheel_lane = clampf(wheel_lane + (1.20 if wheel_lane < 6.0 else -1.20), TRACK_LANE_POSITIONS[0], TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1])
			lane_targets[i] = clampf(wheel_lane, TRACK_LANE_POSITIONS[0], TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1])
			lane_lock[i] = clock + 8.0
		elif m in [MODE_SOLO, MODE_CHASE, MODE_BREAK_DRAFT]:
			# Alone with nobody's wheel ahead: choose the shortest legal line.
			lane_targets[i] = TRACK_LANE_POSITIONS[0]
		elif m == MODE_DRAFT and wheel_i < 0 and distances[i] > median_d + 15.0:
			# An isolated leader may have dropped out of MODE_SOLO before the
			# clustering logic catches up. Do not leave them marooned mid-track.
			lane_targets[i] = TRACK_LANE_POSITIONS[0]
		elif m == MODE_DRAFT and wheel_i >= 0:
			var wheel_lane: float = lanes[wheel_i]
			var lateral_gap: float = absf(wheel_lane - lanes[i])
			var urgent_alignment: bool = gap < 14.0 and lateral_gap > 1.15 and (wheel_i == 0 or gap < 7.0)
			if clock >= lane_lock[i] or urgent_alignment:
				var target_lane: float = wheel_lane
				var rank_gap: float = head_d - distances[i]
				if final_stage and rank_gap > 6.0:
					target_lane = wheel_lane + (1.20 if wheel_lane < 6.0 else -1.20)
				elif gap < 2.0 and lateral_gap < 0.3 and not economical:
					target_lane = wheel_lane + (1.20 if wheel_lane < 6.0 else -1.20)
				if absf(target_lane - lane_targets[i]) >= 0.5:
					lane_targets[i] = clampf(target_lane, TRACK_LANE_POSITIONS[0], TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1])
					lane_lock[i] = clock + (8.0 if urgent_alignment else 35.0)
		# Shelter is the tactical preference. Collision avoidance is a hard
		# local constraint, not a reward for moving into an empty corridor.
		# Re-evaluate wheel alignment even when an old tactical lock is active.
		var shelter_mode: bool = m in [MODE_DRAFT, MODE_BREAK_DRAFT, MODE_CHASE]
		var min_align_gap: float = 1.55 if economical else 2.1
		if shelter_mode and wheel_i >= 0 and gap > min_align_gap and gap < 21.0 and clock >= pull_off_until[i]:
			var desired_wheel_lane: float = clampf(lanes[wheel_i], TRACK_LANE_POSITIONS[0], TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1])
			if absf(lane_targets[i] - desired_wheel_lane) > 0.4:
				lane_targets[i] = desired_wheel_lane
				lane_lock[i] = clock + 1.0
		var sprint_lap: int = jury.next_sprint_lap()
		var sprint_remaining: float = sprint_lap * LAP - maxf(head_d, distances[0])
		var sprint_positioning: bool = jury.finish_clock < 0.0 and sprint_lap > 0 and sprint_remaining > 0.0 and sprint_remaining <= LAP
		_prefer_inner_line(i, clock, distances, speeds, lanes, finished, m, wheel_i, gap, sprint_positioning)
		# If already too close to a rider ahead, slow down rather than
		# automatically leaving their wheel. Move only when passing is viable.
		var hard_conflict: bool = false
		for j in range(count):
			if i == j or finished[j] >= 0.0:
				continue
			var signed_gap: float = distances[j] - distances[i]
			if absf(signed_gap) < 1.45 and absf(lanes[j] - lane_targets[i]) < 0.85:
				hard_conflict = true
				break
		if hard_conflict:
			var best_lane: float = lane_targets[i]
			var best_score: float = -100000.0
			for candidate in TRACK_LANE_POSITIONS:
				var clearance_penalty: float = 0.0
				for j in range(count):
					if i == j or finished[j] >= 0.0:
						continue
					var separation: float = absf(distances[j] - distances[i])
					if separation < 1.45 and absf(lanes[j] - float(candidate)) < 0.85:
						clearance_penalty += 100.0
				var shelter_penalty: float = (2.4 * absf(float(candidate) - lanes[wheel_i])) if shelter_mode and wheel_i >= 0 and gap < 21.0 else 0.0
				var score: float = -clearance_penalty - shelter_penalty - 0.35 * absf(float(candidate) - lanes[i])
				if score > best_score:
					best_score = score
					best_lane = float(candidate)
			if best_score > -80.0 and absf(best_lane - lane_targets[i]) > 0.25:
				lane_targets[i] = best_lane
				lane_lock[i] = clock + 1.0
		# An attack is short; solo pace or group work only after establishing a gap.
		var cap_duration: float = (18.0 if m == MODE_ATTACK else (25.0 if m in [MODE_PULL, MODE_BREAK_PULL, MODE_CHASE] else 12.0))
		target = minf(target, pcurve(cap_duration, cp[i], wmax[i], pmax[i])) if not sprint_started[i] else target
		var next: int = jury.next_sprint_lap()
		var leader: float = maxf(head_d, distances[0])
		var remaining_sprint: float = next * LAP - leader
		var own_remaining: float = fposmod(-distances[i], LAP)
		var onset: float = 235.0 if kind == 1 else (195.0 if kind == 2 else 200.0)
		if intermediate_sprint_enabled and next > 0 and next < laps:
			target = intermediate_sprint.demand(i, target, kind)
			sprint_started[i] = intermediate_sprint.attempting[i]
		elif jury.finish_clock < 0.0 and next > 0 and remaining_sprint > 0.0 and remaining_sprint <= LAP and own_remaining > 0.0 and own_remaining <= onset and reserve > 0.055:
			var seconds: float = maxf(5.0, own_remaining / maxf(speeds[i], 5.0))
			var effort: float = pcurve(seconds, cp[i], wmax[i], pmax[i]) * (0.75 if kind == 1 else (0.99 if kind == 2 else 0.87))
			var budget: float = cp[i] + 0.88 * wprime[i] / maxf(6.0, seconds)
			target = maxf(target, minf(effort, budget))
			sprint_started[i] = true
		var actual: float = _phys_power(i, target * (difficulty / 80.0), dt)
		power_w[i] = actual
		output[i] = actual
	return output
