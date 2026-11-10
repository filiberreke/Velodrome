extends RefCounted
## Shared race/training signal timings. Session time freezes after the hold window.
const LIVE_SECONDS := 1.0
const HOLD_SECONDS := 10.0
const CONTROL_HOLD_SECONDS := .5
var last_valid := -100.0
var dropout_since := -1.0
var paused_since := -1.0
var paused_total := 0.0
var resumed_at := -100.0
var valid := false
func update(now: float) -> void:
	if last_valid < 0: return
	if valid and now-last_valid > LIVE_SECONDS:
		valid = false; dropout_since = last_valid
	if not valid and dropout_since >= 0 and paused_since < 0 and now-dropout_since > HOLD_SECONDS:
		paused_since = dropout_since+HOLD_SECONDS
func receive(ok: bool, now: float) -> void:
	if ok:
		update(now)
		if paused_since >= 0:
			paused_total += maxf(0,now-paused_since); resumed_at = now
		last_valid = now; valid = true; dropout_since = -1; paused_since = -1
	else:
		valid = false
		if dropout_since < 0 and last_valid >= 0: dropout_since = now
		update(now)
func live(now: float) -> bool: update(now); return valid
func usable(now: float) -> bool: update(now); return last_valid >= 0 and paused_since < 0
func paused_seconds(now: float) -> float:
	update(now)
	return maxf(0,now-paused_since) if paused_since >= 0 else 0.0
func time(now: float) -> float:
	update(now)
	return now-paused_total-(maxf(0,now-paused_since) if paused_since >= 0 else 0.0)
func reset_clock(now: float) -> void:
	paused_total = 0; paused_since = -1; resumed_at = now
func status(now: float) -> String:
	update(now)
	if paused_since >= 0: return "Training gepauzeerd · wacht op trainerverbinding"
	if not valid and dropout_since >= 0: return "Signaal tijdelijk weg · laatste vermogen behouden (%d s)" % maxi(0,ceili(HOLD_SECONDS-(now-dropout_since)))
	return ""
