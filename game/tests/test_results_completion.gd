extends SceneTree
class Race extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _record_ai_performances() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func fixture(mode: int):
	var game := Race.new(); root.add_child(game)
	game.race_mode = mode; game.rider_count = 4; game.race_laps = 6 if mode == 2 else 10
	game._configure_peloton(); game.running = true; game.start_state = "RACING"
	game.clock = 100.; game.finished = true
	game.finish_times[0] = 99.; game.distances[0] = 500. if mode == 2 else game._race_length()
	for i in range(1,4): game.distances[i] = game._race_length()-5.; game.speeds[i] = 12.
	if mode == 2:
		game.elimination_rules.active[0] = false
		game.elimination_rules.eliminated.assign([0])
		game.elimination_rules.next_line_m = 1000.
		for i in range(1,4): game.distances[i] = 995.+i*.2
		for i in range(4): game.elimination_rules.last_rear_m[i] = game.distances[i]-game.REAR_TRAILING_EDGE_M
		game.elimination_notice = Label.new(); game.add_child(game.elimination_notice)
	game.finish_overlay = ColorRect.new(); game.add_child(game.finish_overlay)
	return game
func run() -> void:
	for mode in [0,2]:
		var game = fixture(mode)
		game.finish_overlay.hide(); game._refresh_fullscreen_results()
		check(not game.results_completion.active,"No acceleration before results appear")
		game.finish_overlay.show();game._refresh_fullscreen_results()
		check(game.results_completion.active,"Visible results start acceleration automatically")
		var distance: float = game.distances[0]; var time: float = game.finish_times[0]
		for i in range(1000):
			await process_frame
			if not game.results_completion.active: break
		check(game._all_riders_finished(),"Remaining actual AI riders finish automatically")
		check(game.distances[0] == distance and game.finish_times[0] == time,"Player result stays frozen")
		var clock: float = game.clock; game._refresh_fullscreen_results();await process_frame
		check(game.clock == clock,"Repeated result refresh never restarts completed simulation")
		game.free()
	var game = fixture(0); game._refresh_fullscreen_results();game.results_completion.cancel();game.start_state = "SETUP"
	await process_frame;await process_frame
	check(game.clock == 100.,"Restart/navigation invalidates scheduled work")
	game.free()
	print("RESULTS_COMPLETION failures=",failures)
	quit(0 if failures == 0 else 1)
