extends RefCounted
var path := "user://records/ai_riders.json"
var data: Dictionary = {}

func _init() -> void:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary: data = parsed

func record(id: String, mode: int, distance: int, percent: float, seconds: float, peak: float, form: float, parameters: Dictionary = {}) -> void:
	if id.is_empty() or seconds <= 0 or not is_finite(seconds): return
	var key := "%d_%d_%d" % [mode, distance, roundi(percent)]
	if not parameters.is_empty(): key += "_" + JSON.stringify(parameters).sha256_text().left(12)
	var personal: Dictionary = data.get(id, {})
	var previous: Dictionary = personal.get(key, {})
	if previous.is_empty() or seconds < float(previous.time_s):
		personal[key] = {"time_s":seconds, "peak_w":maxf(peak, float(previous.get("peak_w",0.0))), "form":form, "ai_percent":percent, "mode":mode, "distance_m":distance, "parameters":parameters}
	elif peak > float(previous.get("peak_w", 0.0)):
		previous["peak_w"] = peak
	data[id] = personal
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data))

func personal(id: String) -> Dictionary:
	return data.get(id, {}).duplicate(true)
