extends RefCounted
var folder := "user://omnium"
var error := ""
func save_state(state: Dictionary) -> bool:
	error = ""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		error = String(TranslationServer.translate("OMNIUM_FOLDER_UNAVAILABLE")); return false
	var path := folder.path_join("state.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = String(TranslationServer.translate("OMNIUM_SAVE_FAILED")); return false
	file.store_string(JSON.stringify(state)); file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: error = String(TranslationServer.translate("OMNIUM_WRITE_FAILED")); return false
	# Keep the last complete snapshot for recovery from a damaged primary file.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) != OK:
			error = "Omniumreservekopie mislukt"; return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		error = String(TranslationServer.translate("OMNIUM_UPDATE_FAILED")); return false
	return true

func load_state() -> Dictionary:
	for suffix in ["", ".bak"]:
		var path := folder.path_join("state.json" + suffix)
		if not FileAccess.file_exists(path): continue
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary and value.get("version") == 1 and value.get("archive") is Array:
			return value
	return {"version":1, "active":{}, "archive":[]}
