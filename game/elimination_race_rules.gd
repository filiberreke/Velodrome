extends RefCounted
## UCI-style elimination decision core, separated from scene/presentation.
## Call update with cumulative REAR WHEEL TRAILING EDGE positions in metres.
## All inputs must use the same unwrapped 250 m reference path and tick.
const LAP_M := 250.0
const ELIMINATION_INTERVAL_M := 500.0
const EPSILON_M := 0.001

var active: Array[bool] = []
var eliminated: Array[int] = []
var next_line_m := 500.0
var last_rear_m: Array[float] = []
var initialized := false

func reset(rider_count: int, rear_wheel_positions: Array[float]) -> void:
    assert(rider_count >= 2)
    assert(rear_wheel_positions.size() == rider_count)
    active.clear()
    last_rear_m = rear_wheel_positions.duplicate()
    eliminated.clear()
    for i in range(rider_count):
        active.append(true)
    next_line_m = ELIMINATION_INTERVAL_M
    initialized = true

func remaining_count() -> int:
    var n := 0
    for present in active:
        if present:
            n += 1
    return n

func sample(rear_wheel_positions: Array[float]) -> Dictionary:
    ## Returns one event when an elimination line is reached by the leading rear wheel.
    ## Includes snapshot positions for a finish-photo controller.
    ## This is NOT a jury decision for photo ties: those should pause for review.
    if not initialized or rear_wheel_positions.size() != active.size():
        return {}
    var old := last_rear_m.duplicate()
    last_rear_m = rear_wheel_positions.duplicate()
    if remaining_count() <= 2:
        return {}
    var first_alpha := 2.0
    for i in range(active.size()):
        if not active[i]:
            continue
        var traveled: float = rear_wheel_positions[i] - old[i]
        if traveled <= 0.0:
            continue
        if old[i] < next_line_m and rear_wheel_positions[i] >= next_line_m:
            first_alpha = minf(first_alpha, (next_line_m - old[i]) / traveled)
    if first_alpha > 1.0:
        return {}
    var snapshot: Array[float] = []
    var loser := -1
    var furthest_back := INF
    var second_back := INF
    for i in range(active.size()):
        var at_line_time: float = lerpf(old[i], rear_wheel_positions[i], first_alpha)
        snapshot.append(at_line_time)
        if not active[i]:
            continue
        if at_line_time < furthest_back:
            second_back = furthest_back
            furthest_back = at_line_time
            loser = i
        elif at_line_time < second_back:
            second_back = at_line_time
    var line: float = next_line_m
    next_line_m += ELIMINATION_INTERVAL_M
    if loser < 0:
        return {}
    # If the last two rear wheels are effectively tied, keep the jury decision open.
    var ambiguous: bool = second_back - furthest_back <= EPSILON_M
    if not ambiguous:
        active[loser] = false
        eliminated.append(loser)
    return {
        "line_m": line,
        "tick_fraction": first_alpha,
        "rear_positions_m": snapshot,
        "rider_id": -1 if ambiguous else loser,
        "photo_review": ambiguous,
        "gap_to_penultimate_m": second_back - furthest_back,
        "remaining": remaining_count()
    }
