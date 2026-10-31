extends SceneTree
# Headless Godot 4.x smoke test for X tactics, physiology and circular geometry.
const AI = preload("res://x_scratch_ai.gd")
func _initialize() -> void:
	var brain = AI.new()
	var profiles: Array[int] = [0, 1, 2, 3]
	var forms: Array[float] = [1.0, 1.0, 1.0, 1.0]
	var lanes: Array[float] = [1.28, 2.45, 3.85, 5.55]
	brain.reset(profiles, forms, lanes)
	assert(brain.initialized)
	assert(is_equal_approx(brain.cp[2], 240.0))
	assert(is_equal_approx(brain.wmax[2], 30638.0))
	assert(AI.pcurve(5.0, 235.0, 30638.0, 1661.88) > 1200.0)
	assert(is_equal_approx(AI.physical_ahead(499.0, 251.0), 2.0))
	assert(AI.road_power(80.0 / 3.6, 1.0) > 2000.0)
	var progress: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var speed: Array[float] = [10.0, 10.0, 10.0, 10.0]
	var drafts: Array[float] = [0.0, 0.0, 0.5, 0.2]
	var finished: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	var credits: Array[int] = [0, 0, 0, 0]
	var powers: Array[float] = brain.step(0.1, 0.1, progress, speed, lanes, drafts, finished, profiles, 25, 80.0, credits)
	assert(powers.size() == 4)
	assert(powers[1] >= 0.0 and powers[2] >= 0.0)
	assert(brain.wprime[2] >= 0.0 and brain.wprime[2] <= brain.wmax[2])
	# Above CP must consume reserve; sustained sub-CP work must replenish it.
	brain.wprime[2] = 20000.0
	var before: float = brain.wprime[2]
	brain._phys_power(2, 800.0, 2.0)
	assert(brain.wprime[2] < before)
	before = brain.wprime[2]
	brain._phys_power(2, 100.0, 30.0)
	assert(brain.wprime[2] > before)
	print("X_SCRATCH_AI_OK")
	quit(0)
