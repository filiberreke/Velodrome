extends RefCounted
## Output-only impulse representation. Never changes speeds, watts or track grade.
## Defaults are provisional hardware-tuning values, not a resistance percentage.
var enabled := true
var intensity := 1.0
var duration_s := 1.6
var attack_s := 0.2
var decay_s := 1.0
var max_grade_pct := 20.0
var ramp_pct_per_s := 100.0
var mass_kg := 80.0 # Same equal rider/system mass as DernySession.next_speed.
var debug_log := false
var event: Dictionary = {}
var started_at := -INF
var peak_grade := 0.0
var duration := 0.0
var attack := 0.0
var decay := 0.0
var recovery_until := -INF

func clear(now: float = 0.0) -> void:
	if debug_log and not event.is_empty():
		print("MADISON_FEEDBACK_END ", JSON.stringify({"elapsed_s":maxf(0,now-started_at)}))
	event = {}; peak_grade = 0; started_at = -INF
	# Keep a fast return ramp until the bridge can receive the neutral target.
	recovery_until = now + 0.4

func start(exchange: Dictionary, now: float, player: int = 0) -> void:
	clear(now)
	if not enabled or float(exchange.delta_mps) <= 0 or player not in [exchange.giver,exchange.receiver]: return
	duration = maxf(0.4,duration_s)
	attack = clampf(attack_s,0.001,duration*0.5)
	decay = clampf(decay_s,0.001,duration-attack)
	# Smoothstep edges integrate to half their width. J/m = delta-v.
	# a = g*sin(atan(grade/100)); integrate the intended force pulse.
	var area := duration-0.5*(attack+decay)
	var acceleration := maxf(0,intensity)*float(exchange.delta_mps)/area
	var sine := clampf(acceleration/9.81,0,0.95)
	var grade := 100.0*tan(asin(sine))
	peak_grade = minf(grade,clampf(max_grade_pct,0,20))*(1 if player == exchange.giver else -1)
	event = exchange.duplicate(true)
	var before: float = exchange.before_mps[player]
	var after: float = exchange.after_mps[player]
	event.merge({"direction":1 if player == exchange.giver else -1,"duration_s":duration,
		"impulse_ns":mass_kg*float(exchange.delta_mps),
		"player_energy_delta_j":0.5*mass_kg*(after*after-before*before),
		"pair_energy_delta_j":0.5*mass_kg*(pow(exchange.after_mps[0],2)+pow(exchange.after_mps[1],2)-pow(exchange.before_mps[0],2)-pow(exchange.before_mps[1],2)),
		"peak_grade_pct":peak_grade,"clipped":grade>absf(peak_grade)})
	started_at = now; recovery_until = now+duration+0.4
	if debug_log: print("MADISON_FEEDBACK_START ", JSON.stringify(event))

func grade(now: float) -> float:
	if event.is_empty(): return 0.0
	var elapsed := maxf(0,now-started_at)
	if not enabled or elapsed+0.000001 >= duration:
		clear(now)
		return 0.0
	var weight := smoothstep(0,attack,elapsed)
	if elapsed > duration-decay: weight *= 1.0-smoothstep(duration-decay,duration,elapsed)
	# Shape force, rather than grade, so an unclipped pulse has the intended J/m.
	return 100.0*tan(asin(sin(atan(peak_grade/100.0))*weight))

func rate(now: float) -> float:
	return clampf(ramp_pct_per_s,0.1,100) if not event.is_empty() or now < recovery_until else 10.0
