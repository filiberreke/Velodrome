extends RefCounted
## Twenty minutes on the shared session clock; paused wall time never adds energy.
const DURATION := 1200.0
const MAX_SAMPLE_GAP := preload("res://trainer_signal.gd").HOLD_SECONDS
var phase := "IDLE"
var reason := ""
var start_at := -1.0
var last_at := -1.0
var integrated_until := -1.0
var last_power := 0.0
var energy := 0.0
var covered := 0.0

func start(now: float) -> void:
	phase = "TEST"
	reason = ""
	start_at = now
	last_at = -1.0
	integrated_until = now
	last_power = 0.0
	energy = 0.0
	covered = 0.0

func running() -> bool:
	return phase == "TEST"

func sample(now: float, power: float, _cadence: float = -1.0) -> void:
	if not running(): return
	if not is_finite(now) or not is_finite(power) or power < 0.0:
		stop("Ongeldige vermogensmeting")
		return
	if now < start_at or (last_at >= 0.0 and now <= last_at): return
	_advance(now)
	last_at = now
	last_power = power
	# Never fill an uncovered gap with the newly received power.
	integrated_until = maxf(integrated_until, now)

func _advance(now: float) -> void:
	if not running() or last_at < 0.0: return
	var end := minf(minf(now, last_at + MAX_SAMPLE_GAP), start_at + DURATION)
	var dt := maxf(0.0, end - integrated_until)
	energy += last_power * dt
	covered += dt
	integrated_until = maxf(integrated_until, end)
	if covered >= DURATION - 0.0001:
		phase = "RESULT"
		reason = "20 minuten voltooid"

func tick(now: float) -> void:
	_advance(now)

func stop(message: String) -> void:
	if not running(): return
	phase = "RESULT"
	reason = message

func complete() -> bool:
	return phase == "RESULT" and reason == "20 minuten voltooid" and covered >= DURATION - 0.0001

func average_power() -> float:
	return energy / DURATION if complete() else 0.0

func ftp() -> float:
	return 0.95 * average_power()
