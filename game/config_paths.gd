extends RefCounted
## Personal project files beside the game; generated settings stay in user://config.
static func project_path(name: String) -> String:
	return "res://config/" + name if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("config").path_join(name)

static func migrate(old: String, target: String) -> void:
	if FileAccess.file_exists(target) or not FileAccess.file_exists(old): return
	var parent := ProjectSettings.globalize_path(target.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(parent) != OK: return
	# Never overwrite an existing config. A read-only old installation remains readable.
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(target))
	if error != OK: push_warning("Configuratie blijft op oude locatie: " + old)

static func legacy_project_path(name: String) -> String:
	return "res://" + name if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join(name)

static func resolve_project(name: String, sample: bool = false) -> String:
	for candidate in [project_path(name), "user://config/" + name, legacy_project_path(name)]:
		if FileAccess.file_exists(candidate): return candidate
	if sample:
		var example := name.replace(".cfg", ".example.cfg")
		for candidate in [project_path(example), "res://config/" + example]:
			if FileAccess.file_exists(candidate): return candidate
	return ""

static func load_project(cfg: ConfigFile, name: String, sample: bool = false) -> Error:
	cfg.clear()
	migrate(legacy_project_path(name), project_path(name))
	var path := resolve_project(name, sample)
	return ERR_FILE_NOT_FOUND if path.is_empty() else cfg.load(path)

static func user_path(name: String) -> String:
	var path := "user://config/" + name
	migrate("user://" + name, path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://config"))
	return path

static func load_user(cfg: ConfigFile, name: String) -> Error:
	cfg.clear()
	var path := user_path(name)
	return cfg.load(path if FileAccess.file_exists(path) else "user://" + name)
