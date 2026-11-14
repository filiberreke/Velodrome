extends RefCounted
## Classic 20-minute FTP estimate. Only fresh measured power samples count.
const DURATION := 1200.0
const SIGNAL_TIMEOUT := 1.25
var phase := "IDLE"
var reason := ""
var start_at := -1.0
var last_at := -1.0
var last_power := 0.0
var energy := 0.0
var covered := 0.0

func start(now: float) -> void:
	phase = "TEST"
	reason = ""
	start_at = now
	last_at = -1.0
	last_power = 0.0
	energy = 0.0
	covered = 0.0

func running() -> bool:
	return phase == "TEST"

func sample(now: float, power: float) -> void:
	if not running(): return
	if not is_finite(now) or not is_finite(power) or power < 0.0:
		stop("Ongeldige vermogensmeting")
		return
	if now < start_at: return
	if last_at < 0.0 and now - start_at > SIGNAL_TIMEOUT:
		stop("Vermogenssignaal verloren")
		return
	if last_at >= 0.0:
		var dt := now - last_at
		if dt <= 0.0: return
		if dt > SIGNAL_TIMEOUT:
			stop("Vermogenssignaal verloren")
			return
		var usable := minf(dt, maxf(0.0, start_at + DURATION - last_at))
		energy += last_power * usable
		covered += usable
	last_at = now
	last_power = power
	if now >= start_at + DURATION:
		phase = "RESULT"
		reason = "20 minuten voltooid"

func tick(now: float) -> void:
	if running() and now - (last_at if last_at >= 0.0 else start_at) > SIGNAL_TIMEOUT:
		stop("Vermogenssignaal verloren")

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
