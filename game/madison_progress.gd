extends RefCounted
## Persist only completed session results; an interrupted test never unlocks Advanced.
const Paths := preload("res://config_paths.gd")
var path := ""
var advanced_unlocked := false
var target := 10
var attempts := 0
var successes := 0
var last_attempts := 0
var last_successes := 0
var save_error: Error = OK

func _init(settings_path: String = "") -> void:
	path = settings_path

func load_progress() -> void:
	advanced_unlocked = false
	last_attempts = 0; last_successes = 0
	var cfg := ConfigFile.new()
	var error: Error = Paths.load_user(cfg, "madison_progress.cfg") if path.is_empty() else cfg.load(path)
	if error != OK: return
	advanced_unlocked = cfg.get_value("progress", "advanced_unlocked", false) == true
	last_attempts = int(cfg.get_value("progress", "last_attempts", 0))
	last_successes = int(cfg.get_value("progress", "last_successes", 0))

func reset_session(count: int) -> void:
	target = 20 if count == 20 else 10
	attempts = 0; successes = 0; save_error = OK

func record(success: bool, easy: bool) -> void:
	if complete(): return
	attempts += 1
	if success: successes += 1
	if not complete() or not easy: return
	last_attempts = attempts; last_successes = successes
	var unlocked: bool = advanced_unlocked or passed()
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "advanced_unlocked", unlocked)
	cfg.set_value("progress", "last_attempts", attempts)
	cfg.set_value("progress", "last_successes", successes)
	save_error = cfg.save(Paths.user_path("madison_progress.cfg") if path.is_empty() else path)
	if save_error == OK: advanced_unlocked = unlocked

func complete() -> bool:
	return attempts >= target

func passed() -> bool:
	return complete() and successes * 10 >= target * 7

func summary() -> String:
	return "%d/%d · %d geslaagd" % [attempts, target, successes]
