extends SceneTree
const Exchange := preload("res://madison_exchange.gd")
class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _record_ai_performances() -> void: pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func make_game(advanced: bool):
	var game := TestRace.new()
	root.add_child(game)
	game.race_mode = 6
	game.race_laps = 30
	game.madison_advanced = advanced
	game._configure_peloton()
	game.running = true
	game.start_state = "RACING"
	game.watts = 300.0
	return game

func run() -> void:
	for advanced in [false, true]:
		var game = make_game(advanced)
		var phases: Array[String] = []
		game.madison.phase_changed.connect(func(p: String, _g: int, _r: int): phases.append(p))
		var grabbed := false
		var released := false
		for tick in range(24000):
			game.clock += 1.0 / 120.0
			game._update_race(1.0 / 120.0)
			if not grabbed and game.madison.can_grab and game.madison.marker >= 0.795:
				var before: int = game.player_lane
				var event := InputEventKey.new()
				event.keycode = KEY_A; event.pressed = true
				game._input(event)
				check(game.player_lane == before, "A grabs without steering")
				grabbed = true
				if not advanced:
					event.pressed = false; game._input(event)
			if advanced and grabbed and not released and game.madison.phase == Exchange.Phase.SLING and game.madison.sling_t >= 0.6:
				game._ride_raw_button({"source_button":"A", "pressed":true}, false)
				game._madison_button("keyboard", false)
				check(game.madison.phase == Exchange.Phase.SLING, "Second held input keeps contact")
				game._ride_raw_button({"source_button":"A", "pressed":false}, false)
				released = true
			if grabbed and not game.madison.active: break
		check(grabbed, "Live physics offers a reachable grab")
		check(phases == ["APPROACH", "GRAB", "SLING", "RELEASE", "SEPARATE"], "Live physics completes all five phases: %s" % str(phases))
		check(game.madison.efficiency > (0.95 if advanced else 0.65), "Live release respects timing and difficulty cap")
		check(game.madison.active_rider == 1, "AI receiver becomes active")
		# Reverse roles: the player receives and retains complete steering control.
		game.madison.reset(); game.madison.active_rider = 1
		game.player_lane = 4
		game.lane_offsets.assign([3.58, 2.38]); game.distances.assign([50.0, 50.0]); game.speeds.assign([10.0, 12.0]); game.baseline_speed = 10.0
		game.madison.step(game, 0.01)
		check(game.madison.giver == 1 and game.madison.can_grab, "AI giver is inside slow player")
		game._madison_button("test", true)
		game.madison.step(game, game.madison.grab_seconds)
		game.madison.step(game, game.madison.sling_seconds * 0.6)
		game._madison_button("test", false)
		check(is_equal_approx(game._madison_ai_lane(), game.lane_offsets[1]), "Outgoing AI waits for bicycle clearance")
		game.distances[0] += 3.0
		check(game._madison_ai_lane() > 3.58, "Slowing AI steers above blue line after clearance")
		check(game.player_lane == 4, "Release never changes player steering selection")
		game._steer_player(1)
		check(game.player_lane == 5, "Player can steer away after release")
		# Banking, lap seam and both directions use real track geometry.
		for position in [110.0, 249.9]:
			game.madison.reset()
			game.madison.advanced = advanced
			game.player_lane = 2
			game.lane_offsets.assign([2.38, 3.58]); game.distances.assign([position, position]); game.speeds.assign([11.0, 10.5]); game.baseline_speed = 11.0
			for tick in range(100): game.madison.step(game, 0.01)
			check(game.madison.can_grab, "Grab converges on banking or lap seam")
			game._madison_button("test", true)
			for tick in range(170):
				game.clock += 0.01
				game._update_race(0.01)
				if advanced and game.madison.phase == Exchange.Phase.SLING and game.madison.sling_t >= 0.6: game._madison_button("test", false)
			check(game.madison.active_rider == 1, "Physical contact survives slinging on banking or lap seam")
			game._madison_button("test", false)
		game.free()
	var hud := preload("res://madison_hud.gd").new()
	root.add_child(hud)
	var model := Exchange.new()
	hud.update_state(model.parameters())
	check(hud.visible and hud.caption.text.contains("Easy"), "HUD renders current difficulty")
	check(is_equal_approx(hud.anchor_top, 0.0) and hud.offset_top >= 242.0, "Slider sits at top below the wattage display")
	hud.update_state({})
	check(not hud.visible, "HUD hides outside Madison")
	hud.free()
	print("MADISON_INTEGRATION_OK" if failures == 0 else "MADISON_INTEGRATION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
