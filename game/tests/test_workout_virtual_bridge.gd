extends SceneTree
class Game extends "res://main.gd":
	var test_port := 0
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(test_port)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	var game := Game.new()
	game.test_port = int(args[0])
	root.add_child(game)
	game.set_physics_process(false)
	var menu = game.setup_panel
	var page = menu.workout_play_page
	page.trainer.port = int(args[1])
	menu.ftp_page.trainer.port = int(args[1])
	for i in range(150):
		await create_timer(.02).timeout
		game._read_bridge()
		if page.fresh(game._now_s()) and menu.ftp_page.release_complete(): break
	check(page.fresh(game._now_s()) and game.trainer_virtual,"Actual simulator telemetry reaches custom workouts")
	var blocks := [{"kind":"SteadyState","duration":1,"power_low":0.5,"power_high":0.5,"events":[]},{"kind":"FreeRide","duration":1,"power_low":0,"power_high":0,"events":[]},{"kind":"Warmup","duration":2,"power_low":0.5,"power_high":0.7,"events":[]}]
	page.load_workout({"id":"integration","name":"Bridge workout","blocks":blocks})
	menu._show_section(14,"Workout",page)
	page.ftp_input.value = 240
	page.begin()
	check(page.test.running() and game.training_environment != null and game.training_environment.active,"Start opens the training venue with the chosen FTP")
	var saw_erg := false
	var saw_free := false
	var saw_resume := false
	for i in range(650):
		await create_timer(.02).timeout
		game._read_bridge()
		if page.test.phase == "ERG":
			saw_erg = true
			if saw_free: saw_resume = true
		if page.test.phase == "FREE": saw_free = true
		if not page.test.running() and page.release_complete(): break
	print("WORKOUT_FINAL ",page.test.phase," ",page.test.reason," ",page.trainer.state)
	check(saw_erg and saw_free and saw_resume,"Actual UDP trainer confirms ERG, releases for FreeRide, then reacquires ramp control")
	check(page.test.phase == "RESULT" and page.test.reason == "Workout voltooid" and page.release_complete(),"Workout completes and actual bridge confirms release")
	check(not game.training_environment.active and menu.menu_margin.visible,"Result returns from piste to workout page")
	page.load_workout({"id":"pause","name":"ERG pause recovery","blocks":[{"kind":"SteadyState","duration":120,"power_low":.7,"power_high":.7,"events":[]}]})
	menu._show_section(14,"Workout",page); page.begin()
	for i in range(150):
		await create_timer(.02).timeout; game._read_bridge()
		if page.test.phase == "ERG" and page.trainer.owned: break
	print("VIRTUAL_BRIDGE_DROP")
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec() < deadline:
		await create_timer(.02).timeout; game._read_bridge()
	var frozen: float = page.test.elapsed
	check(page.test.running() and page.signal_state.paused_since >= 0 and not page.trainer.owned,"Actual ERG UDP loss pauses rather than ending the workout")
	print("VIRTUAL_BRIDGE_RESTORE")
	for i in range(200):
		await create_timer(.02).timeout; game._read_bridge()
		if page.trainer.owned and page.test.elapsed > frozen+.1: break
	check(page.test.running() and page.trainer.owned and page.test.elapsed > frozen,"Actual ERG UDP recovery restores the previous workout target")
	page.finish("Integratietest voltooid")
	game.free()
	print("WORKOUT_VIRTUAL_BRIDGE failures=",failures)
	if failures == 0: print("VIRTUAL_BRIDGE_OK")
	quit(0 if failures == 0 else 1)
