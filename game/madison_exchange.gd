extends RefCounted
## Asset-independent, spatial Madison exchange. All distances are metres.
signal phase_changed(phase: String, giver: int, receiver: int)
signal released(giver: int, receiver: int, efficiency: float)
signal missed(reason: String)
signal animation_parameters(parameters: Dictionary)

enum Phase { APPROACH, GRAB, SLING, RELEASE, SEPARATE }
const NAMES := ["APPROACH", "GRAB", "SLING", "RELEASE", "SEPARATE"]
var advanced := false
var approach_distance := 10.0
var max_reach := 1.8
var giver_max_kmh := 55.0
var minimum_closing_mps := 0.1
var visual_reach := 1.4
var grab_seconds := 0.15
var sling_seconds := 2.0
var peak_t := 0.6
var release_seconds := 1.15
var separate_seconds := 0.3
var convergence_mps := 0.65
var max_impulse_mps := 3.0
var impulse_speed_fraction := 0.18
var contact_acceleration := 5.0
var phase: int = Phase.SEPARATE
var active := false
var giver := 0
var receiver := 1
var active_rider := 0
var elapsed := 0.0
var cooldown := 0.0
var marker := 0.0
var precision := 0.0
var sling_t := 0.0
var efficiency := 0.0
var held := false
var can_grab := false
var attempted := false
var grab_left := 0.72
var grab_right := 0.88
var grab_window_valid := false
var visual_offsets: Array[float] = [0.0, 0.0]
var contact_point := Vector3.ZERO
var last_result := "Zoek je ploegmaat op bij de blauwe lijn"
var _impulse := 0.0
var release_reason := ""
var position_valid := false
var position_reason := ""
var failure_reason := ""
var speed_valid := false
var speed_reason := ""

func reset() -> void:
	phase = Phase.SEPARATE
	active = false
	giver = 0; receiver = 1; active_rider = 0
	elapsed = 0.0; cooldown = 0.0; marker = 0.0; precision = 0.0
	sling_t = 0.0; efficiency = 0.0; held = false; can_grab = false; attempted = false; grab_window_valid = false
	visual_offsets.assign([0.0, 0.0])
	_impulse = 0.0
	release_reason = ""
	failure_reason = ""; position_valid = false; position_reason = ""; speed_valid = false; speed_reason = ""
	last_result = "Zoek je ploegmaat op bij de blauwe lijn"

func _change(next: int) -> void:
	phase = next
	elapsed = 0.0
	phase_changed.emit(NAMES[phase], giver, receiver)

func button(pressed: bool) -> void:
	if pressed == held: return
	held = pressed
	if not pressed:
		if advanced and active and phase in [Phase.GRAB, Phase.SLING]: _release()
		return
	if not active or phase != Phase.APPROACH or attempted: return
	if not can_grab:
		miss_attempt(position_reason if not position_valid else speed_reason if not speed_valid else "Te vroeg gedrukt — vóór de groene zone" if marker < grab_left else "Te laat gedrukt — voorbij de groene zone")
		return
	attempted = true
	precision = clampf(1.0 - absf(marker - 0.8) / 0.2, 0.0, 1.0)
	sling_t = 0.0
	efficiency = 0.0
	_change(Phase.GRAB)

func miss_attempt(reason: String) -> void:
	if attempted: return
	attempted = true
	if not active:
		giver = active_rider; receiver = 1-giver; active = true
	failure_reason = reason; last_result = reason; can_grab = false; held = false
	missed.emit(reason)
	_change(Phase.SEPARATE)

func _release(reason: String = "player") -> void:
	release_reason = reason
	efficiency = precision * envelope(sling_t) * (1.0 if advanced else 0.7)
	failure_reason = ""
	if efficiency <= 0.0:
		failure_reason = "Te vroeg of te laat gegrepen" if precision <= 0.0 else "Handbereik overschreden vóór de slinger" if reason == "reach" else "Te lang vastgehouden" if reason == "max_hold" else "Te vroeg losgelaten"
	last_result = "Score: %d/100 · %d%% momentum" % [roundi(score_percent()), roundi(efficiency * 100.0)]
	if not failure_reason.is_empty(): last_result += " · " + failure_reason
	active_rider = receiver
	_change(Phase.RELEASE)
	released.emit(giver, receiver, efficiency)

func release_for_reach() -> void:
	if active and phase in [Phase.GRAB, Phase.SLING]: _release("reach")

func envelope(t: float) -> float:
	# A smooth peak, shared by HUD and future animation sampling.
	var x: float = clampf(t / peak_t if t <= peak_t else (1.0 - t) / (1.0 - peak_t), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func cancel(reason: String = "Aflossing afgebroken") -> void:
	if active and phase in [Phase.APPROACH, Phase.GRAB, Phase.SLING]:
		failure_reason = reason
		last_result = reason
		missed.emit(reason)
		_change(Phase.SEPARATE)
	can_grab = false
	held = false

func score_percent() -> float:
	# Skill score is out of 100 in both modes; Easy momentum remains capped at 70%.
	return clampf(efficiency / (1.0 if advanced else 0.7) * 100.0, 0.0, 100.0)

func positioning(game) -> Dictionary:
	var g: int = giver if active else active_rider
	var r: int = 1-g
	var lateral: float = game._at(game.distances[0],game.lane_offsets[g]).distance_to(game._at(game.distances[0],game.lane_offsets[r]))
	var reason := ""
	if game.lane_offsets[g] >= game.lane_offsets[r]-0.4: reason = "De snelle renner moet aan de binnenkant rijden"
	elif absf(game.lane_offsets[r]-3.58) > 0.15 and absf(game.lane_offsets[r]-2.98) > 0.15: reason = "De ontvanger moet op de blauwe lijn of één lijn eronder rijden"
	elif lateral < 0.6: reason = "Te dicht bij je ploegmaat"
	elif lateral > max_reach+0.0001: reason = "Te ver van je ploegmaat"
	return {"valid":reason.is_empty(),"reason":reason}

func speed_guidance(game) -> Dictionary:
	var g: int = giver if active else active_rider
	var r: int = 1-g
	var lateral: float = game._at(game.distances[0],game.lane_offsets[g]).distance_to(game._at(game.distances[0],game.lane_offsets[r]))
	var longitudinal_room: float = sqrt(maxf(0.0,max_reach*max_reach-lateral*lateral))
	var maximum_closing: float = sqrt(4.0*maxf(0.0,contact_acceleration)*longitudinal_room)
	var difference: float = game.speeds[g]-game.speeds[r]
	var minimum_kmh: float = ceilf(maxf(0.0,game.speeds[g]-maximum_closing)*36.0)/10.0
	var reason := ""
	if game.speeds[g]*3.6 > giver_max_kmh:
		reason = "Je reed te snel als uitgaande renner: %.1f km/u (maximum %.0f km/u)" % [game.speeds[g]*3.6,giver_max_kmh] if g == 0 else "Uitgaande ploegmaat reed boven %.0f km/u" % giver_max_kmh
	elif game.speeds[r]*3.6 < minimum_kmh:
		reason = "Je reed te traag als inkomende renner: %.1f km/u (minimum %.1f km/u bij gever %.1f km/u)" % [game.speeds[r]*3.6,minimum_kmh,game.speeds[g]*3.6] if r == 0 else "Snelheidsverschil te groot: inkomende ploegmaat reed %.1f km/u (minimum %.1f km/u)" % [game.speeds[r]*3.6,minimum_kmh]
	elif difference <= minimum_closing_mps:
		reason = "De uitgaande gever moet sneller rijden dan de ontvanger" if g == 0 else "Je reed te snel: de uitgaande ploegmaat kon niet bijsluiten"
	return {"valid":reason.is_empty(),"reason":reason,"minimum_kmh":minimum_kmh,"maximum_closing_kmh":maximum_closing*3.6,"giver_max_kmh":giver_max_kmh}

func _gap_interval(offset: Vector3, tangent: Vector3, reach: float) -> Vector2:
	var scale: float = maxf(tangent.length_squared(),0.000001)
	var centre: float = -offset.dot(tangent)/scale
	var radius_squared: float = (reach*reach-offset.length_squared())/scale+centre*centre
	if radius_squared < 0.0: return Vector2(1,-1)
	var radius: float = sqrt(radius_squared)
	return Vector2(centre-radius,centre+radius)

func _update_grab_window(game) -> void:
	# Map every spatial constraint onto the same gap/marker interval used by HUD
	# and button(). The late edge includes the drift while speeds equalise.
	var d: float = game.distances[giver]
	var g_lane: float = game.lane_offsets[giver]
	var r_lane: float = game.lane_offsets[receiver]
	var r_base: Vector3 = game._at(d,r_lane)
	var tangent: Vector3 = game._at(d+.5,r_lane)-game._at(d-.5,r_lane)
	var visual_r: float = r_lane+visual_offsets[receiver]
	var visual_tangent: Vector3 = game._at(d+.5,visual_r)-game._at(d-.5,visual_r)
	var relative_speed: float = game.speeds[giver]-game.speeds[receiver]
	var drift: float = relative_speed*absf(relative_speed)/maxf(.001,4.0*contact_acceleration)
	var interval := Vector2(-1.0,1.0) # Original 0.72–0.88 timing target.
	var constraints := [
		_gap_interval(r_base-game._at(d,g_lane),tangent,max_reach),
		_gap_interval(game._at(d,visual_r)-game._at(d,g_lane+visual_offsets[giver]),visual_tangent,visual_reach+.04),
		_gap_interval(r_base-game._at(d+drift,g_lane),tangent,max_reach)]
	for allowed in constraints:
		interval.x = maxf(interval.x,allowed.x); interval.y = minf(interval.y,allowed.y)
	grab_window_valid = interval.x <= interval.y
	grab_left = (approach_distance-interval.y)/(approach_distance+2.5)
	grab_right = (approach_distance-interval.x)/(approach_distance+2.5)

func step(game, dt: float) -> void:
	if dt <= 0.0: return
	cooldown = maxf(0.0, cooldown - dt)
	if game.finished or game.finish_times[0] >= 0.0 or game.finish_times[1] >= 0.0:
		cancel()
	var gap: float = wrapf(game.distances[receiver] - game.distances[giver], -125.0, 125.0)
	if not active and cooldown <= 0.0 and not game.finished and game.finish_times[0] < 0.0 and game.finish_times[1] < 0.0:
		giver = active_rider; receiver = 1 - giver
		gap = wrapf(game.distances[receiver] - game.distances[giver], -125.0, 125.0)
		if gap >= -1.5 and gap <= approach_distance and game.speeds[giver] > game.speeds[receiver] + minimum_closing_mps:
			active = true
			precision = 0.0; efficiency = 0.0; sling_t = 0.0; attempted = false
			release_reason = ""; failure_reason = ""
			_impulse = 0.0
			_change(Phase.APPROACH)
	elapsed += dt
	var placement: Dictionary = positioning(game)
	position_valid = placement.valid; position_reason = placement.reason
	var pace: Dictionary = speed_guidance(game)
	speed_valid = pace.valid; speed_reason = pace.reason
	var a: Vector3 = game._at(game.distances[giver], game.lane_offsets[giver])
	var b: Vector3 = game._at(game.distances[receiver], game.lane_offsets[receiver])
	var physical_span: float = a.distance_to(b)
	var converging: bool = active and phase in [Phase.APPROACH, Phase.GRAB, Phase.SLING] and position_valid and physical_span <= max_reach
	var lateral: float = game.lane_offsets[receiver] - game.lane_offsets[giver]
	# Lane coordinates measure horizontal offset. Account for banking in 3D.
	var correction: float = minf(0.2, maxf(0.0, (physical_span - visual_reach) * 0.5)) if converging else 0.0
	if lateral <= 0.6: correction = 0.0
	for i in range(2):
		var target: float = correction * (1.0 if i == giver else -1.0)
		visual_offsets[i] = move_toward(visual_offsets[i], target, convergence_mps * dt)
	a = game._at(game.distances[giver], game.lane_offsets[giver] + visual_offsets[giver])
	b = game._at(game.distances[receiver], game.lane_offsets[receiver] + visual_offsets[receiver])
	contact_point = (a + b) * 0.5 + Vector3.UP
	if active and phase == Phase.APPROACH:
		marker = clampf((approach_distance-gap)/(approach_distance+2.5),0.0,1.0)
		_update_grab_window(game)
	can_grab = active and phase == Phase.APPROACH and not attempted and position_valid and speed_valid and grab_window_valid and marker >= grab_left-0.000001 and marker <= grab_right+0.000001
	if active:
		match phase:
			Phase.APPROACH:
				_impulse = minf(max_impulse_mps, maxf(0.0, game.speeds[giver]) * impulse_speed_fraction)
				marker = clampf((approach_distance - gap) / (approach_distance + 2.5), 0.0, 1.0)
				if gap < -2.5 or gap > approach_distance + 3.0: cancel(position_reason if not position_valid else speed_reason if not speed_valid else "Greep gemist — niet op tijd op A gedrukt")
			Phase.GRAB, Phase.SLING:
				if not position_valid:
					cancel("Handcontact verloren — " + position_reason)
				elif game.speeds[giver]*3.6 > giver_max_kmh:
					cancel(speed_guidance(game).reason)
				elif physical_span > max_reach + 0.05:
					_release("reach")
				else:
					# Compliant contact: equal and opposite impulses, no position snaps.
					var dv: float = clampf((game.speeds[giver] - game.speeds[receiver]) * 0.5, -contact_acceleration * dt, contact_acceleration * dt)
					game.speeds[giver] -= dv
					game.speeds[receiver] += dv
					game.baseline_speed = game.speeds[0]
					if phase == Phase.GRAB and elapsed >= grab_seconds:
						_impulse = minf(max_impulse_mps, maxf(0.0, game.speeds[giver]) * impulse_speed_fraction)
						_change(Phase.SLING)
					elif phase == Phase.SLING:
						sling_t = clampf(elapsed / sling_seconds, 0.0, 1.0)
						efficiency = precision * envelope(sling_t) * (1.0 if advanced else 0.7)
						if (not advanced and sling_t >= peak_t) or sling_t >= 1.0:
							if not advanced: sling_t = peak_t
							_release("auto" if not advanced else "max_hold")
			Phase.RELEASE:
				if elapsed >= release_seconds: _change(Phase.SEPARATE)
			Phase.SEPARATE:
				if elapsed >= separate_seconds:
					active = false
					cooldown = 4.0
	animation_parameters.emit(parameters())

func apply_release(game, g: int, r: int, amount: float) -> void:
	var delta: float = minf(game.speeds[g], _impulse * amount)
	game.speeds[g] -= delta
	game.speeds[r] += delta
	game.baseline_speed = game.speeds[0]

func parameters() -> Dictionary:
	var duration: float = {Phase.GRAB:grab_seconds, Phase.SLING:sling_seconds, Phase.RELEASE:release_seconds, Phase.SEPARATE:separate_seconds}.get(phase, 1.0)
	return {"active":active, "phase":NAMES[phase], "giver":giver, "receiver":receiver,
		"approach_t":marker, "sling_t":sling_t, "efficiency":efficiency, "precision":precision,
		"hand_contact":active and phase in [Phase.GRAB, Phase.SLING], "contact_point":contact_point,
		"visual_offsets":visual_offsets.duplicate(), "can_grab":can_grab,
		"grab_left":grab_left,"grab_right":grab_right,"grab_window_valid":grab_window_valid, "advanced":advanced,
		"phase_t":clampf(elapsed / maxf(0.001, duration), 0.0, 1.0),
		"phase_seconds":elapsed, "release_seconds":release_seconds, "release_reason":release_reason,
		"message":last_result, "position_valid":position_valid, "position_reason":position_reason,
		"failure_reason":failure_reason, "score":score_percent(), "speed_valid":speed_valid, "speed_reason":speed_reason}
