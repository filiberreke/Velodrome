extends RefCounted
## Only user-authored workouts; built-in FTP tests never enter this collection.
var folder := "user://workouts"
var error := ""
func _path(id: String) -> String:
	return folder.path_join(id+".json") if not id.is_empty() and id == id.validate_filename() and not id.contains("..") else ""
func save_workout(id: String, title: String, blocks: Array) -> String:
	error = ""
	if blocks.is_empty(): error = "Voeg minstens één blok toe."; return ""
	if id.is_empty(): id = "workout-%d-%08x" % [Time.get_ticks_usec(),randi()]
	var path := _path(id)
	if path.is_empty(): error = "Ongeldige workout."; return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: error = "Workout kon niet worden opgeslagen."; return ""
	file.store_string(JSON.stringify({"version":1,"id":id,"name":title.strip_edges() if not title.strip_edges().is_empty() else "Naamloze workout","blocks":blocks,"updated":Time.get_unix_time_from_system()}))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path)) != OK: error = "Opslaan mislukt."; return ""
	return id
func get_workout(id: String) -> Dictionary:
	var path := _path(id)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary and value.get("version") == 1 and value.get("blocks") is Array else {}
func delete_workout(id: String) -> bool:
	error = ""
	var path := _path(id)
	if path.is_empty() or get_workout(id).is_empty():
		error = "Workout niet gevonden."
		return false
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		error = "Workout kon niet worden verwijderd."
		return false
	return true
func all_workouts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(folder)
	if directory == null: return result
	for filename in directory.get_files():
		if not filename.ends_with(".json"): continue
		var value := get_workout(filename.get_basename())
		if not value.is_empty(): result.append(value)
	result.sort_custom(func(a,b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result
static func duration(block: Dictionary) -> float:
	return float(block.get("repeat",1))*(float(block.get("on_duration",0))+float(block.get("off_duration",0))) if block.kind == "IntervalsT" else float(block.duration)
static func total_seconds(blocks: Array) -> float:
	var result := 0.0
	for block in blocks: result += duration(block)
	return result

static func average_target(blocks: Array) -> float:
	var weighted := 0.0
	var measured_seconds := 0.0
	for block in blocks:
		if block.kind == "FreeRide": continue
		var seconds := duration(block)
		if seconds <= 0: continue
		if block.kind == "IntervalsT":
			weighted += float(block.get("repeat", 1)) * (float(block.on_duration) * float(block.on_power) + float(block.off_duration) * float(block.off_power))
		else:
			var low := float(block.get("power_low", 0))
			var high := float(block.get("power_high", low)) if block.kind in ["Warmup", "Cooldown", "Ramp"] else low
			weighted += seconds * (low + high) * 0.5
		measured_seconds += seconds
	return weighted / measured_seconds if measured_seconds > 0 else -1.0

static func intensity_level(target: float) -> int:
	if target < 0: return 0
	if target < .55: return 1
	if target < .7: return 2
	if target < .85: return 3
	if target < 1.0: return 4
	return 5
