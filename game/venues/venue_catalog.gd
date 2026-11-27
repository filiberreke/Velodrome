extends RefCounted
## Playable stadiums. Every game owns an independent profile instance.
const DEFAULT_ID := "velodrome"
const DEFAULT := preload("res://venues/velodrome.tres")
const GENT := preload("res://venues/gent.tres")
const ROUBAIX := preload("res://venues/roubaix.tres")

static func available_ids() -> PackedStringArray:
	return PackedStringArray([DEFAULT_ID, "gent", "roubaix"])

static func default_venue():
	# Resources are cached by Godot. Each game owns its data and nested arrays.
	return DEFAULT.duplicate(true)

static func find(venue_id: String):
	if venue_id == DEFAULT_ID: return default_venue()
	if venue_id == "gent": return GENT.duplicate(true)
	if venue_id == "roubaix": return ROUBAIX.duplicate(true)
	return null

static func resolved(venue_id: String):
	var result = find(venue_id)
	return default_venue() if result == null else result

static func metadata(venue_id: String) -> Dictionary:
	var profile = resolved(venue_id)
	return {"venue_id": profile.id, "lap_length_m": profile.lap_length_m, "geometry_version": 1}

static func compatible(data: Dictionary, venue_id: String) -> bool:
	var profile = resolved(venue_id)
	var length = data.get("lap_length_m", 250.0)
	var version = data.get("geometry_version", 1)
	if not (length is int or length is float) or not is_finite(float(length)): return false
	if not (version is int or version is float) or float(version) != 1.0: return false
	return data.get("venue_id", DEFAULT_ID) is String and String(data.get("venue_id", DEFAULT_ID)) == profile.id and is_equal_approx(float(length), profile.lap_length_m)
