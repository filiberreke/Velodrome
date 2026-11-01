extends "res://x_scratch_ai.gd"
## Elimination-specific decisions; inherits the real CP, W', Pmax and fatigue model.
## Only physics and rendering remain owned by main.gd.
var elimination_line_m := 500.0
var final_line_m := 7500.0

func step(dt: float, clock: float, distances: Array[float], speeds: Array[float], lanes: Array[float], drafts: Array[float], finished: Array[float], profiles: Array[int], laps: int, difficulty: float, credits: Array[int]) -> Array[float]:
    var count := distances.size()
    var output: Array[float] = []
    output.resize(count)
    output.fill(0.0)
    if not initialized or count != cp.size() or dt <= 0.0:
        return output

    var active: Array[int] = []
    for i in range(count):
        if finished[i] < 0.0:
            active.append(i)
    if active.size() <= 1:
        return output
    active.sort_custom(func(a: int, b: int) -> bool: return distances[a] > distances[b])
    var final_pair := active.size() <= 2
    var deadline: float = final_line_m if final_pair else elimination_line_m
    var group_tail: float = distances[active[active.size()-1]]
    var last_approach: float = maxf(0.0, deadline - group_tail)

    for i in range(1, count):
        if finished[i] >= 0.0:
            continue
        var rank := active.find(i) + 1
        var n := active.size()
        var remaining: float = maxf(0.0, deadline - distances[i])
        var imminent := clampf((240.0 - remaining) / 200.0, 0.0, 1.0)
        var risk: float = clampf(float(rank - maxi(1, n - 5)) / 4.0, 0.0, 1.0)
        var reserve := wprime[i] / maxf(wmax[i], 1.0)
        var sheltered := drafts[i] > 0.12
        # Follow at CP or slightly below; the last five riders react progressively.
        var target: float = cp[i] * (0.79 if sheltered else 0.96)
        if remaining < 450.0:
            target = maxf(target, cp[i] * (0.96 + 0.19 * risk))
        if remaining < 240.0:
            var kick: float = pcurve(maxf(6.0, remaining / maxf(speeds[i], 7.0)), cp[i], wprime[i], pmax[i])
            var strength: float = (0.62 + 0.33 * risk) if not final_pair else 0.99
            target = maxf(target, lerpf(cp[i], kick * strength, imminent))
        if rank == n and remaining < 130.0:
            target = maxf(target, minf(pmax[i], cp[i] + 0.90 * wprime[i] / maxf(5.0, remaining / maxf(speeds[i], 7.0))))
        if not final_pair and reserve < 0.14 and rank <= maxi(2, n - 3):
            target = minf(target, cp[i] * 1.04)

        # Search for a REAL pass, rather than changing lanes just because a wheel is close.
        var blocked_by := -1
        var blocking_gap := 100.0
        for j in active:
            if j == i:
                continue
            var ahead: float = distances[j] - distances[i]
            if ahead > 0.1 and ahead < 7.0 and absf(lanes[j] - lanes[i]) < 0.88 and ahead < blocking_gap:
                blocked_by = j
                blocking_gap = ahead
        var candidate: float = lanes[i]
        if blocked_by >= 0 and (imminent > 0.10 or speeds[i] >= speeds[blocked_by] - 0.3):
            var options: Array[float] = []
            for direction in [-1.0, 1.0]:
                var lane: float = clampf(lanes[i] + direction * 1.20, TRACK_LANE_POSITIONS[0], TRACK_LANE_POSITIONS[TRACK_LANE_POSITIONS.size() - 1])
                if absf(lane - lanes[i]) > 0.35 and _inner_corridor_clear(i, lane, distances, speeds, lanes, finished):
                    options.append(lane)
            if not options.is_empty():
                # Inside is shorter, but an open outside corridor is safer than being boxed in.
                candidate = options[0]
                if options.size() == 2:
                    candidate = options[0] if options[0] < options[1] else options[1]
            else:
                # The following rider alone must lower speed, not mutually block both.
                var allowed_v: float = maxf(2.0, speeds[blocked_by] + maxf(0.0, blocking_gap - 2.0) * 0.55)
                if speeds[i] > allowed_v:
                    var drag_factor: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
                    target = minf(target, road_power(allowed_v, drag_factor) / 0.975)
        elif blocked_by < 0 and remaining > 220.0:
            candidate = TRACK_LANE_POSITIONS[0] if _inner_corridor_clear(i, TRACK_LANE_POSITIONS[0], distances, speeds, lanes, finished) else lanes[i]
        lane_targets[i] = candidate
        output[i] = _phys_power(i, target * (difficulty / 80.0), dt)
        power_w[i] = output[i]
    return output
