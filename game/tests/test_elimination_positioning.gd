extends SceneTree
const Motion := preload("res://elimination_motion.gd")
const AI := preload("res://elimination_ai.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func move_pair(gap: float, first: float, target: float, other: float, relative: float = 0.0) -> Array[float]:
	var distances: Array[float] = [249.5, 249.5 + gap]
	var speeds: Array[float] = [12.0, 12.0 + relative]
	var previous: Array[float] = [first, other]
	var requested: Array[float] = [target, other]
	var done: Array[float] = [-1.0, -1.0]
	var metrics: Array[float] = [1.0, 1.0]
	return Motion.constrain_lanes(distances, speeds, previous, requested, done, metrics, 0.1)
func _initialize() -> void:
	check(is_equal_approx(move_pair(0.4, 2.38, 2.495, 2.0)[0], 2.495), "Rightward escape from existing overlap remains possible")
	check(is_equal_approx(move_pair(0.4, 2.0, 1.885, 2.38)[0], 1.885), "Leftward escape remains possible")
	check(is_equal_approx(move_pair(0.0, 2.38, 2.495, 2.38)[0], 2.495), "Coincident riders can separate")
	check(is_equal_approx(move_pair(0.4, 2.38, 2.265, 2.0)[0], 2.38), "Steering further into overlap is blocked")
	check(is_equal_approx(move_pair(0.4, 2.1, 1.8, 2.0)[0], 2.1), "Crossing through an overlapped bicycle is blocked")
	check(move_pair(0.4, 1.78, 1.895, 2.38)[0] <= 1.83001, "An occupied neighbouring line still blocks entry")
	check(is_equal_approx(move_pair(2.1, 1.78, 1.895, 2.38)[0], 1.895), "Compact front and rear clearances allow a merge")
	check(move_pair(2.1, 1.78, 1.895, 2.38, -3.0)[0] <= 1.83001, "A rapidly closing gap still blocks entry")
	var distances: Array[float] = [100.0, 100.4, 99.8]
	var speeds: Array[float] = [12.0, 12.0, 12.0]
	var previous: Array[float] = [2.38, 2.0, 2.98]
	var requested: Array[float] = [2.495, 2.0, 2.98]
	var done: Array[float] = [-1.0, -1.0, -1.0]
	var metrics: Array[float] = [1.0, 1.0, 1.0]
	var result := Motion.constrain_lanes(distances, speeds, previous, requested, done, metrics, 0.1)
	check(result[0] <= 2.43001, "Escaping one rider cannot cross another rider")
	var ai := AI.new()
	var active: Array[int] = [0, 1, 2]
	distances.assign([100.0, 102.1, 97.9]); previous.assign([1.78, 2.38, 2.38])
	check(ai._lane_safe(0, 2.38, active, distances, speeds, previous, {}), "AI can enter a compact opening between two bicycles")
	distances[1] = 101.9
	check(not ai._lane_safe(0, 2.38, active, distances, speeds, previous, {}), "AI still requires bicycle clearance")
	print("ELIMINATION_POSITIONING failures=", failures)
	quit(0 if failures == 0 else 1)
