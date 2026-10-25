extends SceneTree
const Rules = preload("res://simulator/race_rules.gd")
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + message)
		quit(1)

func _initialize() -> void:
	check(Rules.sprint_laps(25) == [5, 10, 15, 20, 25], "25-lap schedule")
	check(Rules.sprint_laps(15) == [5, 10, 15], "15-lap schedule")
	check(Rules.sprint_laps(50).size() == 10, "50-lap schedule")
	var crossings := Rules.ordered_crossings([249.0, 249.6, 245.0], [251.0, 250.1, 245.3], 0.1, 250.0)
	check(crossings.size() == 2, "exactly two crossings")
	# Rider 0 crosses at 0.05 s; rider 1 at 0.08 s.
	check(crossings[0]["rider"] == 0, "interpolated order within same tick")
	var points: Array = [0, 0, 0, 0]
	Rules.award(points, [2, 1, 0, 3], false)
	check(points == [1, 2, 3, 0], "intermediate scoring")
	Rules.award(points, [3, 1, 0, 2], true)
	check(points == [3, 6, 4, 6], "final scoring")
	# Points [3, 6, 4, 6]: finish rank only resolves riders 1 and 3.
	check(Rules.standings(points, [2, 1, 3, 0]) == [3, 1, 2, 0], "tie break by finish")
	print("PASS: ", checks, " race rule checks")
	quit(0)
