extends RefCounted
const DISCIPLINES := ["scratch", "tempo", "elimination", "points"]
const FORMATS := {
	"short": {"scratch":20, "tempo":20, "elimination_interval":1, "points":40},
	"men": {"scratch":40, "tempo":40, "elimination_interval":2, "points":100},
	"women": {"scratch":40, "tempo":40, "elimination_interval":2, "points":80}
}
static func settings(format_id: String) -> Dictionary:
	return FORMATS.get(format_id, {}).duplicate(true)

# The final pair rides two more laps, matching standalone elimination finish rules.
static func race_laps(format_id: String, discipline: String, rider_count: int, lap_length_m: float = 250.0) -> int:
	var format_settings := settings(format_id)
	if format_settings.is_empty(): return 0
	if discipline == "elimination":
		return maxi(0, rider_count - 2) * int(format_settings.elimination_interval) + 2
	return roundi(float(format_settings.get(discipline, 0)) * 250.0 / lap_length_m)
