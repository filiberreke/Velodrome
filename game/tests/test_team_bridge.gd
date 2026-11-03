extends SceneTree
class Model extends "res://main.gd":
	var test_port := 0
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(test_port)
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func tick(game: Node3D, count: int, dt: float = 0.05) -> void:
	for i in range(count):
		game._physics_process(dt)
		await create_timer(0.02).timeout
func control_tick(game: Node3D) -> void:
	for i in range(60):
		game._read_bridge()
		game._update_trainer_control()
		game._update_hud()
		await create_timer(0.02).timeout
func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	var game := Model.new()
	game.test_port = int(args[0])
	game.trainer_control.port = int(args[1])
	root.add_child(game)
	game.set_physics_process(false)
	for i in range(100):
		game._read_bridge()
		if game.connected: break
		await create_timer(0.02).timeout
	game.setup_panel.select_mode(2)
	game.setup_panel.pursuit_flow.select_distance(1000)
	game.setup_panel.pursuit_flow.select_size(4)
	game.setup_panel.pursuit_flow.next_step()
	game.setup_panel.team_options.resistance_choice.select(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	await tick(game, 100)
	check(game.start_state == "RACING" and game.team_resistance_mode == "MANUAL", "Actual team menu starts manual race")
	check(game.trainer_control.phase == "ACTIVE" and game.trainer_control.state.get("mode") == "SIM", "Manual team acquires SIM")
	check(game.trainer_selected_gear == 4 and game.race_overlay.gear_label.text == "4", "Manual team displays actual simulator gear")
	print("TEAM_BRIDGE_POWER")
	await tick(game, 80)
	check(game.team_race.velocity[0] > 0.5, "Team is moving before exchange")
	print("TEAM_BRIDGE_SHIFT")
	await tick(game, 30)
	check(not game.team_race.ours.player_is_out() and game.team_race.ours.player_rank() == 0 and game.team_race.ours.exchanges == 0, "Actual simulator shift keeps player on the front")
	check(game.trainer_selected_gear == 5 and game.race_overlay.gear_label.text == "5", "Manual gear shift updates gear while continuing head turn")
	print("TEAM_BRIDGE_STEER")
	await tick(game, 30)
	check(game.team_race.ours.player_is_out(), "Separate right steering starts team exchange")
	for i in range(150):
		await tick(game, 1, 0.2)
		if not game.team_race.ours.player_is_out(): break
	check(game.team_race.ours.player_rank() > 0, "Player rejoins in following position")
	game.team_resistance_mode = "ERG"
	await control_tick(game)
	check(game.trainer_control.phase == "ACTIVE" and game.trainer_control.state.get("mode") == "ERG", "Following in ERG switches actual simulator")
	game.team_resistance_mode = "MANUAL"
	await control_tick(game)
	check(game.trainer_control.phase == "ACTIVE" and game.trainer_control.state.get("mode") == "SIM", "Returning to manual switches simulator to SIM")
	check(game.trainer_selected_gear == 5 and game.race_overlay.gear_label.text == "5", "Gear returns in manual after ERG")
	game.queue_free()
	await process_frame
	print("VIRTUAL_BRIDGE_OK" if failures == 0 else "TEAM_BRIDGE_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
