extends SceneTree
class Game extends "res://main.gd":
	var quit_requested := false
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _quit_application() -> void: quit_requested = true
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func escape(game) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
func run_test() -> void:
	var game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var ui = game.exit_menu
	check(ui.exit_button.visible, "Exit visible in gallery")
	for page in [2, 3, 4, 5]:
		game.setup_panel.page = page
		check(ui.exit_button.is_visible_in_tree(), "Exit available throughout menu pages")
	game.get_node("GameSettings").panel_root.show()
	check(ui.exit_button.is_visible_in_tree() and ui.layer > 30, "Exit above settings and rider picker layers")
	game.get_node("GameSettings").panel_root.hide()
	ui.exit_button.pressed.emit()
	check(ui.quitting_application and not game.quit_requested, "Exit opens confirmation before application cleanup")
	escape(game)
	check(not ui.quitting_application and not game.quit_requested, "Escape cancels application exit")
	ui.exit_button.pressed.emit()
	ui.leave_button.pressed.emit()
	check(game.quit_requested, "Confirmed exit routes through application cleanup")
	# The test double records cleanup instead of terminating the process.
	ui.hide_pause()
	game.quit_requested = false
	game.setup_panel.cards[0].pressed.emit()
	game.setup_panel.start_button.pressed.emit()
	game.setup_panel.startlist_page.start_button.pressed.emit()
	game.broadcast_intro.finish()
	game._physics_process(0.01)
	check(not ui.exit_button.visible, "Exit hidden from start staging")
	for state in ["WAIT_STOP", "COUNTDOWN", "NEUTRAL", "RUN_UP", "RACING"]:
		game.start_state = state
		game.running = state in ["NEUTRAL", "RUN_UP", "RACING"]
		game.clock = 12.0
		game.countdown = 2.0
		var neutral_time: float = game.neutral_start.elapsed
		var run_up_time: float = game.flying_start.elapsed
		var distance: float = game.distances[0]
		var lane: int = game.player_lane
		escape(game)
		check(game.race_paused and ui.backdrop.visible, "Escape pauses " + state)
		game._physics_process(0.5)
		game._steer_player(1)
		game._process_steering(100)
		game._process_bridge_packet({"type":"button", "button":"LEFT", "source_button":"SHIFT_UP_LEFT"})
		check(game.start_state == state and game.race_paused, "Controller cannot reset paused event")
		check(game.clock == 12.0 and game.countdown == 2.0 and game.distances[0] == distance, "Race and countdown frozen")
		check(game.neutral_start.elapsed == neutral_time and game.flying_start.elapsed == run_up_time, "Opening-lap clocks remain frozen while paused")
		check(game.player_lane == lane, "Keyboard and trainer steering blocked while paused")
		ui.leave_button.pressed.emit()
		check(ui.confirming_leave and game.race_paused, "Leaving requires confirmation")
		escape(game)
		check(not ui.confirming_leave and game.race_paused, "Escape cancels leave confirmation")
		escape(game)
		check(not game.race_paused and not ui.backdrop.visible and game.start_state == state, "Escape resumes same state")
	# Exercise real trainer release and delayed resume without external hardware.
	game.trainer_control._open()
	game.trainer_control.enabled_before = true
	game.trainer_control.owned = true
	game.trainer_control.phase = "ACTIVE"
	game._pause_race()
	check(game.trainer_control.phase == "RELEASING", "Pause releases owned trainer")
	check(game.trainer_control.pending.packet.command == "set_target_power" and game.trainer_control.pending.packet.watts == 0, "Pause sends reset rather than ERG resistance")
	ui.resume_button.pressed.emit()
	game._update_trainer_control()
	check(game.trainer_pause_resume and not game.trainer_control.armed, "Resume waits for pending release")
	game.trainer_control.phase = "IDLE"
	game.trainer_control.pending = {}
	game._update_trainer_control()
	check(not game.trainer_pause_resume, "Resume completes after release")
	game.trainer_control.owned = false
	game.trainer_control.enabled_before = true
	game.trainer_control.pending = {"packet": {"command": "set_target_power", "watts": 250}}
	game._pause_race()
	check(game.trainer_control.pending.packet.watts == 0, "Pause also releases an ERG acquisition awaiting acknowledgement")
	ui.leave_button.pressed.emit()
	ui.leave_button.pressed.emit()
	check(game.start_state == "SETUP" and not game.race_paused and game.setup_panel.page == 1, "Confirmed leave returns to gallery")
	check(ui.exit_button.visible and not ui.backdrop.visible, "Exit restored after leave")
	game.finished = true
	game.start_state = "RACING"
	game._physics_process(0.01)
	check(ui.exit_button.visible, "Exit available after finish")
	check(not game.quit_requested, "Escape never quits active race")
	game.free()
	print("EXIT_PAUSE_OK failures=%d" % failures)
	quit(0 if failures == 0 else 1)
