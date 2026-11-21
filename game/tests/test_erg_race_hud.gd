extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var menu = preload("res://race_menu.gd").new()
	root.add_child(menu)
	menu.set_process(false)
	var page = menu.workout_play_page
	page.set_process(false)
	var blocks := [
		{"kind":"SteadyState","duration":60.0,"power_low":0.75,"power_high":0.75,"events":[]},
		{"kind":"FreeRide","duration":30.0,"power_low":0.0,"power_high":0.0,"events":[]},
		{"kind":"Warmup","duration":60.0,"power_low":0.5,"power_high":1.2,"events":[]}
	]
	page.load_workout({"id":"hud_test","name":"HUD test","blocks":blocks})
	menu._show_section(14,"Workout",page)
	page.receive({"type":"telemetry","valid":true,"power_sample_id":0,"power_age_s":0.0,"power_w":180.0,"heart_rate_bpm":140.0,"cadence_rpm":90.0,"gear":6,"speed_kmh":35.0},page.now_s())
	page.begin()
	check(page.test.running() and menu.ftp_ramp_hud.visible and menu.session_panel.position.x < 0,"Workout starts in race HUD with controller offscreen")
	var hud = menu.ftp_ramp_hud
	for i in range(41):
		page.test.elapsed = float(i)
		page._record_ramp_sample(page.now_s(),180.0 if i < 20 else 240.0)
	hud.update_workout(page)
	check(not hud.ftp_panel.visible and not hud.step_panel.visible,"Workout hides FTP and ramp-only statistics")
	check(hud.power_meter.target_visible and hud.power_meter.target == 150.0,"Workout supplies current ERG target to race meter")
	check(hud.ramp_dial.current_w == 150 and hud.ramp_dial.next_w == 0 and hud.ramp_dial.seconds_left == 20,"Countdown tracks actual block and upcoming free ride")
	check(hud.profile_graph.samples.size() == 41 and hud.profile_graph.workout_duration == 150,"Workout telemetry and full target profile reach graph")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://erg_hud.png")
	page.test.elapsed = 70.0
	hud.update_workout(page)
	check(hud.ramp_dial.current_w == 0 and not hud.power_meter.target_visible,"FreeRide hides ERG arrow and shows free countdown")
	page.test.elapsed = 100.0
	hud.update_workout(page)
	check(hud.ramp_dial.last_block and hud.ramp_dial.block_duration == 60,"Final ramp block uses its own countdown duration")
	for i in range(41):
		page.activity_samples.append({"time_s":float(i),"distance_m":i*8.0,"power_w":180.0 if i < 20 else 240.0,"heart_rate_bpm":140.0+i/2.0,"cadence_rpm":90.0,"game_speed_kmh":35.0})
	page.test.advance(100.0)
	page.finish(page.test.reason)
	check(not hud.visible and menu.menu_margin.visible and page.get_parent() == menu.menu_layout,"Completion restores workout menu")
	check(page.selected_activity.get("kind") == "erg_workout","Completion retains activity archive")
	var archive := preload("res://training_store.gd").new()
	var stored := archive.load_activity(page.selected_activity.id)
	check(stored.get("samples",[]).size() == 41,"Workout can be read back from history storage")
	menu.show_erg_history()
	menu.erg_history_page._show_activity(stored)
	check(menu.erg_history_page.detail_graph.samples.size() == 41,"History opens stored samples")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://erg_history.png")
	menu._show_section(14,"Workout",page)
	page.receive({"type":"telemetry","valid":true,"power_sample_id":1,"power_age_s":0.0,"power_w":180.0},page.now_s())
	page.trainer.close()
	page.begin()
	hud.update_workout(page)
	hud.stop_test.pressed.emit()
	check(not page.test.running() and not hud.visible and menu.menu_margin.visible,"HUD stop button ends workout and restores menu")
	var ftp = menu.ftp_page
	ftp.set_process(false)
	ftp.test.start(ftp.session_now(ftp.now_s()))
	hud.update_ftp(ftp)
	check(hud.ftp_panel.visible and hud.step_panel.visible,"Ramp FTP panel restores after an ERG session")
	ftp.test.stop("Test")
	ftp.select_test(true)
	ftp.twenty_warmup = true
	hud.update_ftp(ftp)
	check(hud.ftp_panel.visible and not hud.step_panel.visible and hud.profile_graph.twenty_mode,"Twenty minute warmup keeps FTP HUD and constant target graph")
	ftp.twenty_warmup = false
	menu.free()
	print("ERG_RACE_HUD failures=",failures)
	quit(0 if failures == 0 else 1)
