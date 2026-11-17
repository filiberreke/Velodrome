extends SceneTree
## Run: godot --headless --path game --script res://tests/test_omnium_recovery.gd
const Recovery = preload("res://omnium/energy_recovery.gd")

func _initialize() -> void:
	var finish_levels := [0.0, 0.2, 0.5, 0.8, 1.0]
	var checkpoints := [0.0, 900.0, 1800.0, 3600.0, 7200.0, 10800.0, 14400.0]
	for finish_level in finish_levels:
		var previous := -1.0
		for seconds in checkpoints:
			var value: float = Recovery.recovered_reserve(finish_level, seconds)
			assert(value >= finish_level and value <= 1.0)
			assert(value >= previous)
			if seconds == 0.0: assert(is_equal_approx(value, finish_level))
			if seconds == 3600.0: assert(absf(value - (finish_level + 0.8 * (1.0 - finish_level))) < 0.00001)
			if seconds == 14400.0: assert(is_equal_approx(value, 1.0))
			previous = value
	assert(Recovery.recovered_reserve(-0.5, 0.0) == 0.0)
	assert(Recovery.recovered_reserve(1.5, 0.0) == 1.0)
	print("PASS: omnium recovery 5 finish levels x 7 checkpoints, 80% deficit recovered at 1h, 100% at 4h")
	quit()
