extends SceneTree
## Run: godot --headless --path game --script res://tests/test_elimination_traffic.gd
const Traffic = preload("res://elimination_traffic.gd")

func _initialize() -> void:
    var previous: Array[float]
    var upcoming: Array[float]
    var speeds: Array[float]
    var lanes: Array[float]
    var done: Array[float]
    # 1: follower tries to reach same position; front rider keeps all its speed.
    previous = [100.0, 97.5]
    upcoming = [107.5, 106.0]
    speeds = [15.0, 17.0]
    lanes = [1.18, 1.18]
    done = [-1.0, -1.0]
    Traffic.resolve(previous, upcoming, speeds, lanes, done, 0.5)
    assert(is_equal_approx(upcoming[0], 107.5))
    assert(upcoming[1] <= upcoming[0] - 2.2 + 0.001)

    # 2: riders alongside in separate legal corridors: neither is slowed.
    previous = [100.0, 100.0]
    upcoming = [107.0, 108.0]
    speeds = [14.0, 16.0]
    lanes = [1.18, 2.38]
    Traffic.resolve(previous, upcoming, speeds, lanes, done, 0.5)
    assert(is_equal_approx(upcoming[0], 107.0))
    assert(is_equal_approx(upcoming[1], 108.0))

    # 3: a faster rider can pass outside without a longitudinal cap.
    previous = [100.0, 97.0]
    upcoming = [107.0, 109.0]
    speeds = [14.0, 24.0]
    lanes = [1.18, 2.38]
    Traffic.resolve(previous, upcoming, speeds, lanes, done, 0.5)
    assert(upcoming[1] > upcoming[0])

    # 4: 16 riders, six corridors and >=2.4m initial same-lane spacing.
    previous = []
    upcoming = []
    speeds = []
    lanes = []
    done = []
    var possible := [1.18, 2.38, 3.58, 4.78, 5.98, 7.18]
    for i in range(16):
        var progress: float = 100.0 - 2.4 * float(i / 6)
        previous.append(progress)
        upcoming.append(progress + 7.0)
        speeds.append(14.0)
        lanes.append(possible[i % 6])
        done.append(-1.0)
    for tick in range(40):
        var prior: Array[float] = upcoming.duplicate()
        for i in range(16): upcoming[i] += 7.0
        Traffic.resolve(prior, upcoming, speeds, lanes, done, 0.5)
        for v in speeds: assert(v > 10.0)
    print("Elimination traffic 4 tests passed")
    quit()
