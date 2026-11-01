extends RefCounted
## Isolated elimination-race timing core.
## Input: cumulative trailing edge of rear tyre, in metres on the common 250 m reference path.
## At each elimination line every ACTIVE rider must cross before a decision is issued.
const ELIMINATION_INTERVAL_M := 500.0
const TIE_EPSILON_SECONDS := 0.0005

var active: Array[bool] = []
var last_rear_m: Array[float] = []
var crossing_s: Dictionary = {}
var future_crossings: Dictionary = {}
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
    future_crossings.clear()
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
        if not active[i]:
            continue
        var step: float = rear_positions[i] - previous[i]
        if step <= 0.0: continue
        # Fast riders can pass a later jury line while the tail is still
        # completing this one. Keep those real interpolated crossings; they
        # must not be lost when next_line_m advances after a late decision.
        var line: float = maxf(next_line_m, (floorf(previous[i] / ELIMINATION_INTERVAL_M) + 1.0) * ELIMINATION_INTERVAL_M)
        while line <= rear_positions[i] and line <= (active.size() - 2) * ELIMINATION_INTERVAL_M:
            var time_s: float = start_time_s + (line - previous[i]) / step * dt
            if is_equal_approx(line, next_line_m):
                crossing_s[i] = time_s
            else:
                var key := roundi(line)
                if not future_crossings.has(key): future_crossings[key] = {}
                future_crossings[key][i] = time_s
            line += ELIMINATION_INTERVAL_M
    if crossing_s.size() < remaining_count():
        return {}
    var ordering: Array[int] = []
    for i in range(active.size()):
        if active[i]:
            ordering.append(i)
    ordering.sort_custom(func(a: int, b: int) -> bool: return (float(crossing_s[a]) < float(crossing_s[b])) if not is_equal_approx(float(crossing_s[a]), float(crossing_s[b])) else a < b)
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
    # Preserve progression for a playable prototype. Extremely tight passages
    # are flagged for visual review, but the maximum interpolated crossing time
    # (deterministic rider-ID fallback for an exact floating-point tie) decides.
    active[last_id] = false
    eliminated.append(last_id)
    event["eliminated_id"] = last_id
    event["remaining"] = remaining_count()
    next_line_m += ELIMINATION_INTERVAL_M
    crossing_s = future_crossings.get(roundi(next_line_m), {}).duplicate()
    future_crossings.erase(roundi(next_line_m))
    for id in crossing_s.keys():
        if not active[id]: crossing_s.erase(id)
    return event
