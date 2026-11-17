extends RefCounted
const DISCIPLINES := ["scratch", "tempo", "elimination", "points"]
const FORMATS := {
	"short": {"scratch":20, "tempo":20, "elimination_interval":1, "points":40},
	"men": {"scratch":40, "tempo":40, "elimination_interval":2, "points":100},
	"women": {"scratch":40, "tempo":40, "elimination_interval":2, "points":80}
}
static func settings(format_id: String) -> Dictionary:
	return FORMATS.get(format_id, {}).duplicate(true)
