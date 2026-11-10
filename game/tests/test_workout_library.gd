extends SceneTree
const Profile := preload("res://player_profile.gd")
const Library := preload("res://workout_library.gd")
const Run := preload("res://workout_run.gd")
class FakeTrainer extends "res://trainer_control.gd":
	var confirm := true
	func tick(enabled: bool,_grade: float,_aero: float,now: float,target: int = 0) -> void:
		last_response = now
		owned = enabled
		state = {"mode":"ERG" if enabled else "RELEASED","desired_mode":"ERG","confirmed_target_w":target if confirm else -1,"revision":2,"applied_revision":2,"release_confirmed":not enabled,"udp_owned":enabled}
		phase = "ACTIVE" if enabled else "IDLE"
class Page extends "res://workout_training.gd":
	var clock := 100.0
	func now_s() -> float: return clock
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func shot(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/derny-captures/"+filename+".png"))
func run_test() -> void:
	root.size = Vector2i(1920,1080)
	var profile := Profile.new()
	profile.path = "user://test_player_ftp.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.path))
	check(profile.ftp() == 200,"New players have a usable FTP default")
	var cfg := ConfigFile.new()
	cfg.set_value("rider","name","Ada")
	cfg.set_value("rider","weight_kg",68)
	cfg.save(profile.path)
	check(profile.set_ftp(260) == OK and profile.ftp() == 260,"Manual FTP survives reload")
	cfg.load(profile.path)
	check(cfg.get_value("rider","name") == "Ada" and cfg.get_value("rider","weight_kg") == 68,"Saving FTP preserves other rider settings")
	check(profile.set_ftp(NAN) != OK and profile.set_ftp(0) != OK and profile.ftp() == 260,"Invalid FTP cannot overwrite the profile")
	var menu := preload("res://race_menu.gd").new()
	menu.workout_library.folder = "user://test_workout_library"
	root.add_child(menu)
	await process_frame
	var editor = menu.workout_editor_page
	editor.name_edit.text = "Tempo"
	editor.save_workout()
	var first: String = editor.current_id
	editor.new_workout()
	editor.name_edit.text = "Intervals"
	editor.blocks.clear()
	editor.blocks.append(editor._new_block("IntervalsT"))
	editor.save_workout()
	var second: String = editor.current_id
	check(first != second and menu.saved_workout_tiles.size() == 2,"New workout adds a separate persistent tile")
	editor.load_workout(first)
	editor.name_edit.text = "Tempo aangepast"
	editor.save_workout()
	check(menu.workout_library.all_workouts().size() == 2 and editor.workout_choice.item_count == 3,"Editing replaces one custom workout; FTP test is excluded from dropdown")
	var reload := Library.new()
	reload.folder = menu.workout_library.folder
	check(reload.get_workout(first).name == "Tempo aangepast","Library survives a fresh instance")
	menu.workout_play_page.player_profile = profile
	menu.show_training()
	var tile_art = menu.saved_workout_tiles[0].get_child(0).get_child(0)
	check(tile_art.workout_blocks == reload.get_workout(second).blocks,"Tile receives its own saved workout, not placeholder artwork")
	var preview := preload("res://training_tile_art.gd").chart_sections([{"kind":"IntervalsT","repeat":2,"on_duration":40,"off_duration":20,"on_power":1.2,"off_power":.4}])
	check(preview.size() == 4 and preview[0].seconds == 40 and preview[1].seconds == 20 and preview[0].high == 1.2 and preview[1].low == .4,"Thumbnail expands real intervals with proportional time and FTP power")
	await shot("workout_library")
	menu.saved_workout_tiles[1].pressed.emit()
	await shot("workout_start")
	check(menu.page == 14 and menu.workout_play_page.start_button.visible and menu.workout_play_page.edit_button.visible,"Saved tile opens Start and Edit screen")
	check(menu.workout_play_page.ftp_input.value == 260,"Workout FTP defaults to the player profile")
	menu.workout_play_page.ftp_input.value = 220
	check(profile.ftp() == 260,"Workout override never changes the profile")
	menu.workout_play_page.edit_button.pressed.emit()
	check(menu.page == 10 and editor.current_id == first,"Edit opens the chosen workout")
	menu.show_workout(first)
	check(menu.workout_play_page.ftp_input.value == 260,"Reopening uses the latest profile default")
	var ftp_page = menu.ftp_page
	ftp_page.player_profile = profile
	ftp_page.test.phase = "RESULT"
	ftp_page.test.best_60 = 400
	ftp_page._refresh()
	check(profile.ftp() == 300,"Completed FTP test updates profile to 75 percent of best measured minute")
	profile.set_ftp(280)
	ftp_page._refresh()
	check(profile.ftp() == 280,"Repeated result redraw cannot overwrite a later manual FTP")
	menu.show_workout(first)
	check(menu.workout_play_page.ftp_input.value == 280,"New training sees FTP changed after a test")
	var page := Page.new()
	page.trainer = FakeTrainer.new()
	page.player_profile = profile
	root.add_child(page)
	page.set_process(false)
	var blocks := [{"kind":"Warmup","duration":2,"power_low":0.5,"power_high":1.0,"events":[]},{"kind":"FreeRide","duration":2,"power_low":0,"power_high":0,"events":[]},{"kind":"SteadyState","duration":2,"power_low":0.8,"power_high":0.8,"events":[]}]
	page.load_workout({"id":"test","name":"Transitions","blocks":blocks})
	page.ftp_input.value = 250
	page.telemetry_ok = true
	page.last_sample = page.clock
	page.begin()
	check(page.test.running() and page.test.ftp_w == 250 and page.test.target(0) == 125,"Start uses only this workout's FTP override")
	for i in range(6):
		page.clock += 1
		page.last_sample = page.clock
		page._process(1)
		if i == 0: check(page.test.target(0) == 188,"Ramp targets interpolate as a fraction of chosen FTP")
		if i == 2: check(page.test.phase == "FREE" and not page.trainer.owned,"FreeRide releases trainer")
		if i == 4: check(page.test.phase == "ERG" and page.trainer.owned,"ERG resumes after FreeRide confirmation")
	check(page.test.phase == "RESULT" and page.test.reason == "Workout voltooid" and not page.trainer.owned,"Finishing workout releases trainer")
	page.load_workout({"id":"test","name":"No proof","blocks":[blocks[2]]})
	page.trainer.confirm = false
	page.last_sample = page.clock
	page.begin()
	for i in range(10):
		page.clock += 1
		page.last_sample = page.clock
		page._process(1)
	check(page.test.elapsed == 0 and page.test.phase == "RESULT" and page.test.reason.contains("niet bevestigd"),"Unconfirmed hardware target cannot advance training and times out")
	page.free()
	for item in reload.all_workouts(): DirAccess.remove_absolute(ProjectSettings.globalize_path(reload._path(item.id)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.path))
	menu.free()
	print("WORKOUT_LIBRARY failures=",failures)
	quit(0 if failures == 0 else 1)
