extends SceneTree
const Brain = preload("res://x_scratch_ai.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	check(is_equal_approx(Brain.economical_closing(2.7, 1.0), 0.0), "No surge at the settled wheel gap")
	check(Brain.economical_closing(3.0, 1.0) < 0.1, "Small correction stays gentle")
	check(is_equal_approx(Brain.economical_closing(10.0, 0.31), 2.0), "Real gap permits strong catch-up")
	check(is_equal_approx(Brain.economical_closing(10.0, 0.30), 1.5), "Low reserve limits closing speed")
	for row in [[4.0, 0.29, 60.0], [4.0, 0.28, 25.0], [4.0, 0.13, 0.0], [6.0, 0.29, 115.0], [6.0, 0.28, 75.0], [6.0, 0.13, 20.0], [7.0, 0.29, 165.0], [7.0, 0.28, 90.0], [7.0, 0.13, 0.0]]:
		check(is_equal_approx(Brain.economical_overhead(row[0], row[1]), row[2]), "CP overhead table: " + str(row))
	var profiles: Array[int] = [0, 1, 2, 3, 1, 1]
	var forms: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	var lanes: Array[float] = [7.18, 2.38, 2.38, 3.58, 4.78, 5.98]
	var distances: Array[float] = [520.0, 503.0, 500.0, 502.0, 498.0, 497.0]
	var speeds: Array[float] = [5.0, 14.0, 14.0, 14.0, 14.0, 14.0]
	var drafts: Array[float] = [0.0, 0.0, 0.7, 0.0, 0.0, 0.0]
	var finished: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
	var credits: Array[int] = [0, 0, 0, 0, 0, 0]
	var model = Brain.new()
	model.reset(profiles, forms, lanes)
	check(is_equal_approx(model.cp[3], 250.0), "Attacker base CP is 250 W")
	model.shelter_wheel[2] = 1
	var before: float = model.wprime[2]
	var watts: Array[float] = model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.shelter_wheel[2] == 1, "Keep aligned wheel despite closer adjacent rider")
	check(watts[2] <= 295.001, "Near wheel uses at most CP + 60 W at 80% difficulty")
	check(model.wprime[2] < before, "Following above CP still spends actual W-prime")
	check(is_equal_approx(model.lane_targets[2], lanes[1]), "Keep shelter lane")
	var economy_watts: float = watts[2]
	model.reset(profiles, forms, lanes)
	model.economical_sprinter_wheels = false
	watts = model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(watts[2] > economy_watts, "Integrated power request is lower than legacy follow")
	model.economical_sprinter_wheels = true
	model.reset(profiles, forms, lanes)
	# A finished wheel must be released immediately, even across a lap boundary.
	model.shelter_wheel[2] = 1
	finished[1] = 10.0
	distances[3] = 752.7
	lanes[3] = lanes[2]
	model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.shelter_wheel[2] == 3, "Release finished wheel; circular acquisition remains valid")
	finished[1] = -1.0
	distances[3] = 502.0
	# Urgent human demarrage response retains the chase controller.
	model.reset(profiles, forms, lanes)
	model.modes[2] = Brain.MODE_CHASE
	model.mode_until[2] = 100.0
	model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.modes[2] == Brain.MODE_CHASE and model.shelter_wheel[2] == -1, "Economy does not override chase tactics")
	model.reset(profiles, forms, lanes)
	model.cooperation[2] = 0.7
	distances = [503.0, 501.0, 500.0, 499.0, 498.0, 497.0]
	speeds = [13.0, 11.0, 11.0, 11.0, 11.0, 11.0]
	model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.modes[2] == Brain.MODE_CHASE, "Nearby sprinter reacts to a real player acceleration")
	# Shelter preference must never win over a hard occupied corridor.
	model.reset(profiles, forms, lanes)
	distances = [520.0, 502.0, 500.0, 500.2, 498.0, 497.0]
	lanes[3] = lanes[2]
	model.shelter_wheel[2] = 1
	model.step(0.1, 20.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(absf(model.lane_targets[2] - lanes[3]) >= 0.85, "Hard conflict overrides wheel retention")
	# Sprint launch must still exceed the economy overhead when reserves allow.
	model.reset(profiles, forms, lanes)
	distances = [12200.0, 12350.0, 12347.0, 12349.0, 12345.0, 12344.0]
	lanes[3] = 3.58
	watts = model.step(0.1, 1000.0, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.sprint_started[2] and watts[2] > 295.0, "Individual final sprint overrides conserving watts")
	model.step(0.1, 1000.1, distances, speeds, lanes, drafts, finished, profiles, 50, 80.0, credits)
	check(model.shelter_wheel[2] == -1, "Launched sprint no longer uses economy wheel retention")
	model.reset(profiles, forms, lanes)
	check(model.shelter_wheel[2] == -1, "New race clears old target")
	print("SPRINTER_ECONOMY_OK" if failures == 0 else "SPRINTER_ECONOMY_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
