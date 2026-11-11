extends SceneTree
const Progress := preload("res://madison_progress.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var path := "user://test_madison_progress.cfg"
	for example in [[10,6,false],[10,7,true],[20,13,false],[20,14,true]]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var model := Progress.new(path); model.load_progress(); model.reset_session(example[0])
		for i in range(example[0]):
			model.record(i < example[1],true)
			if i < example[0]-1: check(not model.advanced_unlocked,"No unlock before session completion")
		check(model.advanced_unlocked == example[2],"Exact 70% threshold")
		var saved := Progress.new(path); saved.load_progress()
		check(saved.advanced_unlocked == example[2] and saved.last_successes == example[1],"Unlock/result persisted")
		model.record(true,true); check(model.attempts == example[0],"Cannot count extra attempts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MADISON_PROGRESS_OK" if failures == 0 else "MADISON_PROGRESS_FAILED")
	quit(0 if failures == 0 else 1)
