extends SceneTree
const Store := preload("res://performance_records.gd")
const Replays := preload("res://pursuit_records.gd")
class Model extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
class IsolatedStore extends "res://performance_records.gd":
	func import_saved(_libraries: Array = []) -> void: pass
var failures := 0
var folder: String

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	folder = "res://tests/tmp_records_%d" % Time.get_ticks_usec()
	call_deferred("run_test")

func entry(id: String, seconds: float, mode: int = 4, distance: int = 1000, team: int = 0) -> Dictionary:
	return {"id": id, "seconds": seconds, "mode": mode, "distance_m": distance, "team_size": team, "player_name": "Speler " + id, "finished_at": 1700000000.0 + seconds, "finished_local": "2026-10-23 18:12:34", "legacy": false}

func replay_samples(distance: int, seconds: float) -> Array[Dictionary]:
	return [{"t": 0.0, "d": 0.0, "p": 0.0, "lane": 1.18}, {"t": seconds, "d": distance, "p": 300.0, "lane": 1.18}]

func auto_finish(mode: int) -> void:
	var game = Model.new(); root.add_child(game)
	game.performance_records.path = folder.path_join("auto_%d.json" % mode)
	game.player_display_name = "Recordrenner"
	game.race_mode = mode; game.race_laps = 4; game.team_size = 3
	game._configure_peloton(); game._prepare_pursuit({}, 250.0)
	if mode == 5: game.team_race.prepare(game, {}, 250.0)
	game._register_performance()
	check(game.performance_records.top(mode, 1000, 3 if mode == 5 else 0).is_empty(), "Unfinished rides never become records")
	game.start_state = "RACING"; game.running = true; game.watts = 400.0
	while not game._all_riders_finished() and game.clock < 1000.0:
		game.clock += 0.1; game._update_race(0.1)
	var rows: Array[Dictionary] = game.performance_records.top(mode, 1000, 3 if mode == 5 else 0)
	check(game.performance_recorded and rows.size() == 1, "Finish automatically records without manual replay save")
	check(rows[0]["player_name"] == "Recordrenner" and absf(float(rows[0]["seconds"]) - game.finish_times[0]) < 0.000001, "Stored player name and exact finish time")
	check(not str(rows[0]["finished_local"]).is_empty() and float(rows[0]["finished_at"]) > 0.0, "Finish date/time captured")
	game.player_display_name = "Andere naam"; game._register_performance()
	rows = game.performance_records.top(mode, 1000, 3 if mode == 5 else 0)
	check(rows.size() == 1 and rows[0]["player_name"] == "Recordrenner", "Repeated finish refresh does not duplicate or rename record")
	var library := Replays.new()
	if mode == 5: library.configure_team(3)
	library.directory = folder.path_join("saved_%d" % mode)
	var metadata: Dictionary = game.performance_context.duplicate(true)
	metadata["performance_id"] = metadata["id"]
	var saved: Dictionary = library.save("Naam van rit", 1000, game.finish_times[0], game.pursuit_trace, metadata)
	check(not saved.has("error"), "Optional replay save accepts record metadata")
	game.performance_records.import_saved([library])
	check(game.performance_records.top(mode, 1000, 3 if mode == 5 else 0).size() == 1, "Optional replay does not duplicate automatic result")
	game.free()

func run_test() -> void:
	var store := Store.new(); store.path = folder.path_join("records.json")
	for mode in [4, 5]:
		for size in ([0] if mode == 4 else [3, 4]):
			for distance in [1000, 4000]:
				for n in range(11, -1, -1):
					check(store.add(entry("%d_%d_%d_%d" % [mode, size, distance, n], 100.0 + n, mode, distance, size)), "Repeated atomic record writes")
				var top: Array[Dictionary] = store.top(mode, distance, size)
				check(top.size() == 10 and float(top[0]["seconds"]) == 100.0 and float(top[-1]["seconds"]) == 109.0, "Separate Top 10 per mode, distance and squad size")
	var restarted := Store.new(); restarted.path = store.path
	check(restarted.top(5, 4000, 4).size() == 10, "Records survive reload and JSON numeric conversion")
	var tie_new: Dictionary = entry("tie_new", 80.0); tie_new["finished_at"] = 1700000200.0
	var tie_old: Dictionary = entry("tie_old", 80.0); tie_old["finished_at"] = 1700000100.0
	store.add(tie_new); store.add(tie_old)
	check(store.top(4, 1000)[0]["id"] == "tie_old", "Exact equal times use earlier performance date")
	var first: Dictionary = store.top(4, 1000)[0]
	var before: String = FileAccess.get_file_as_string(store.path)
	check(store.add(first) and FileAccess.get_file_as_string(store.path) == before, "Duplicate id is idempotent")
	var invalid: Dictionary = first.duplicate(); invalid["seconds"] = NAN
	check(not store.add(invalid), "Non-finite times rejected")
	invalid["seconds"] = -1.0; check(not store.add(invalid), "Negative times rejected")
	var legacy := Replays.new(); legacy.directory = folder.path_join("legacy")
	legacy.save("Dit is een ritnaam", 4000, 90.0, replay_samples(4000, 90.0))
	store.import_saved([legacy])
	var imported: Dictionary = store.top(4, 4000)[0]
	check(imported["player_name"] == "Onbekende speler" and bool(imported["legacy"]) and str(imported["finished_local"]).ends_with(" UTC"), "Legacy ride title never invented as player name; old storage date explicit UTC")
	before = FileAccess.get_file_as_string(store.path); store.import_saved([legacy])
	check(FileAccess.get_file_as_string(store.path) == before, "Legacy import idempotent")
	var broken := Store.new(); broken.path = folder.path_join("broken.json")
	broken.add(entry("one", 80.0)); broken.add(entry("two", 81.0))
	var file := FileAccess.open(broken.path, FileAccess.WRITE); file.store_string("broken"); file.close()
	check(broken.top(4, 1000).size() == 1, "Corrupt primary can recover last backup")
	file = FileAccess.open(broken.path + ".bak", FileAccess.WRITE); file.store_string("also broken"); file.close()
	check(not broken.add(entry("three", 82.0)) and FileAccess.get_file_as_string(broken.path) == "broken", "Unreadable records not silently overwritten")
	auto_finish(4); auto_finish(5)
	var game = load("res://main.gd").new()
	game.performance_records = IsolatedStore.new(); game.performance_records.path = store.path
	root.add_child(game); game.set_physics_process(false)
	await process_frame; await process_frame
	var menu = game.setup_panel
	check(menu.cards.size() == 8 and menu.cards[7].name == "records", "Separate final Records tile")
	check(menu.cards[2].find_child("Status", true, false).text == "SPEEL", "Team pursuit status updated on home page")
	for card in menu.cards:
		var rect: Rect2 = card.get_global_rect()
		check(rect.end.x <= 1920.1 and rect.end.y <= 1080.1, "All eight tiles stay within screen")
	menu.cards[7].pressed.emit(); await process_frame; await process_frame
	check(menu.page == 3 and menu.records_page.visible and not menu.settings_page.visible, "Records tile opens separate page")
	check(menu.records_page.shown.size() == 10 and menu.records_page.rows.get_child_count() == 10, "Top 10 entries rendered")
	var page = menu.records_page
	page.mode_choice.select(1); page.mode_choice.item_selected.emit(1)
	page.distance_choice.select(1); page.distance_choice.item_selected.emit(1)
	page.size_choice.select(1); page.size_choice.item_selected.emit(1)
	check(page.size_box.visible and page.shown.size() == 10 and int(page.shown[0]["team_size"]) == 4, "UI filters select four-person 4 km records")
	check(page.back_button.get_global_rect().end.y <= 1080.1, "Records navigation fits viewport")
	page.back_button.pressed.emit()
	check(menu.page == 1 and not page.visible, "Back returns to mode gallery")
	menu.cards[7].pressed.emit()
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	menu._unhandled_key_input(escape)
	check(menu.page == 1, "Escape returns from Records")
	game.free()
	_cleanup(folder)
	print("PERSONAL_RECORDS_OK" if failures == 0 else "PERSONAL_RECORDS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

func _cleanup(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for child in dir.get_directories(): _cleanup(directory.path_join(child))
	for child in dir.get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(child)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
