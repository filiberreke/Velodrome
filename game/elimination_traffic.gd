extends RefCounted
## Elimination-only longitudinal safety pass, independent of rider update order.
## Each tick: sort by PREVIOUS progress, then constrain only those following
## another rider in the same lateral corridor. Crossing into another corridor
## remains possible without a speed penalty.
const LATERAL_CLEARANCE_M := 0.88
const FOLLOWING_DISTANCE_M := 2.2

static func resolve(previous: Array[float], upcoming: Array[float], speeds: Array[float], lanes: Array[float], finish_times: Array[float], dt: float) -> int:
    if dt <= 0.0 or previous.size() != upcoming.size() or previous.size() != lanes.size() or previous.size() != speeds.size():
        return 0
    var active: Array[int] = []
    for i in range(previous.size()):
        if finish_times[i] < 0.0:
            active.append(i)
    # Fixed tie order for two riders at an identical longitudinal coordinate.
    active.sort_custom(func(a: int, b: int) -> bool: return a < b if absf(previous[a] - previous[b]) < 0.00001 else previous[a] > previous[b])
    var clamped := 0
    for order in range(active.size()):
        var follower: int = active[order]
        var max_progress := upcoming[follower]
        for before in range(order):
            var leader: int = active[before]
            if absf(lanes[leader] - lanes[follower]) >= LATERAL_CLEARANCE_M:
                continue
            var old_gap: float = previous[leader] - previous[follower]
            if old_gap < -0.00001:
                continue
            # The leader is ahead (or owns the deterministic initial tie).
            var allowed: float = upcoming[leader] - FOLLOWING_DISTANCE_M
            if allowed < max_progress:
                max_progress = allowed
        if max_progress < upcoming[follower]:
            # Never move a rider backwards. A pre-existing overlap can only
            # be resolved by waiting for the leader to clear it.
            var requested_step: float = upcoming[follower] - previous[follower]
            upcoming[follower] = maxf(previous[follower], max_progress)
            # Progress is measured on the common 250 m reference, whereas
            # speed is metres along the actual banked lane. Preserve that
            # metric: assigning reference m/s repeatedly stalls outer riders.
            var fraction: float = clampf((upcoming[follower] - previous[follower]) / maxf(requested_step, 0.000001), 0.0, 1.0)
            speeds[follower] *= fraction
            clamped += 1
    return clamped
