extends SceneTree
const Library := preload("res://workout_library.gd")
const Menu := preload("res://race_menu.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	var intervals := [{"kind":"IntervalsT", "repeat":4, "on_duration":60, "off_duration":180, "on_power":1.2, "off_power":.4}]
	check(is_equal_approx(Library.average_target(intervals), .6), "Interval intensity weights recovery and effort by duration")
	check(is_equal_approx(Library.average_target([{"kind":"Warmup", "duration":600, "power_low":.4, "power_high":.8}]), .6), "Ramps use their mean target")
	check(Library.average_target([{"kind":"FreeRide", "duration":600}]) < 0, "Free riding has no invented FTP intensity")
	for sample in [[-.1, 0], [.54, 1], [.55, 2], [.7, 3], [.85, 4], [1.0, 5]]:
		check(Library.intensity_level(sample[0]) == sample[1], "Flame levels handle each intensity boundary")
	var menu := Menu.new()
	root.add_child(menu)
	menu.workout_library.folder = "user://menu_cleanup_filter_test"
	var fixtures := [
		["short", 1799, .69], ["medium", 1800, .7],
		["long", 3600, .9], ["longer", 3601, 1.0]
	]
	for entry in fixtures:
		menu.workout_library.save_workout(entry[0], entry[0], [{"kind":"SteadyState", "duration":entry[1], "power_low":entry[2]}])
	menu.workout_library.save_workout("free", "free", [{"kind":"FreeRide", "duration":1200}])
	menu.refresh_workout_tiles()
	menu.show_training()
	check(menu.fixed_workout_grid.get_child_count() == 3 and menu.fixed_workout_grid.get_child(1).disabled, "Three fixed top tiles include the unavailable 20-minute test")
	menu.custom_duration_filter.select(2)
	menu.apply_workout_filters()
	check(visible_tiles(menu) == 2, "Thirty and sixty minutes are both included in the middle duration band")
	menu.custom_intensity_filter.select(3)
	menu.apply_workout_filters()
	check(visible_tiles(menu) == 1, "Duration and flame-level filters intersect")
	menu.custom_duration_filter.select(3)
	menu.apply_workout_filters()
	check(visible_tiles(menu) == 0 and menu.custom_workout_empty.visible, "No matches provides a visible explanation")
	menu.custom_duration_filter.select(0)
	menu.custom_intensity_filter.select(6)
	menu.apply_workout_filters()
	check(visible_tiles(menu) == 1, "Free riding remains separately filterable")
	check(menu.ftp_tile.visible and menu.editor_tile.visible, "Custom filters leave fixed tests and editor visible")
	for entry in fixtures: menu.workout_library.delete_workout(entry[0])
	menu.workout_library.delete_workout("free")
	menu.free()
	print("WORKOUT_FILTERS failures=", failures)
	quit(0 if failures == 0 else 1)

func visible_tiles(menu: Control) -> int:
	var count := 0
	for tile in menu.saved_workout_tiles:
		if tile.visible: count += 1
	return count
