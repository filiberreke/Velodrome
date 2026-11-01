extends SceneTree
const Catalog := preload("res://rider_catalog.gd")
const Paths := preload("res://config_paths.gd")
const AI := preload("res://x_scratch_ai.gd")
const Points := preload("res://points_ai.gd")
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_test() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://config/riders_config.example.cfg") == OK, "Sample loads from config folder")
	var seen := {}
	for index in range(1,14):
		var entry := Catalog.entry(cfg,index,1+(index-1)%3)
		check(not seen.has(entry.id), "Every sample rider has a unique persistent ID")
		seen[entry.id] = true
		check(entry.cp_factor == 1.0 and entry.max_power_factor == 1.0 and entry.w_prime_factor == 1.0, "All supplied sample factors are neutral")
		check(entry.cp_w == Catalog.CP[entry.profile] and entry.max_power_w == Catalog.PMAX[entry.profile] and entry.w_prime_j == Catalog.WPRIME[entry.profile], "Sample retains exact archetype physiology")
	check(Catalog.entry(cfg,1,1).name == "Filippa Ganno" and Catalog.entry(cfg,13,2).name == "Ella Andress", "Sample preserves supplied rider names")
	cfg.set_value("rider_01","cp_factor",1.04)
	cfg.set_value("rider_01","max_power_factor",0.96)
	cfg.set_value("rider_01","w_prime_factor",1.02)
	cfg.set_value("rider_01","hip_width",0.4)
	var modified := Catalog.entry(cfg,1,1)
	check(is_equal_approx(modified.cp_w,265.0*1.04) and modified.morphs.HipWidth == 0.4, "Factors and body fields are independent")
	var ai := AI.new()
	var profiles: Array[int] = [0,1,2,3]
	var forms: Array[float] = [1.,.975,1.025,1.]
	var lanes: Array[float] = [1.18,1.18,1.18,1.18]
	ai.reset(profiles,forms,lanes)
	var entries: Array[Dictionary] = [{},Catalog.entry(ConfigFile.new(),1,1),Catalog.entry(ConfigFile.new(),2,2),Catalog.entry(ConfigFile.new(),3,3)]
	var before := [ai.cp.duplicate(),ai.wmax.duplicate(),ai.pmax.duplicate(),ai.aggression.duplicate(),ai.cooperation.duplicate(),ai.rng.state]
	ai.configure_riders(entries,forms)
	check(before == [ai.cp,ai.wmax,ai.pmax,ai.aggression,ai.cooperation,ai.rng.state], "Neutral identities preserve exact reset values, character and RNG state")
	check(ai.cp[1] == 265.0*.975 and ai.cp[2] == 240.0*1.025, "Scratch now uses the approved points CP bases")
	entries[1] = modified
	ai.configure_riders(entries,forms)
	check(is_equal_approx(ai.cp[1],265*.975*1.04) and is_equal_approx(ai.pmax[1],856.79*.975*.96), "Configured factors enter the existing physiology")
	var points := Points.new()
	points.reset(profiles,forms,lanes)
	points.configure_riders(entries,forms)
	check(points.cp == ai.cp and points.wmax == ai.wmax and points.pmax == ai.pmax, "Points and scratch share physiological identity without replacing tactics")
	# Migrate disposable config files in the isolated Godot user directory.
	var old := "user://test_profile_migration.cfg"
	var target := "user://config/test_profile_migration.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	var file := FileAccess.open(old,FileAccess.WRITE)
	file.store_string("[test]\nvalue=123\n");file.close()
	check(Paths.user_path("test_profile_migration.cfg") == target and FileAccess.file_exists(target) and not FileAccess.file_exists(old), "Legacy user settings move into config")
	file = FileAccess.open(old,FileAccess.WRITE);file.store_string("do not overwrite");file.close()
	Paths.user_path("test_profile_migration.cfg")
	check(FileAccess.get_file_as_string(target).contains("123") and FileAccess.file_exists(old), "Migration preserves existing destination and original on conflict")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old));DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	var records = preload("res://rider_records.gd").new()
	records.path = "user://records/test_ai_profiles.json"
	records.data.clear()
	records.record("ganno",4,1000,80,70,900,1.02)
	records.record("ganno",4,1000,80,72,850,.99)
	records.record("ganno",4,1000,100,65,1000,1.0)
	check(records.personal("ganno").size() == 2 and records.personal("ganno")["4_1000_80"].time_s == 70, "Personal records persist by identity, discipline, distance and percentage")
	check(JSON.parse_string(FileAccess.get_file_as_string(records.path)).ganno.size() == 2, "AI records survive on disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(records.path))
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	for form in game.rider_forms: check(form >= .975 and form <= 1.025, "Mass race day form stays in the agreed narrow range")
	check(game.rider_names[1] == "Filippa Ganno" and game.rider_identities[1].id == "rider_01", "Actual game loads sample identity")
	game.setup_panel.select_mode(1)
	var options = game.setup_panel.pursuit_options
	check(options.cp_input.value == 265 and options.selected_ai().id == "rider_01", "Pursuit selection initializes the selected rider's base CP")
	options.open_picker()
	await process_frame
	var overlays := root.get_children()
	var picker = overlays[-1].get_child(0)
	check(picker.cards.size() == options.ai_entries.size(), "Passport grid contains every available rider")
	check(picker.count_label.text == "%d renners" % options.ai_entries.size(), "Empty search shows the complete roster")
	picker.search.text = "Ella Andress"
	picker.apply_filter()
	check(picker.count_label.text == "1 renner", "Passport search filters the real roster")
	var chosen: Dictionary = options.ai_entries[12]
	picker.selected.emit(chosen)
	check(options.selected_ai().name == "Ella Andress" and options.cp_input.value == 240, "Passport selection updates actual opponent and absolute watts")
	picker.layer.free()
	game.race_mode = 4
	game.pursuit_opponent_config = chosen
	game._configure_peloton()
	game._prepare_pursuit({},240)
	check(game.rider_names[1] == "Ella Andress" and game.pursuit_pacer.wprime_j == chosen.w_prime_j and game.pursuit_pacer.max_power_w == chosen.max_power_w, "Pursuit uses identity name, reserve and peak")
	game.broadcast_intro.start()
	game.broadcast_intro.advance(9.0)
	check(game.broadcast_intro.opponent_card.passport.entry.id == chosen.id and game.broadcast_intro.opponent_card.visible, "Pursuit intro shows the same real passport as the picker")
	game.broadcast_intro.finish()
	check(not game.broadcast_intro.overlay.visible and game.start_state == "WAIT_STOP", "Intro passport respects the existing start gate")
	game.free()
	print("RIDER_PROFILES failures=",failures)
	quit(0 if failures == 0 else 1)
