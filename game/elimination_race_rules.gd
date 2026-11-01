extends RefCounted
## Isolated elimination-race timing core.
## Input: cumulative trailing edge of rear tyre, in metres on the common 250 m reference path.
## At each elimination line every ACTIVE rider must cross before a decision is issued.
const ELIMINATION_INTERVAL_M := 500.0
const TIE_EPSILON_SECONDS := 0.0005

var active: Array[bool] = []
var last_rear_m: Array[float] = []
var crossing_s: Dictionary = {}
var next_line_m := ELIMINATION_INTERVAL_M
var eliminated: Array[int] = []
var initialized := false

func reset(count: int, rear_positions: Array[float]) -> void:
    assert(count >= 2 and rear_positions.size() == count)
    active.clear()
    for i in range(count):
        active.append(true)
    last_rear_m = rear_positions.duplicate()
    crossing_s.clear()
    eliminated.clear()
    next_line_m = ELIMINATION_INTERVAL_M
    initialized = true

func remaining_count() -> int:
    var total := 0
    for present in active:
        if present:
            total += 1
    return total

func sample(rear_positions: Array[float], start_time_s: float, dt: float) -> Dictionary:
    if not initialized or rear_positions.size() != active.size() or dt <= 0.0:
        return {}
    var previous := last_rear_m.duplicate()
    last_rear_m = rear_positions.duplicate()
    if remaining_count() <= 2:
        return {}
    for i in range(active.size()):
        if not active[i] or crossing_s.has(i):
            continue
        var step: float = rear_positions[i] - previous[i]
        if step > 0.0 and previous[i] < next_line_m and rear_positions[i] >= next_line_m:
            var fraction: float = (next_line_m - previous[i]) / step
            crossing_s[i] = start_time_s + fraction * dt
    if crossing_s.size() < remaining_count():
        return {}
    var ordering: Array[int] = []
    for i in range(active.size()):
        if active[i]:
            ordering.append(i)
    ordering.sort_custom(func(a: int, b: int) -> bool: return float(crossing_s[a]) < float(crossing_s[b]))
    var last_id: int = ordering[ordering.size() - 1]
    var penultimate_id: int = ordering[ordering.size() - 2]
    var gap_s: float = float(crossing_s[last_id]) - float(crossing_s[penultimate_id])
    var event := {
        "line_m": next_line_m,
        "last_rider_id": last_id,
        "crossing_times_s": crossing_s.duplicate(),
        "gap_to_penultimate_s": gap_s,
        "photo_review": gap_s <= TIE_EPSILON_SECONDS,
        "eliminated_id": -1,
        "remaining": remaining_count()
    }
    if not event["photo_review"]:
        active[last_id] = false
        eliminated.append(last_id)
        event["eliminated_id"] = last_id
        event["remaining"] = remaining_count()
    next_line_m += ELIMINATION_INTERVAL_M
    crossing_s.clear()
    return event
