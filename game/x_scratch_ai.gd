extends RefCounted
## X scratch AI port: calibrated CP/W', tactical pace, solo escapes, group turns,
## stable wheel pursuit, and individual FINAL_750 decisions. The player's power
## remains untouched and comes from the existing trainer/demo bridge.
const LAP := 250.0
const AIR_RHO := 1.20
const CDA := 0.334
const DRIVETRAIN := 0.975
const MASS := 80.0
const CRR := 0.004
const G := 9.81
const CP := [0.0, 270.86, 235.0, 250.0]
const WMAX := [0.0, 24120.4, 30638.0, 32658.4]
const PMAX := [0.0, 856.79, 1661.88, 1149.10]
const MODE_DRAFT := 0
const MODE_ATTACK := 1
const MODE_SOLO := 2
const MODE_BREAK_PULL := 3
const MODE_BREAK_DRAFT := 4
const MODE_CHASE := 5
const MODE_PULL := 6
const MODE_RECOVER := 7

var cp: Array[float] = []
var wmax: Array[float] = []
var pmax: Array[float] = []
var wprime: Array[float] = []
var fatigue: Array[float] = []
var modes: Array[int] = []
var mode_until: Array[float] = []
var cooldown: Array[float] = []
var attacks: Array[int] = []
var lane_targets: Array[float] = []
var lane_lock: Array[float] = []
var pull_off_until: Array[float] = []
var idle_since: Array[float] = []
var power_w: Array[float] = []
var cooperation: Array[float] = []
var aggression: Array[float] = []
var sprint_started: Array[bool] = []
var shelter_wheel: Array[int] = []
var economical_sprinter_wheels := true # A/B diagnostic; enabled for normal gameplay.
var prefer_inside_when_free := true # Shared scratch/points default; diagnostic baseline switch.
var inside_line_requested: Array[bool] = []
var last_role_change: Array[float] = []
var turns: Dictionary = {}
var tactic_clock := 0.0
var previous_player_speed := -1.0
var player_attack_until := 0.0
var rng := RandomNumberGenerator.new()
var initialized := false
var human_power_w := 0.0
var rotation_events: Array[Dictionary] = []

static func pcurve(seconds: float, cp_w: float, w_j: float, max_w: float) -> float:
	return cp_w + w_j / (maxf(0.0, seconds) + w_j / maxf(1.0, max_w - cp_w))

static func road_power(speed_mps: float, aero_factor: float) -> float:
	var v: float = maxf(0.0, speed_mps)
	return 0.5 * AIR_RHO * CDA * aero_factor * v * v * v + CRR * MASS * G * v

static func physical_ahead(follower: float, leader: float) -> float:
	return fposmod(leader - follower, LAP)

func reset(profiles: Array[int], forms: Array[float], initial_lanes: Array[float]) -> void:
	var count: int = profiles.size()
	cp.resize(count); wmax.resize(count); pmax.resize(count)
	wprime.resize(count); fatigue.resize(count)
	modes.resize(count); mode_until.resize(count); cooldown.resize(count)
	attacks.resize(count); lane_targets.resize(count); lane_lock.resize(count)
	pull_off_until.resize(count); idle_since.resize(count); power_w.resize(count)
	cooperation.resize(count); aggression.resize(count); sprint_started.resize(count)
	shelter_wheel.resize(count); shelter_wheel.fill(-1)
	inside_line_requested.resize(count); inside_line_requested.fill(false)
	last_role_change.resize(count)
	rng.randomize()
	turns.clear()
	rotation_events.clear()
	tactic_clock = 0.0
	previous_player_speed = -1.0
	player_attack_until = 0.0
	for i in range(count):
		var kind: int = profiles[i]
		var shape: float = forms[i]
		cp[i] = (CP[kind] if kind > 0 else 0.0) * shape
		wmax[i] = (WMAX[kind] if kind > 0 else 0.0) * shape
		pmax[i] = (PMAX[kind] if kind > 0 else 0.0) * shape
		wprime[i] = wmax[i]
		fatigue[i] = 0.0
		modes[i] = MODE_DRAFT
		mode_until[i] = 0.0
		cooldown[i] = rng.randf_range(50.0, 120.0)
		attacks[i] = 0
		lane_targets[i] = initial_lanes[i]
		lane_lock[i] = 0.0
		pull_off_until[i] = 0.0
		idle_since[i] = -1.0
		power_w[i] = 0.0
		cooperation[i] = rng.randf_range(0.20, 0.70) if kind == 2 else rng.randf_range(0.35, 0.95)
		aggression[i] = rng.randf_range(0.25, 0.65) + (0.22 if kind == 3 else 0.0)
		sprint_started[i] = false
		last_role_change[i] = 0.0
	initialized = true

func _phys_power(i: int, wanted: float, dt: float) -> float:
	var adjusted_cp: float = cp[i] * (1.0 - 0.10 * fatigue[i])
	var ceiling: float = pmax[i] * (1.0 - 0.25 * fatigue[i])
	var demand: float = clampf(wanted, 0.0, ceiling)
	var actual: float = demand
	if demand > adjusted_cp:
		var use_j: float = minf(wprime[i], (demand - adjusted_cp) * dt)
		actual = adjusted_cp + use_j / maxf(dt, 0.0001)
		wprime[i] -= use_j
		fatigue[i] = minf(1.0, fatigue[i] + use_j / maxf(wmax[i], 1.0) * 0.10)
	else:
		var ratio: float = actual / maxf(adjusted_cp, 1.0)
		var tau: float = 180.0 + 600.0 * pow(ratio, 3.0)
		wprime[i] = minf(wmax[i], wprime[i] + (wmax[i] - wprime[i]) * (1.0 - exp(-dt / tau)))
		fatigue[i] = maxf(0.0, fatigue[i] - dt / 1800.0 * maxf(0.0, 1.0 - ratio))
	return actual

func _set_mode(i: int, role: int, seconds: float, clock: float) -> void:
	modes[i] = role
	mode_until[i] = clock + seconds
	last_role_change[i] = clock

const TRACK_LANE_POSITIONS := [1.18, 2.38, 3.58, 4.78, 5.98, 7.18]
const INSIDE_MERGE_CLEARANCE := 2.5
const INSIDE_LATERAL_CLEARANCE := 0.85
const INSIDE_LANE_CHANGE_MPS := 1.15 # Same physical lateral rate as main.gd.

func _inner_corridor_clear(i: int, candidate: float, distances: Array[float], speeds: Array[float], lanes: Array[float], finished: Array[float]) -> bool:
	# Check the complete descent, not only an empty destination. A faster rider
	# arriving from behind also needs room while we cross their corridor.
	var low: float = minf(lanes[i], candidate) - INSIDE_LATERAL_CLEARANCE
	var high: float = maxf(lanes[i], candidate) + INSIDE_LATERAL_CLEARANCE
	var horizon: float = absf(lanes[i] - candidate) / INSIDE_LANE_CHANGE_MPS + 0.5
	for j in range(lanes.size()):
		if j == i or finished[j] >= 0.0: continue
		var other_low: float = lanes[j]
		var other_high: float = lanes[j]
		# Earlier riders in this planning tick have already reserved their path.
		# Later riders check our choice in turn; do not use their stale requests.
		if j > 0 and j < i:
			other_low = minf(other_low, lane_targets[j])
			other_high = maxf(other_high, lane_targets[j])
		if other_high <= low or other_low >= high: continue
		var gap: float = fposmod(distances[j] - distances[i] + LAP * 0.5, LAP) - LAP * 0.5
		var future_gap: float = gap + (speeds[j] - speeds[i]) * horizon
		var nearest: float = 0.0 if gap * future_gap <= 0.0 else minf(absf(gap), absf(future_gap))
		if nearest < INSIDE_MERGE_CLEARANCE: return false
	return true

func _prefer_inner_line(i: int, clock: float, distances: Array[float], speeds: Array[float], lanes: Array[float], finished: Array[float], mode: int, wheel: int, gap: float, sprint_positioning: bool) -> void:
	if not prefer_inside_when_free or i <= 0 or finished[i] >= 0.0: return
	var was_default: bool = inside_line_requested[i]
	inside_line_requested[i] = false
	# Pull-offs, takeovers, attacks, sprint passing and useful wheel acquisition
	# are deliberate tactical lane choices. An old lane lock alone is not one.
	if clock < pull_off_until[i] or mode in [MODE_ATTACK, MODE_BREAK_PULL] or sprint_started[i] or sprint_positioning: return
	var wheel_range: float = 25.0 if mode in [MODE_CHASE, MODE_SOLO, MODE_BREAK_DRAFT] else 21.0
	if wheel >= 0 and wheel < finished.size() and finished[wheel] < 0.0 and gap > 1.4 and gap < wheel_range: return
	# A close wheel with an outward passing request needs room to complete it.
	if wheel >= 0 and gap < 4.0 and lane_targets[i] > lanes[i] + 0.3 and clock < lane_lock[i]: return
	# This default applies only when the inner lane AND the full route to it
	# are free. Do not squeeze riders into intermediate lanes just because the
	# innermost lane is occupied; retain the existing tactical target instead.
	var inside: float = TRACK_LANE_POSITIONS[0]
	if _inner_corridor_clear(i, inside, distances, speeds, lanes, finished):
		lane_targets[i] = inside
		lane_lock[i] = minf(lane_lock[i], clock + 1.0)
		inside_line_requested[i] = true
	elif was_default and is_equal_approx(lane_targets[i], inside):
		# Recheck while moving: cancel our own old request if a rider now
		# occupies the descent. Do not erase a separate tactical lane choice.
		lane_targets[i] = lanes[i]

# Variant L in the supplied Python simulator: small corrections must not
# repeatedly spend sprint reserve. Real gaps still permit a stronger catch-up.
static func economical_closing(gap: float, reserve: float) -> float:
	if gap > 5.5:
		return clampf(0.34 * (gap - 1.8), 0.0, 2.0 if reserve > 0.30 else 1.5)
	return clampf(0.18 * (gap - 2.7), -0.8, 1.2)

static func economical_overhead(gap: float, reserve: float) -> float:
	if gap <= 4.0:
		return 60.0 if reserve > 0.28 else (25.0 if reserve > 0.13 else 0.0)
	if gap <= 6.0:
		return 115.0 if reserve > 0.28 else (75.0 if reserve > 0.13 else 20.0)
	return 165.0 if reserve > 0.28 else (90.0 if reserve > 0.13 else 0.0)

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
	var finish_d: float = float(laps) * LAP
	var remaining_group: float = finish_d - median_d
	var final_stage: bool = remaining_group > 0.0 and remaining_group <= 750.0
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
	var idle: bool = not active_escape and not final_stage and remaining_group > 500.0 and main.size() >= 3 and clock > 10.0 and front_i >= 0 and speeds[front_i] > 8.0
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
			var opportunity: float = 0.66 * dt * aggression[i]
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
		_prefer_inner_line(i, clock, distances, speeds, lanes, finished, m, wheel_i, gap, final_stage)
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
		var actual: float = _phys_power(i, target * (difficulty / 80.0), dt)
		power_w[i] = actual
		output[i] = actual
	return output

func _escape_group_order(active: Array[int], distances: Array[float], finished: Array[float]) -> Array[int]:
	var result: Array[int] = active.duplicate()
	if finished[0] < 0.0: result.append(0)
	result.sort_custom(func(a: int, b: int) -> bool: return distances[a] < distances[b])
	return result

func _break_pull_power(i: int, group: Array, distances: Array[float], speeds: Array[float], aero: float) -> float:
	var front: int = i
	for id in group:
		if distances[int(id)] > distances[front]: front = int(id)
	var reserve: float = wprime[i]/maxf(wmax[i],1.0)
	var target: float = cp[i]*(1.17 if pmax[i] > 1300.0 else 1.24)
	if front != i and distances[front]-distances[i] < 25.0:
		var wanted: float = speeds[front]+clampf(0.22*(distances[front]+3.0-distances[i]),0.25,1.2)
		var required: float = road_power(wanted,aero)/DRIVETRAIN
		var budget: float = cp[i]+minf(170.0,wprime[i]/18.0)
		target = maxf(target,minf(required,budget))
	return minf(target,pcurve(25.0,cp[i],wmax[i],pmax[i])) if reserve > 0.0 else cp[i]

func _takeover_lane(i: int, group: Array, distances: Array[float], lanes: Array[float], finished: Array[float]) -> float:
	var front: int = i
	for id in group:
		if distances[int(id)] > distances[front]: front = int(id)
	if front == i or distances[front]-distances[i] > 20.0: return TRACK_LANE_POSITIONS[0]
	var best: float = lane_targets[i]
	var best_cost := INF
	for candidate in TRACK_LANE_POSITIONS:
		var cost: float = absf(float(candidate)-lanes[i])
		if absf(float(candidate)-lanes[front]) < 1.0: cost += 100.0
		for j in range(distances.size()):
			if j == i or finished[j] >= 0.0: continue
			var separation: float = absf(fposmod(distances[j]-distances[i]+LAP*0.5,LAP)-LAP*0.5)
			if separation < 1.45 and absf(float(candidate)-lanes[j]) < 0.85: cost += 100.0
		if cost < best_cost: best_cost = cost; best = float(candidate)
	return best
