extends RefCounted
## Fixed-power pacer using the same force balance and banked gravity as the rider.
const Physics := preload("res://derny_session.gd")
const SEGMENTS := 256
const LIVE_STEP := 1.0/120.0
static var profiles := {}
static var powers := {}
var speed_mps := 0.0
var power_w := 0.0
var mean_kmh := -1.0
var planned_lane := -1.0

static func _profile(game, lane: float) -> Array:
	var key := snappedf(lane,.01)
	if profiles.has(key): return profiles[key]
	var result: Array = []
	for i in range(SEGMENTS):
		var a: Vector3 = game._at(game.LAP*i/float(SEGMENTS),lane)
		var b: Vector3 = game._at(game.LAP*(i+1)/float(SEGMENTS),lane)
		result.append(Vector2(a.distance_to(b),b.y-a.y))
	profiles[key] = result
	return result

static func _mean_speed(profile: Array, watts: float, initial: float, draft: float) -> float:
	var speed := initial
	var elapsed := 0.0
	var distance := 0.0
	# Settle onto a periodic lap before measuring the fourth lap.
	for lap in range(4):
		elapsed = 0.0
		distance = 0.0
		for segment: Vector2 in profile:
			var dt := segment.x/maxf(speed,.5)
			var gravity := clampf(-9.81*segment.y/maxf(segment.x,.001)*minf(1.0,speed*LIVE_STEP/.15),-2,2)
			var next := maxf(.1,Physics.next_speed(speed,watts,draft,dt)+gravity*dt)
			elapsed += 2.0*segment.x/maxf(.2,speed+next)
			distance += segment.x
			speed = next
	return distance/elapsed*3.6

static func power_for_mean(game, kmh: float, lane: float, draft: float = 0.0) -> float:
	var key := Vector3(kmh,snappedf(lane,.01),draft)
	if powers.has(key): return powers[key]
	var profile := _profile(game,lane)
	var low := 0.0
	var high := maxf(300,Physics.required_power(kmh/3.6,draft)*2+50)
	for i in range(14):
		var middle := (low+high)*.5
		if _mean_speed(profile,middle,kmh/3.6,draft) < kmh: low = middle
		else: high = middle
	powers[key] = (low+high)*.5
	return powers[key]

func configure(game, target_mean_kmh: float, target_lane: float) -> void:
	if is_equal_approx(mean_kmh,target_mean_kmh) and is_equal_approx(planned_lane,target_lane): return
	mean_kmh = target_mean_kmh
	planned_lane = target_lane
	power_w = power_for_mean(game,mean_kmh,planned_lane)

func advance_speed(game, at: float, old_lane: float, lane: float, dt: float) -> void:
	var previous: Vector3 = game._at(at,old_lane)
	var side: Vector3 = game._at(at,lane)
	speed_mps = Physics.next_speed(speed_mps,power_w,0.0,dt)
	var next: Vector3 = game._at(at+speed_mps*dt/game._path_metric(at,lane),lane)
	speed_mps = game._banked_speed(speed_mps,next.y-side.y,side.y-previous.y,absf(lane-old_lane),dt,power_w)
