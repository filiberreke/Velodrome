extends RefCounted
## Monotonic session clock and time-weighted, zero-order-held measured power.
const WARMUP_SECONDS := 300.0
const MAX_SAMPLE_GAP := preload("res://trainer_signal.gd").HOLD_SECONDS
const START_W := 100
const STEP_W := 20
const STEP_SECONDS := 60.0
const MAX_W := 1300
var phase := "IDLE"
var reason := ""
var started_at := 0.0
var ramp_at := -1.0
var last_at := -1.0
var last_power := 0.0
var best_60 := 0.0
var low_seconds := 0.0
var stall_seconds := 0.0
var previous_target := 100
var segments: Array[Dictionary] = []

func running() -> bool:
	return phase in ["CONNECTING", "WARMUP", "RAMP"]

func start(now: float) -> void:
	phase = "WARMUP"
	reason = ""
	started_at = now
	ramp_at = -1.0
	last_at = -1.0
	best_60 = 0.0
	low_seconds = 0.0
	stall_seconds = 0.0
	previous_target = 100
	segments.clear()

func target(now: float) -> int:
	if phase == "WARMUP": return 0
	if phase != "RAMP": return START_W
	return START_W + STEP_W * int(maxf(0.0, now - ramp_at) / STEP_SECONDS)

static func preview_blocks(ftp_w: float) -> Array[Dictionary]:
	# Show the full protocol up to its safety limit; the rider can stop earlier.
	var blocks: Array[Dictionary] = [{"kind":"FreeRide","duration":WARMUP_SECONDS,"power_low":0,"power_high":0}]
	for watts in range(START_W,MAX_W+1,STEP_W):
		var fraction := watts/maxf(20,ftp_w)
		blocks.append({"kind":"SteadyState","duration":STEP_SECONDS,"power_low":fraction,"power_high":fraction})
	return blocks

func tick(now: float, confirmed: bool) -> void:
	if phase == "CONNECTING":
		if confirmed:
			phase = "RAMP"
			ramp_at = now
			last_at = -1.0
		elif now - started_at > 8.0: stop("Trainer bevestigt ERG niet")
	elif phase == "WARMUP" and now - started_at >= WARMUP_SECONDS:
		phase = "CONNECTING"
		started_at = now
	elif phase == "RAMP" and target(now) > MAX_W:
		stop("Veiligheidslimiet van 1300 W bereikt")

func stop(message: String) -> void:
	if not running(): return
	phase = "RESULT"
	reason = message

func ftp() -> float:
	return 0.75 * best_60

func _average(end: float) -> float:
	var energy := 0.0
	var duration := 0.0
	for s in segments:
		var dt := maxf(0.0, minf(end, s.b) - maxf(end - 60.0, s.a))
		energy += dt * s.w
		duration += dt
	return energy / 60.0 if duration >= 60.0 - 0.00001 else -1.0

func interrupt_measurements() -> void:
	segments.clear(); last_at = -1; low_seconds = 0; stall_seconds = 0
func sample(now: float, power: float, cadence: float = -1.0) -> void:
	if phase != "RAMP": return
	if not is_finite(power) or power < 0.0:
		stop("Ongeldige vermogensmeting")
		return
	if last_at >= 0.0:
		var dt := now - last_at
		if dt <= 0.0: return
		if dt > MAX_SAMPLE_GAP:
			# Resume the test, but never fill missing measured seconds with held watts.
			segments.clear(); low_seconds = 0; stall_seconds = 0
			last_at = now; last_power = power
			return
		segments.append({"a": last_at, "b": now, "w": last_power})
		# A rolling integral is piecewise linear. Its extrema occur at sample
		# boundaries or at those boundaries shifted by exactly 60 seconds.
		for s in segments:
			for boundary in [s.a, s.b]:
				var candidate: float = boundary + 60.0
				if candidate > last_at and candidate < now:
					best_60 = maxf(best_60, _average(candidate))
		best_60 = maxf(best_60, _average(now))
		while not segments.is_empty() and segments[0].b <= now - 60.0:
			segments.pop_front()
		var current_target := target(now)
		if current_target != previous_target:
			low_seconds = 0.0
			stall_seconds = 0.0
		previous_target = current_target
		# Ten seconds to settle after each step. Missing cadence never means zero.
		if fmod(now - ramp_at, 60.0) >= 10.0:
			low_seconds = low_seconds + dt if power < current_target * 0.85 else 0.0
			stall_seconds = stall_seconds + dt if cadence >= 0.0 and cadence < 40.0 and power < current_target * 0.90 else 0.0
			if low_seconds >= 10.0 or stall_seconds >= 5.0:
				stop("Doelvermogen niet meer vol te houden")
	last_at = now
	last_power = power
