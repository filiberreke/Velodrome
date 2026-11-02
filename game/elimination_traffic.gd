extends RefCounted
## Elimination-only longitudinal safety pass, independent of rider update order.
## Each tick: sort by PREVIOUS progress, then constrain only those following
## another rider in the same lateral corridor. Crossing into another corridor
## remains possible without a speed penalty.
const LATERAL_CLEARANCE_M := 0.65
const FOLLOWING_DISTANCE_M := 2.2

static func lateral_clearance(a: int, b: int, scales: Array[float]) -> float:
    # Lane offsets are horizontal. On banking the real centre-to-centre
    # distance is larger: do not treat visibly separate bicycles as one lane.
    return LATERAL_CLEARANCE_M / maxf(1.0, minf(scales[a], scales[b])) if not scales.is_empty() else LATERAL_CLEARANCE_M

static func constrain_lanes(distances: Array[float], speeds: Array[float], previous: Array[float], requested: Array[float], done: Array[float], scales: Array[float], dt: float) -> Array[float]:
    var result: Array[float] = requested.duplicate()
    # Yield laterally BEFORE a new corridor overlap can impose a speed clamp
    # on the incumbent. Applies equally to manual, assisted and AI steering.
    for a in range(previous.size()):
        if done[a] >= 0.0: continue
        for b in range(a + 1, previous.size()):
            if done[b] >= 0.0: continue
            var gap: float = fposmod(distances[b] - distances[a] + 125.0, 250.0) - 125.0
            var future: float = gap + (speeds[b] - speeds[a]) * maxf(0.6, dt)
            var nearest: float = 0.0 if gap * future <= 0.0 else minf(absf(gap), absf(future))
            if nearest >= FOLLOWING_DISTANCE_M + 0.3: continue
            var separation: float = absf(previous[b] - previous[a])
            var clearance: float = lateral_clearance(a, b, scales) + 0.02
            # Existing followers may move away from the shared corridor.
            # Even just inside the safety margin, forbid further convergence.
            if separation < 0.00001: continue
            var direction: float = signf(previous[b] - previous[a])
            var inward_a: float = maxf(0.0, (result[a] - previous[a]) * direction)
            var inward_b: float = maxf(0.0, (previous[b] - result[b]) * direction)
            var inward: float = inward_a + inward_b
            var available: float = maxf(0.0, separation - clearance)
            if inward <= available or inward <= 0.0: continue
            var fraction: float = maxf(0.0, available / inward)
            if inward_a > 0.0: result[a] = previous[a] + direction * inward_a * fraction
            if inward_b > 0.0: result[b] = previous[b] - direction * inward_b * fraction
    return result

static func resolve(previous: Array[float], upcoming: Array[float], speeds: Array[float], lanes: Array[float], finish_times: Array[float], dt: float, lateral_scales: Array[float] = []) -> int:
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
            if absf(lanes[leader] - lanes[follower]) >= lateral_clearance(leader, follower, lateral_scales) - 0.00001:
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
