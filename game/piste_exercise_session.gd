extends RefCounted
## Exercise results use unwrapped reference distance, independent of camera or frame rate.
const LAP := 250.0
const PACK_COUNT := 8
const PACK_SPACING := 3.0
const FOLLOW_GAP := 3.0
const START_KMH := 30.0
var kind := "flying_start"
var phase := "IDLE"
var reason := ""
var origin := 0.0
var elapsed := 0.0
var peak_w := 0.0
var energy_j := 0.0
var entry_kmh := 0.0
var gained_m := 0.0
var target_kmh := 30.0
var time_limit := 600.0
var successful := false
var last_fraction := 1.0
var laps: Array[Dictionary] = []
var lap_started_s := 0.0
func running() -> bool: return phase == "RIDE"
static func title(mode: String) -> String:
	return {"flying_start":"Vliegende start","take_lap":"Neem een ronde","free_ride":"Vrije training"}.get(mode,"Pistetraining")
static func pursuit_line(game) -> float:
	# The same reference coordinate as the painted pursuit line in main.gd.
	return fposmod(game.PURSUIT_START_M,game.LAP)
func start(mode: String, at: float, pack_kmh: float, seconds: float) -> void:
	kind = mode; origin = at; target_kmh = pack_kmh; time_limit = seconds
	phase = "RIDE"; reason = ""; elapsed = 0; peak_w = 0; energy_j = 0
	entry_kmh = 0; gained_m = 0; successful = false; last_fraction = 1
	laps.clear(); lap_started_s = 0
func stop(message: String) -> void:
	if not running(): return
	phase = "RESULT"; reason = message
static func pack_tail(front: float) -> float: return front-(PACK_COUNT-1)*PACK_SPACING
func progress(player: float, pack: float) -> float:
	return player-origin if kind == "flying_start" else player-pack_tail(pack)+FOLLOW_GAP
func observe(dt: float, before: float, after: float, speed_before: float, speed_after: float, power: float, pack_before: float, pack_after: float) -> void:
	if not running() or dt <= 0: return
	if kind == "free_ride":
		last_fraction = 1
		var previous_elapsed := elapsed
		elapsed += dt; peak_w = maxf(peak_w,maxf(0,power)); energy_j += maxf(0,power)*dt
		gained_m = after-origin
		if after > before:
			for number in range(maxi(1,floori((before-origin)/LAP)+1),floori((after-origin)/LAP)+1):
				var crossing := previous_elapsed+dt*(origin+number*LAP-before)/(after-before)
				laps.append({"lap":number,"seconds":crossing-lap_started_s,"elapsed_s":crossing})
				lap_started_s = crossing
		return
	var previous := progress(before,pack_before)
	var current := progress(after,pack_after)
	last_fraction = 1.0
	if previous < LAP and current >= LAP:
		last_fraction = clampf((LAP-previous)/maxf(.000001,current-previous),0,1)
		# Success must occur before the time limit, not merely in the same frame.
		if elapsed+dt*last_fraction <= time_limit:
			successful = true
			entry_kmh = lerpf(speed_before,speed_after,last_fraction)*3.6
		else: last_fraction = clampf((time_limit-elapsed)/dt,0,1)
	elif elapsed+dt >= time_limit: last_fraction = clampf((time_limit-elapsed)/dt,0,1)
	elapsed += dt*last_fraction
	peak_w = maxf(peak_w,maxf(0,power))
	energy_j += maxf(0,power)*dt*last_fraction
	gained_m = lerpf(previous,current,last_fraction)
	if successful: stop("Startlijn gepasseerd" if kind == "flying_start" else "Ronde gewonnen")
	elif elapsed >= time_limit-.000001: stop("Tijdslimiet bereikt")
func result() -> Dictionary:
	return {"kind":kind,"title":title(kind),"exercise_success":successful,"entry_speed_kmh":entry_kmh,"peak_power_w":peak_w,"mean_power_w":energy_j/maxf(.001,elapsed),"gained_m":gained_m,"peloton_kmh":target_kmh,"time_limit_s":time_limit,"laps":laps.duplicate(true)}
