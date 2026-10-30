extends SceneTree
const Game := preload("res://main.gd")

class TestGame extends "res://main.gd":
	var test_port := 0
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(test_port)

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	print("VIRTUAL_BRIDGE_START")
	var args := OS.get_cmdline_user_args()
	var game := TestGame.new()
	game.test_port = int(args[0])
	game.trainer_control.port = int(args[1])
	root.add_child(game)
	print("VIRTUAL_BRIDGE_WORLD_READY")
	game.set_physics_process(false)
	var menu = game.setup_panel
	menu.select_mode(0)
	for i in range(150):
		await create_timer(0.02).timeout
		game._read_bridge()
		if game.trainer_seen: break
	game._update_hud()
	check(game.trainer_seen and game.connected and game.trainer_ready, "Actual Python simulator detected in SETUP")
	check(menu.bridge_label.text.contains("LIVE") and not menu.demo_settings.visible, "Menu reflects received bridge instead of demo")
	check(game.watts == 0.0 and game.trainer_speed_kmh == 0.0 and game._final_start_speed_ok(), "Simulator startup permits standing start")
	# Invalid trainer telemetry and command failure must not gain automatic recovery.
	game.running = true
	game.start_state = "RACING"
	game.trainer_control.owned = true
	game._process_bridge_packet({"type": "telemetry", "valid": false})
	game._update_trainer_control()
	check(not game.trainer_telemetry_resume, "Live stream with invalid trainer data does not auto re-arm")
	game.trainer_telemetry_resume = true
	game.trainer_control.error = "control_busy"
	game._update_trainer_control()
	check(not game.trainer_telemetry_resume, "Another controller's error cancels automatic recovery")
	game.trainer_control.error = ""
	game.trainer_control.owned = false
	game.trainer_control.may_resume = false
	game._reset()
	for race in range(3):
		game._read_bridge()
		game._confirm_start()
		game.broadcast_intro.finish()
		check(game.start_state == "WAIT_STOP", "Explicit start enters standing-start flow")
		for tick in range(65):
			game._physics_process(0.1)
			await create_timer(0.02).timeout
		check(game.start_state == "RACING" and game.running and game.recording_active, "Race %d uses trainer path after countdown" % race)
		check(game.demo_fit_records.is_empty() and game.watts == 0.0, "No demo power or demo recording injected")
		for tick in range(40):
			game._physics_process(0.02)
			await create_timer(0.02).timeout
		check(game.trainer_control.phase == "ACTIVE", "Race %d completes simulator command handshake" % race)
		check(game.trainer_selected_gear == (4 if race == 0 else 5) and game.trainer_heart_rate_bpm == 140, "Gear and HR received")
		if race == 0:
			print("VIRTUAL_BRIDGE_DROP")
			var paused_clock := -1.0
			for tick in range(600):
				game._physics_process(0.02)
				await create_timer(0.02).timeout
				if tick == 550: paused_clock = game.clock
			check(game.clock == paused_clock, "Long dropout pauses race after the existing power-hold interval")
			check(not game.connected and not game.trainer_control.owned and not game.trainer_control.armed, "Telemetry loss releases control")
			check(game.trainer_telemetry_resume and game.trainer_control.may_resume, "Only our telemetry-loss release permits resume")
			print("VIRTUAL_BRIDGE_RESTORE")
			for tick in range(150):
				game._physics_process(0.02)
				await create_timer(0.02).timeout
				if game.trainer_control.phase == "ACTIVE" and game.trainer_selected_gear == 4: break
			check(game.connected and game.trainer_control.phase == "ACTIVE" and game.trainer_control.owned and game.trainer_control.armed, "Fresh telemetry re-probes and resumes own SIM session")
			check(game.start_state == "RACING" and game.trainer_selected_gear == 4, "Same race and gear restored after packet loss")
			print("VIRTUAL_BRIDGE_SHIFT")
			for tick in range(50):
				game._physics_process(0.02)
				await create_timer(0.02).timeout
				if game.trainer_selected_gear == 5 and game.player_lane == 1: break
			check(game.trainer_selected_gear == 5 and game.player_lane == 1, "Actual simulator shift and steering packet work after recovery")
		game._reset()
		for tick in range(25):
			game._physics_process(0.02)
			await create_timer(0.02).timeout
		check(game.trainer_seen and game.connected, "Race reset retains bridge detection")
	# Reproduce a second instance trying to use the same telemetry port.
	var second := Game.new()
	second.start_state = "SETUP"
	check(second._bind_bridge(game.udp.get_local_port()) != OK, "Occupied telemetry port detected")
	second.setup_panel = menu
	second._update_hud()
	check(menu.bridge_label.text.contains("51723 bezet") and menu.start_button.disabled and not menu.demo_settings.visible, "Port conflict displayed; no silent demo start")
	second._confirm_start()
	check(second.start_state == "SETUP" and not second._start_conditions_met(), "Port conflict cannot enter race via start action or countdown")
	second.setup_panel = null
	second.free()
	game.queue_free()
	await process_frame
	print("VIRTUAL_BRIDGE_OK" if failures == 0 else "VIRTUAL_BRIDGE_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
