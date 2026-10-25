extends SceneTree
# Godot 4.x headless regression for player wheel acquisition and solo inner lane.
# Run in an existing complete project: godot --headless --path . --script res://test_x_wheel_follow.gd
const Brain = preload("res://x_scratch_ai.gd")

func _initialize() -> void:
	var model = Brain.new()
	var profiles: Array[int] = [0, 1, 2, 3, 1]
	var forms: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
	var lanes: Array[float] = [3.58, 1.18, 2.38, 5.98, 1.18]
	var finished: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
	var credits: Array[int] = [0, 0, 0, 0, 0]
	var drafts: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var speeds: Array[float] = [13.0, 12.0, 11.0, 11.0, 11.0]
	model.reset(profiles, forms, lanes)
	# An AI chaser on the inside must discover and align with the human's
	# wheel on the outside, even while a tactical lane lock is in effect.
	model.modes[1] = Brain.MODE_CHASE
	model.mode_until[1] = 100.0
	model.lane_lock[1] = 100.0
	var positions: Array[float] = [310.0, 305.0, 300.0, 301.0, 302.0]
	var powers: Array[float] = model.step(0.1, 20.0, positions, speeds, lanes, drafts, finished, profiles, 25, 80.0, credits)
	assert(is_equal_approx(model.lane_targets[1], lanes[0]), "AI chase must align with player's lane")
	assert(powers[1] > 0.0, "AI still pedals while capturing a wheel")
	# No wheel within 30 m: a lone rider in a genuine break rides inside.
	model.reset(profiles, forms, lanes)
	model.modes[1] = Brain.MODE_SOLO
	model.mode_until[1] = 100.0
	positions = [280.0, 325.0, 280.0, 281.0, 282.0]
	model.step(0.1, 20.0, positions, speeds, lanes, drafts, finished, profiles, 25, 80.0, credits)
	assert(is_equal_approx(model.lane_targets[1], Brain.TRACK_LANE_POSITIONS[0]), "Solo rider must choose shortest legal lane")
	print("X_WHEEL_FOLLOW_OK")
	quit(0)
