extends RefCounted
## Between-race recovery of the Wprime reserve shown in the AI rider HUD.
## The remaining deficit is 20% after one hour; full recovery after four hours.
## This is deliberately separate from in-race Wprime regeneration and fatigue.

static func recovered_fraction(elapsed_seconds: float) -> float:
	if elapsed_seconds <= 0.0:
		return 0.0
	if elapsed_seconds >= 14400.0:
		return 1.0
	# Exponential: 80% of deficit restored after 3600 seconds.
	return 1.0 - pow(0.2, elapsed_seconds / 3600.0)

static func recovered_reserve(finish_reserve: float, elapsed_seconds: float) -> float:
	var initial := clampf(finish_reserve, 0.0, 1.0)
	return clampf(initial + (1.0 - initial) * recovered_fraction(elapsed_seconds), 0.0, 1.0)
