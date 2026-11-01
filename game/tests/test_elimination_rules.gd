extends SceneTree
## Run with: godot --headless --path game --script res://tests/test_elimination_rules.gd
const Rules = preload("res://elimination_race_rules.gd")

func _initialize() -> void:
    # Four riders. All must cross; the last rear wheel is eliminated.
    var jury = Rules.new()
    var start: Array[float] = [0.0, 0.0, 0.0, 0.0]
    jury.reset(4, start)
    var first: Array[float] = [501.0, 502.0, 499.0, 503.0]
    assert(jury.sample(first, 0.0, 1.0).is_empty())
    var second: Array[float] = [504.0, 505.0, 501.0, 506.0]
    var result: Dictionary = jury.sample(second, 1.0, 1.0)
    assert(not result.is_empty())
    assert(int(result["eliminated_id"]) == 2)
    assert(jury.remaining_count() == 3)
    # No repeat event in the next tick.
    var next: Array[float] = [510.0, 511.0, 507.0, 512.0]
    assert(jury.sample(next, 2.0, 1.0).is_empty())
    # The next elimination is at 1000m, not 500m.
    var near: Array[float] = [1001.0, 1002.0, 507.0, 999.0]
    assert(jury.sample(near, 3.0, 1.0).is_empty())
    var after: Array[float] = [1004.0, 1005.0, 507.0, 1001.0]
    result = jury.sample(after, 4.0, 1.0)
    assert(int(result["eliminated_id"]) == 3)
    assert(jury.remaining_count() == 2)
    # With two remaining, elimination stops: final sprint is separate.
    var final_positions: Array[float] = [2000.0, 2001.0, 507.0, 1005.0]
    assert(jury.sample(final_positions, 5.0, 1.0).is_empty())
    # A leader crosses 1000 m before the last rider has crossed 500 m.
    # Its true next-line time must survive the delayed first decision.
    jury.reset(4, start)
    var spread: Array[float] = [1100.0, 1050.0, 900.0, 490.0]
    assert(jury.sample(spread, 0.0, 10.0).is_empty())
    var catch_up: Array[float] = [1200.0, 1150.0, 950.0, 510.0]
    result = jury.sample(catch_up, 10.0, 1.0)
    assert(int(result.eliminated_id) == 3)
    var next_crossing: Array[float] = [1300.0, 1250.0, 1010.0, 510.0]
    result = jury.sample(next_crossing, 11.0, 1.0)
    assert(int(result.eliminated_id) == 2)
    assert(is_equal_approx(float(result.crossing_times_s[0]), 1000.0 / 1100.0 * 10.0))
    assert(jury.remaining_count() == 2)
    print("Elimination rules basic tests passed")
    quit()
