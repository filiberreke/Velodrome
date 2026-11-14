extends SceneTree
const Menu = preload("res://race_menu.gd")
const PREFS := "user://config/test_race_difficulty.cfg"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func make_menu():
	var menu = Menu.new()
	menu.difficulty_preferences_path = PREFS
	root.add_child(menu)
	return menu
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
	var menu = make_menu()
	for control in [menu.difficulty_slider, menu.keirin_derny, menu.pursuit_flow.strength_slider, menu.pursuit_flow.strength_input]:
		check(control.min_value == 40 and control.max_value == 120 and control.step == 5,"Every race selector has the same bounds and step")
	check(menu.difficulty_slider.value == 80 and menu.keirin_derny.value == 80,"Fresh peloton and derny defaults are 80%")
	menu.select_mode(1)
	menu.pursuit_flow.preferences_path = "user://config/test_race_difficulty_opponents.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.pursuit_flow.preferences_path))
	menu.pursuit_flow.begin(false)
	menu.pursuit_flow.select_kind(0)
	check(menu.pursuit_flow.strength_input.value == 80,"Fresh pursuit AI default is 80%")
	menu.pursuit_flow.select_kind(1)
	check(menu.pursuit_flow.strength_input.value == 80,"Fresh replay default is 80%")
	menu.difficulty_slider.value = 115
	menu.keirin_derny.value = 120
	menu.free()
	menu = make_menu()
	check(menu.difficulty_slider.value == 115 and menu.keirin_derny.value == 120,"Race and derny strengths survive menu recreation")
	menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://config/test_race_difficulty_opponents.cfg"))
	print("RACE_DIFFICULTY failures=",failures)
	quit(0 if failures == 0 else 1)
