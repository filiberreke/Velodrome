extends RefCounted
## Same distance transform and banked offsets as main.gd, for design scenes.
var venue: Resource
var geometry: RefCounted
func _init(profile: Resource) -> void:
	venue = profile
	geometry = preload("res://track_geometry.gd").new(profile)
func phase(distance: float) -> float:
	return fposmod(venue.transition_m * 0.5 + venue.finish_straight_clearance_m - distance, venue.lap_length_m)
func bank(distance: float) -> float:
	return deg_to_rad(lerpf(venue.straight_bank_deg, venue.corner_bank_deg, geometry.bend(phase(distance))))
func at(distance: float, offset: float) -> Vector3:
	var s := phase(distance)
	var base: Vector2 = geometry.position(s)
	var angle: float = geometry.heading(s)
	var banking := bank(distance)
	var apron: float = minf(offset, venue.apron_width_m)
	var wood: float = clampf(offset - venue.apron_width_m, 0.0, venue.track_outer_offset_m - venue.apron_width_m)
	var outside: float = maxf(0.0, offset - venue.track_outer_offset_m)
	var lateral: float = apron + wood * cos(banking) + outside
	var height: float = 0.015 + apron * tan(deg_to_rad(venue.apron_bank_deg)) + wood * sin(banking) + outside * tan(banking)
	return Vector3(base.x + lateral*cos(angle), height, base.y + lateral*sin(angle))
func outward(distance: float) -> Vector3:
	var v := at(distance, 1.0) - at(distance, 0.0)
	v.y = 0.0
	return v.normalized()
func direction(distance: float, offset: float = 0.0) -> Vector3:
	return (at(distance + 0.05, offset) - at(distance - 0.05, offset)).normalized()
