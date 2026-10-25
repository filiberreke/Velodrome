extends SceneTree
# Run with Godot installed: godot --headless --path PROJECT --script res://test_scratch_lap_rules.gd
const Rules = preload("res://scratch_lap_rules.gd")
func _initialize() -> void:
	var rules = Rules.new()
	rules.reset(5)
	assert(is_equal_approx(Rules.ahead_gap(760.0, 515.0), 5.0))
	assert(is_equal_approx(Rules.ahead_gap(500.0, 510.0), 10.0))
	var positions: Array[float] = [743.0, 501.0, 504.0, 507.0, 250.0]
	var ends: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
	rules.examine(positions, ends, 100.0)
	assert(rules.credits[0] == 0)
	positions[0] = 749.5 # 248.5m ahead of the bunch tail (rear-wheel contact).
	rules.examine(positions, ends, 101.0)
	assert(rules.credits[0] == 1)
	rules.examine(positions, ends, 102.0)
	assert(rules.events.size() == 1)
	ends = [107.0, 104.0, 105.0, 106.0, 110.0]
	assert(rules.better(0, 1, ends, positions))
	rules.reset(5)
	assert(rules.credits[0] == 0 and rules.events.is_empty())
	# Passing through the same physical point without a full-lap advantage is not a gain.
	positions = [520.0, 501.0, 504.0, 507.0, 250.0]
	ends = [-1.0, -1.0, -1.0, -1.0, -1.0]
	rules.examine(positions, ends, 10.0)
	positions[0] = 524.0
	rules.examine(positions, ends, 11.0)
	assert(rules.credits[0] == 0)
	# The exact same detector works for player and all AI rider IDs.
	rules.reset(5)
	positions = [501.0, 504.0, 507.0, 743.0, 245.0]
	rules.examine(positions, ends, 10.0)
	positions[3] = 749.5
	rules.examine(positions, ends, 11.0)
	assert(rules.credits[3] == 1)
	print("SCRATCH_LAP_RULES_OK")
	quit(0)
