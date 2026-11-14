extends RefCounted
## Continue the same race physics in short CPU batches while results are visible.
const STEP := 1.0 / 60.0
const FRAME_BUDGET_US := 10000
var active := false
var started := false
var generation := 0

func cancel() -> void:
	generation += 1
	active = false
	started = false

func start(game: Node) -> void:
	if started or not game.finished or game.start_state != "RACING" or game.race_mode not in [0,1,2,3] or game._all_riders_finished(): return
	started = true
	active = true
	_run.call_deferred(game, generation)

func _run(game: Node, token: int) -> void:
	# Present the results before consuming CPU; keep input and rendering responsive.
	await game.get_tree().process_frame
	if token != generation or not is_instance_valid(game): return
	var deadline: float = game.clock + maxf(600.,game.race_laps*120.)
	while token == generation and is_instance_valid(game) and game.is_inside_tree() and game.start_state == "RACING" and game.finished and game.finish_overlay != null and game.finish_overlay.visible and not game._all_riders_finished() and game.clock < deadline:
		var frame_end := Time.get_ticks_usec() + FRAME_BUDGET_US
		while Time.get_ticks_usec() < frame_end and not game._all_riders_finished() and game.clock < deadline:
			game.clock += STEP
			game._update_race(STEP)
		game._refresh_fullscreen_results()
		await game.get_tree().process_frame
	if token != generation: return
	active = false
	if is_instance_valid(game) and game.is_inside_tree() and game.start_state == "RACING":
		game._record_ai_performances()
		game._refresh_fullscreen_results()
