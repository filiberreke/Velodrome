extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; push_error(text)
func _initialize() -> void:
	var store := preload("res://training_store.gd").new()
	store.folder = "user://test_training_store"
	var samples: Array[Dictionary] = [{"time_s":0,"distance_m":0,"game_speed_kmh":30,"power_w":150,"cadence_rpm":-1,"heart_rate_bpm":null},{"time_s":1,"distance_m":8.33,"game_speed_kmh":30,"power_w":155,"cadence_rpm":80,"heart_rate_bpm":130}]
	var item := {"version":1,"id":"test-activity","started_unix":1794220000,"samples":samples,"final":false}
	check(store.save(item),"Initial checkpoint saves")
	item.final = true
	check(store.save(item),"Atomic update replaces checkpoint")
	var loaded := store.load_activity("test-activity")
	check(loaded.get("final",false) and loaded.samples[0].heart_rate_bpm == null,"Reload preserves result and unavailable sensors")
	check(store.recent().size() == 1,"Archive lists saved activity")
	var fit := preload("res://training_store.gd").fit_payload(loaded)
	check(fit.size() > 14 and fit.slice(8,12).get_string_from_ascii() == ".FIT","Archive exports a valid FIT header")
	check(not store.save({"id":"../outside"}),"Archive rejects escaping filenames")
	check(preload("res://derny_session.gd").required_power(10,.60) < preload("res://derny_session.gd").required_power(10,0),"Target watts account for shelter")

	var watts := preload("res://derny_session.gd").required_power(10,.60)
	check(preload("res://derny_session.gd").next_speed(10,watts,0,.1) < 10,"Leaving shelter increases required power")
	check(is_equal_approx(preload("res://derny_session.gd").next_speed(10,watts,.60,.1),10),"Suggested watts hold speed in the force model")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.folder.path_join("test-activity.json")))
	print("TRAINING_STORE failures=",failures)
	quit(0 if failures==0 else 1)
