extends RefCounted
## Deterministic pacing and wake geometry. No race state or trainer commands.
signal speed_changed(kmh: int)
signal gesture_requested(action: String)
const LAP := 250.0
const DEFAULT_START_KMH := 30
const MIN_START_KMH := 10
const MAX_START_KMH := 60
const GUIDANCE_MAX_W_PER_S := 20.0
const STEP_SECONDS := 60.0
const MAX_DRAFT := 0.60
const LOSS_GAP_M := 15.0
const LOSS_SECONDS := 5.0
var start_speed_kmh := DEFAULT_START_KMH
var runup_start_kmh := 20.0
var guidance_power_w := 0.0
var phase := "IDLE"
var derny_distance := 0.0
var runup_distance := 0.0
var elapsed := 0.0
var target_kmh := 20.0
var completed_kmh := 0
var loss_seconds := 0.0
var reason := ""
var announced_step := -1
var look_cooldown := 10.0

func running() -> bool: return phase in ["RUNUP", "PACE"]
func start(at: float, chosen_start_kmh: float = DEFAULT_START_KMH) -> void:
	start_speed_kmh = clampi(roundi(chosen_start_kmh),MIN_START_KMH,MAX_START_KMH)
	runup_start_kmh = minf(20.0,start_speed_kmh*2.0/3.0)
	phase = "RUNUP"
	derny_distance = at + 3.0
	runup_distance = 0.0
	elapsed = 0.0
	target_kmh = runup_start_kmh
	guidance_power_w = required_power(target_kmh/3.6,MAX_DRAFT)
	completed_kmh = 0
	loss_seconds = 0.0
	reason = ""
	announced_step = -1
	look_cooldown = 10.0

func stop(message: String) -> void:
	if not running(): return
	phase = "RESULT"
	reason = message

static func draft_reduction(gap: float, lateral: float) -> float:
	# Origin-to-origin spacing; no shelter beside or ahead of the motorbike.
	if gap <= 1.5 or gap >= 14.0 or absf(lateral) >= 1.0: return 0.0
	var longitudinal := minf(1.0, (14.0 - gap) / 10.0)
	return MAX_DRAFT * longitudinal * pow(1.0 - absf(lateral), 2.0)

static func next_speed(speed: float, power: float, reduction: float, dt: float) -> float:
	var drag := .5 * 1.20 * .334 * speed * speed * (1.0 - clampf(reduction, 0, MAX_DRAFT))
	var rolling := .004 * 80.0 * 9.81
	var drive := maxf(0.0, power) * .975 / maxf(speed, 2.5)
	return maxf(0.0, speed + (drive - drag - rolling) / 80.0 * dt)

func advance(dt: float, metric: float, player_distance: float, player_metric: float, actual_speed_mps: float = -1.0) -> void:
	if not running() or dt <= 0.0: return
	var travel := (actual_speed_mps if actual_speed_mps >= 0 else target_kmh/3.6) * dt
	derny_distance += travel / maxf(.5, metric)
	var gap := (derny_distance - player_distance) * maxf(.5, player_metric)
	look_cooldown -= dt
	if phase == "RUNUP":
		runup_distance += travel
		target_kmh = lerpf(runup_start_kmh, float(start_speed_kmh), clampf(runup_distance / LAP, 0, 1))
		if runup_distance >= LAP:
			phase = "PACE"
			elapsed = 0.0
			target_kmh = start_speed_kmh
			gesture_requested.emit("speed_up")
			speed_changed.emit(start_speed_kmh)
	else:
		var previous_step := int((elapsed + .000001) / STEP_SECONDS)
		elapsed += dt
		var step := int((elapsed + .000001) / STEP_SECONDS)
		if step > previous_step:
			completed_kmh = start_speed_kmh + step - 1
			target_kmh = start_speed_kmh + step
			speed_changed.emit(int(target_kmh))
		if elapsed - step * STEP_SECONDS >= STEP_SECONDS - 1.5 and announced_step != step:
			announced_step = step
			gesture_requested.emit("speed_up")
			look_cooldown = maxf(look_cooldown, 3.0)
		loss_seconds = loss_seconds + dt if gap > LOSS_GAP_M else 0.0
		if loss_seconds >= LOSS_SECONDS: stop("Aansluiting verloren")
	if running() and look_cooldown <= 0.0:
		gesture_requested.emit("look_back")
		look_cooldown = 5.0 if gap > 5.0 else 16.0

static func required_power(speed_mps: float, reduction: float, grade_pct: float = 0.0) -> float:
	var v := maxf(0, speed_mps)
	var aero := .5 * 1.20 * .334 * v * v * (1-clampf(reduction,0,MAX_DRAFT))
	return maxf(0, (aero + .004 * 80 * 9.81 + 80 * 9.81 * grade_pct / 100) * v / .975)

func update_guidance(dt: float, lap_mean_power: float = -1.0) -> void:
	# A closed lap returns to the same height: signed gravitational work sums to zero.
	# Show mean power at pacing speed in the wheel, not the instantaneous hill demand.
	# Actual physics and trainer grade still use the unchanged road_grade path.
	if dt <= 0: return
	var desired := lap_mean_power if lap_mean_power >= 0 else required_power(target_kmh/3.6,MAX_DRAFT)
	guidance_power_w = move_toward(guidance_power_w,desired,GUIDANCE_MAX_W_PER_S*dt)

static func lane_at_speed(speed_kmh: float, initial_kmh: float) -> float:
	# Existing track: lowest riding corridor 1.18 m; blue line painted 3.53–3.58 m.
	var steps := floori(maxf(0,speed_kmh-initial_kmh)/5.0)
	return minf(3.55,1.18 + steps*.60)
