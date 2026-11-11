extends RefCounted
## Smooth, periodic oval. Curvature and banking share four transition curves.
## Offsets on the wood measure distance ON the surface, not its projection.
const LAP := 250.0
const RADIUS := 18.0
const STRAIGHT := (LAP - TAU * RADIUS) * 0.5
const TRANSITION := 36.0
const STEP := 0.05
const HALF_SAMPLES := 2500
var points := PackedVector2Array()

func _init() -> void:
	points.append(Vector2.ZERO)
	for i in range(HALF_SAMPLES):
		var angle := heading((float(i) + 0.5) * STEP)
		points.append(points[-1] + Vector2(-sin(angle), cos(angle)) * STEP)
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
	var index := mini(int(d / STEP), HALF_SAMPLES - 1)
	var t := (d - float(index) * STEP) / STEP
	var a := heading(float(index) * STEP)
	var b := heading(float(index + 1) * STEP)
	# Hermite interpolation keeps the tangent continuous between lookup samples.
	var m0 := Vector2(-sin(a), cos(a)) * STEP
	var m1 := Vector2(-sin(b), cos(b)) * STEP
	var t2 := t * t
	var t3 := t2 * t
	return sign_value * ((2.0*t3-3.0*t2+1.0)*points[index] + (t3-2.0*t2+t)*m0 + (-2.0*t3+3.0*t2)*points[index+1] + (t3-t2)*m1)
