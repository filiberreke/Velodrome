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
var visual_offsets: Array[float] = [0.0, 0.0]
var contact_point := Vector3.ZERO
var last_result := "Zoek je ploegmaat op bij de blauwe lijn"
var _impulse := 0.0
var release_reason := ""

func reset() -> void:
	phase = Phase.SEPARATE
	active = false
	giver = 0; receiver = 1; active_rider = 0
	elapsed = 0.0; cooldown = 0.0; marker = 0.0; precision = 0.0
	sling_t = 0.0; efficiency = 0.0; held = false; can_grab = false
	visual_offsets.assign([0.0, 0.0])
	_impulse = 0.0
	release_reason = ""
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
	if not active or phase != Phase.APPROACH: return
	if not can_grab:
		last_result = "Buiten handbereik"
		missed.emit(last_result)
		return
	precision = clampf(1.0 - absf(marker - 0.8) / 0.2, 0.0, 1.0)
	sling_t = 0.0
	efficiency = 0.0
	_change(Phase.GRAB)

func _release(reason: String = "player") -> void:
	release_reason = reason
	efficiency = precision * envelope(sling_t) * (1.0 if advanced else 0.7)
	last_result = "Aflossing: %d%% momentum" % roundi(efficiency * 100.0)
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
		last_result = reason
		missed.emit(reason)
		_change(Phase.SEPARATE)
	can_grab = false
	held = false

func step(game, dt: float) -> void:
	if dt <= 0.0: return
	cooldown = maxf(0.0, cooldown - dt)
	if game.finished or game.finish_times[0] >= 0.0 or game.finish_times[1] >= 0.0:
		cancel()
	var gap: float = wrapf(game.distances[receiver] - game.distances[giver], -125.0, 125.0)
	if not active and cooldown <= 0.0 and not game.finished and game.finish_times[0] < 0.0 and game.finish_times[1] < 0.0:
		giver = active_rider; receiver = 1 - giver
		gap = wrapf(game.distances[receiver] - game.distances[giver], -125.0, 125.0)
		if gap >= -1.5 and gap <= approach_distance and game.speeds[giver] > game.speeds[receiver] + 0.1:
			active = true
			precision = 0.0; efficiency = 0.0; sling_t = 0.0
			release_reason = ""
			_impulse = 0.0
			_change(Phase.APPROACH)
	elapsed += dt
	var ordered: bool = game.lane_offsets[giver] < game.lane_offsets[receiver] - 0.4
	var receiver_in_zone: bool = absf(game.lane_offsets[receiver] - 3.58) <= 0.15 or absf(game.lane_offsets[receiver] - 2.98) <= 0.15
	var a: Vector3 = game._at(game.distances[giver], game.lane_offsets[giver])
	var b: Vector3 = game._at(game.distances[receiver], game.lane_offsets[receiver])
	var physical_span: float = a.distance_to(b)
	var converging: bool = active and phase in [Phase.APPROACH, Phase.GRAB, Phase.SLING] and ordered and receiver_in_zone and physical_span <= max_reach
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
	can_grab = active and phase == Phase.APPROACH and ordered and receiver_in_zone and physical_span <= max_reach + 0.0001 and a.distance_to(b) <= visual_reach + 0.05
	if active:
		match phase:
			Phase.APPROACH:
				_impulse = minf(max_impulse_mps, maxf(0.0, game.speeds[giver]) * impulse_speed_fraction)
				marker = clampf((approach_distance - gap) / (approach_distance + 2.5), 0.0, 1.0)
				if gap < -2.5 or gap > approach_distance + 3.0: cancel("Greep gemist — probeer de volgende ronde")
			Phase.GRAB, Phase.SLING:
				if not ordered or not receiver_in_zone:
					cancel("Handcontact verloren")
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
		"visual_offsets":visual_offsets.duplicate(), "can_grab":can_grab, "advanced":advanced,
		"phase_t":clampf(elapsed / maxf(0.001, duration), 0.0, 1.0),
		"phase_seconds":elapsed, "release_seconds":release_seconds, "release_reason":release_reason,
		"message":last_result}
