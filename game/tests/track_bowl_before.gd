extends "res://main.gd"
func _ready() -> void: pass
func _bank_angle(s: float) -> float:
	var d: float = fposmod(s, LAP)
	var corner_progress: float = -1.0
	var arc_length: float = PI * RADIUS
	if d >= STRAIGHT and d <= STRAIGHT + arc_length:
		corner_progress = d - STRAIGHT
	elif d >= 2.0 * STRAIGHT + arc_length:
		corner_progress = d - (2.0 * STRAIGHT + arc_length)
	if corner_progress < 0.0:
		return deg_to_rad(STRAIGHT_BANK_DEG)
	var entry: float = clampf(corner_progress / 12.0, 0.0, 1.0)
	var exit_factor: float = clampf((arc_length - corner_progress) / 12.0, 0.0, 1.0)
	var a: float = minf(entry, exit_factor)
	var smooth: float = a * a * (3.0 - 2.0 * a)
	return deg_to_rad(lerpf(STRAIGHT_BANK_DEG, CORNER_BANK_DEG, smooth))

func _at(distance: float, offset: float) -> Vector3:
	# Counter-clockwise velodrome: reversed traversal of the old clockwise path.
	# Positive offsets stay toward the outside, independent of direction.
	# At the right-hand straight the rider now heads toward -Z; the infield is LEFT.
	var s: float = _track_s(distance)
	var x := 0.0
	var z := 0.0
	var nx := 0.0
	var nz := 0.0
	if s < STRAIGHT:
		x = RADIUS
		z = -STRAIGHT / 2.0 + s
		nx = 1.0
	elif s < STRAIGHT + PI * RADIUS:
		var angle := (s - STRAIGHT) / RADIUS
		x = RADIUS * cos(angle)
		z = STRAIGHT / 2.0 + RADIUS * sin(angle)
		nx = cos(angle)
		nz = sin(angle)
	elif s < 2.0 * STRAIGHT + PI * RADIUS:
		x = -RADIUS
		z = STRAIGHT / 2.0 - (s - STRAIGHT - PI * RADIUS)
		nx = -1.0
	else:
		var angle := PI + (s - 2.0 * STRAIGHT - PI * RADIUS) / RADIUS
		x = RADIUS * cos(angle)
		z = -STRAIGHT / 2.0 + RADIUS * sin(angle)
		nx = cos(angle)
		nz = sin(angle)
	# The blue apron stays at a fixed 12-degree cross-slope all the way around.
	# Wood starts at the same height at TRACK_EDGE, then uses the variable
	# banking angle; the shared boundary therefore remains watertight.
	var apron_width: float = minf(offset, TRACK_EDGE)
	var wood_width: float = maxf(0.0, offset - TRACK_EDGE)
	var height: float = 0.015 + apron_width * tan(deg_to_rad(BLUE_APRON_BANK_DEG)) + wood_width * tan(_bank_angle(s))
	return Vector3(x + offset * nx, height, z + offset * nz)

