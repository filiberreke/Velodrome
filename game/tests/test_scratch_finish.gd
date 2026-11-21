extends SceneTree

class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass
	func _capture_demo_fit_sample() -> void: pass

var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run_tests() -> void:
	for credit in [1]:
		var game := TestRace.new()
		root.add_child(game)
		game.race_mode = 0; game.rider_count = 4; game.race_laps = 10
		game._configure_peloton()
		game.running = true; game.start_state = "RACING"; game.watts = 315.0
		game.scratch_rules.credits[0] = credit
		# Player reaches the raw race distance while the bunch still has laps left.
		game.distances.assign([2499.9, 2499.9 - credit * 250.0, 2498.9 - credit * 250.0, 2497.9 - credit * 250.0])
		game.speeds.fill(12.0)
		game.baseline_speed = 12.0 # Match the rolling player speed used by the motor.
		game.clock = 200.0
		game.clock += 0.1; game._advance_race(0.1)
		check(game.distances[0] > 2500.0, "Player crosses raw distance with a lap gain")
		check(game.finish_times[0] < 0.0 and not game.finished, "Raw distance cannot finish scratch early")
		check(game.scratch_rules.finish_clock < 0.0, "Jury awaits the actual final lap")
		check(absf(game._last_lap_progress() - float(game.peloton_info.center)) < 0.001, "Bell follows HUD peloton clock")
		check(game._hud_race_lap() == 10, "HUD shows bunch lap 10 instead of player lap 11")
		game.peloton_info = {"center": 2001.0}
		check(game._hud_race_lap() == 9 and game._last_lap_progress() == 2001.0, "HUD and bell share bunch clock")
		game.peloton_info.clear()
		check(game._hud_race_lap() == 10, "Fallback removes gained lap from odometer")
		# The same physical line one/two laps later is the real finish.
		game.distances.assign([2499.9 + credit * 250.0, 2499.8, 2498.8, 2497.8])
		game.speeds.fill(12.0)
		game.baseline_speed = 12.0 # Match the rolling player speed used by the motor.
		game.clock += 0.1; game._advance_race(0.1)
		check(game.finish_times[0] >= 0.0 and game.finished, "Jury finishes player at credited final passage")
		check(game.scratch_rules.finish_clock >= 0.0, "Arrival belongs to the common jury finish")
		game.free()
	# A lapped rider finishes at the first passage after the common finish.
	var jury = preload("res://scratch_lap_rules.gd").new()
	jury.reset(4)
	jury.credits.assign([1, 0, 0, -1])
	var ends: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	jury.advance([2749.0, 2498.0, 2497.0, 2230.0], [2751.0, 2500.0, 2499.0, 2232.0], 100.0, 1.0, ends, 10)
	check(ends[0] == 99.5 and ends[1] == 100.0 and ends[3] < 0.0, "Common finish preserves physical passage order")
	jury.advance([2751.0, 2500.0, 2499.0, 2232.0], [2751.0, 2500.0, 2501.0, 2252.0], 110.0, 10.0, ends, 10)
	check(ends[3] >= 0.0, "Lapped rider need not ride the full odometer distance")
	print("SCRATCH_FINISH failures=", failures)
	quit(0 if failures == 0 else 1)
