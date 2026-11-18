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
func fixture(mode: int, count: int = 4, laps: int = 10):
	var game := Race.new(); root.add_child(game)
	game.race_mode = mode; game.rider_count = count; game.race_laps = 6 if mode == 2 else laps
	game._configure_peloton(); game.running = true; game.start_state = "RACING"
	game.clock = 100.; game.finished = true
	game.finish_times[0] = 99.; game.distances[0] = 500. if mode == 2 else game._race_length()
	for i in range(1,count): game.distances[i] = game._race_length()-240.+i*.2; game.speeds[i] = 12.
	if mode in [1,8]:
		var jury = game.points_rules if mode == 1 else game.tempo_rules
		var interval := 10 if mode == 1 else 1
		var first := 10 if mode == 1 else 5
		var ordering: Array = []
		for i in range(count): ordering.append(i)
		for lap in range(first, game.race_laps, interval):
			var awards: Array = []; var times: Array = []
			for i in range(count):
				var award: int = ([5,3,2,1][i] if i < 4 else 0) if mode == 1 else (1 if i == 0 else 0)
				awards.append(award); times.append(float(lap))
				jury.points[i] += award
			jury.sprints.append({"lap":lap,"seconds":float(lap),"order":ordering.duplicate(),"times":times,"awards":awards})
		var final_award := 10 if mode == 1 else 1
		jury.points[0] += final_award
		jury.sprints.append({"lap":game.race_laps,"seconds":99.0,"order":[0],"times":[99.0],"awards":[final_award]})
		jury.finish_clock = 99.0; jury.last_sprint_clock = 99.0
		for i in range(1,count): jury.credits[i] = -1
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
	for scenario in [[0,4,10],[1,4,10],[2,4,6],[8,4,20],[1,24,40],[1,24,80],[1,24,100],[8,24,40]]:
		var mode: int = scenario[0]
		var game = fixture(mode, int(scenario[1]), int(scenario[2]))
		game.finish_overlay.hide(); game._refresh_fullscreen_results()
		check(not game.results_completion.active,"No acceleration before results appear")
		game.finish_overlay.show();game._refresh_fullscreen_results()
		check(game.results_completion.active,"Visible results start acceleration automatically")
		var distance: float = game.distances[0]; var time: float = game.finish_times[0]
		var player_points: int = game.points_rules.points[0] if mode == 1 else (game.tempo_rules.points[0] if mode == 8 else 0)
		for i in range(5000):
			await process_frame
			if not game.results_completion.active: break
		check(game._all_riders_finished(),"Remaining actual AI riders finish automatically")
		check(game.distances[0] == distance and game.finish_times[0] == time,"Player result stays frozen")
		if mode in [1,8]:
			var jury = game.points_rules if mode == 1 else game.tempo_rules
			check(jury.complete(), "Final sprint contains all riders")
			check(jury.points[0] == player_points, "Already awarded player points remain unchanged")
			check(jury.sprints.size() == (game.race_laps / 10 if mode == 1 else game.race_laps - 4), "Sprint calendar stays unchanged")
		print("COMPLETED mode=%d riders=%d laps=%d" % [mode,game.rider_count,game.race_laps])
		var clock: float = game.clock; game._refresh_fullscreen_results();await process_frame
		check(game.clock == clock,"Repeated result refresh never restarts completed simulation")
		game.free()
	var game = fixture(0); game._refresh_fullscreen_results();game.results_completion.cancel();game.start_state = "SETUP"
	await process_frame;await process_frame
	check(game.clock == 100.,"Restart/navigation invalidates scheduled work")
	game.free()
	print("RESULTS_COMPLETION failures=",failures)
	quit(0 if failures == 0 else 1)
