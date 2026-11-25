extends RefCounted
## Smooth, periodic oval. Curvature and banking share four transition curves.
## Offsets on the wood measure distance ON the surface, not its projection.
const DefaultVenue := preload("res://venues/velodrome.tres")
const STEP := 0.05
var LAP: float
var RADIUS: float
var STRAIGHT: float
var TRANSITION: float
var HALF_SAMPLES: int
var sample_step: float
var points := PackedVector2Array()

func _init(venue = DefaultVenue) -> void:
	assert(venue.validation_errors().is_empty(), "Invalid venue geometry")
	LAP = venue.lap_length_m
	RADIUS = venue.bend_radius_m
	STRAIGHT = (LAP - TAU * RADIUS) * 0.5
	TRANSITION = venue.transition_m
	HALF_SAMPLES = ceili(LAP * 0.5 / STEP)
	sample_step = LAP * 0.5 / float(HALF_SAMPLES)
	points.append(Vector2.ZERO)
	for i in range(HALF_SAMPLES):
		var angle := heading((float(i) + 0.5) * sample_step)
		points.append(points[-1] + Vector2(-sin(angle), cos(angle)) * sample_step)
	var center := points[HALF_SAMPLES] * 0.5
	for i in range(HALF_SAMPLES + 1):
		points[i] -= center

func _smooth(t: float) -> float:
	return t * t * t * (10.0 + t * (-15.0 + 6.0 * t))

func _integral(t: float) -> float:
	return t * t * t * t * (2.5 + t * (-3.0 + t))

func _phase(s: float) -> float:
	return fposmod(s - (STRAIGHT - TRANSITION * 0.5), LAP * 0.5)

func bend(s: float) -> float:
	var q := _phase(s)
	var arc := PI * RADIUS
	if q < TRANSITION:
		return _smooth(q / TRANSITION)
	if q < arc:
		return 1.0
	if q < arc + TRANSITION:
		return 1.0 - _smooth((q - arc) / TRANSITION)
	return 0.0

func heading(s: float) -> float:
	var unwrapped := s - (STRAIGHT - TRANSITION * 0.5)
	var turns := floorf(unwrapped / (LAP * 0.5))
	var q := _phase(s)
	var arc := PI * RADIUS
	var area := arc
	if q < TRANSITION:
		area = TRANSITION * _integral(q / TRANSITION)
	elif q < arc:
		area = q - TRANSITION * 0.5
	elif q < arc + TRANSITION:
		var t := (q - arc) / TRANSITION
		area = arc - TRANSITION * 0.5 + TRANSITION * (t - _integral(t))
	return turns * PI + area / RADIUS

func position(s: float) -> Vector2:
	var d := fposmod(s, LAP)
	var sign_value := 1.0 if d < LAP * 0.5 else -1.0
	d = fposmod(d, LAP * 0.5)
	var index := mini(int(d / sample_step), HALF_SAMPLES - 1)
	var t := (d - float(index) * sample_step) / sample_step
	var a := heading(float(index) * sample_step)
	var b := heading(float(index + 1) * sample_step)
	# Hermite interpolation keeps the tangent continuous between lookup samples.
	var m0 := Vector2(-sin(a), cos(a)) * sample_step
	var m1 := Vector2(-sin(b), cos(b)) * sample_step
	var t2 := t * t
	var t3 := t2 * t
	return sign_value * ((2.0*t3-3.0*t2+1.0)*points[index] + (t3-2.0*t2+t)*m0 + (-2.0*t3+3.0*t2)*points[index+1] + (t3-t2)*m1)
