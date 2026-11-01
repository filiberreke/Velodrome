extends "res://x_scratch_ai.gd"
## Elimination-specific decisions; inherits the real CP, W', Pmax and fatigue model.
## Only physics and rendering remain owned by main.gd.
var elimination_line_m := 500.0
var final_line_m := 7500.0

func _inner_corridor_clear(i: int, candidate: float, distances: Array[float], speeds: Array[float], lanes: Array[float], finished: Array[float]) -> bool:
    if not super._inner_corridor_clear(i, candidate, distances, speeds, lanes, finished): return false
    if i <= 0 or finished[0] >= 0.0: return true
    # Respect the player's reserved manoeuvre too. The inherited scratch
    # planner only reserves earlier AI riders, not human steering requests.
    var low: float = minf(lanes[i], candidate) - 0.88
    var high: float = maxf(lanes[i], candidate) + 0.88
    if maxf(lanes[0], lane_targets[0]) <= low or minf(lanes[0], lane_targets[0]) >= high: return true
    var horizon: float = absf(lanes[i] - candidate) / 1.15 + 0.5
    var gap: float = fposmod(distances[0] - distances[i] + 125.0, 250.0) - 125.0
    var future: float = gap + (speeds[0] - speeds[i]) * horizon
    var nearest: float = 0.0 if gap * future <= 0.0 else minf(absf(gap), absf(future))
    return nearest >= 4.5

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
    var bunch: Array[int] = []
    for id in active:
        if id > 0: bunch.append(id)
    var bunch_middle: int = bunch[bunch.size() / 2] if not bunch.is_empty() else active[0]

    for i in range(1, count):
        if finished[i] >= 0.0:
            continue
        var rank := active.find(i) + 1
        var n := active.size()
        var remaining: float = maxf(0.0, deadline - distances[i])
        var imminent := clampf((200.0 - remaining) / 160.0, 0.0, 1.0)
        var risk: float = clampf(float(rank - maxi(1, n - 5)) / 4.0, 0.0, 1.0)
        var reserve := wprime[i] / maxf(wmax[i], 1.0)
        var sheltered := drafts[i] > 0.12
        # Cruise on a real wheel: match its speed rather than independently
        # riding a fixed CP fraction (which strings out the field).
        var wheel := -1
        var wheel_gap := 70.0
        var wheel_cost := 1000.0
        for j in active:
            var gap: float = distances[j] - distances[i]
            var lateral: float = absf(lanes[j] - lanes[i])
            # A rider alongside is not a wheel to brake for. Prefer a wheel
            # in our corridor over repeatedly chasing across the banking.
            var cost: float = gap + lateral * 8.0
            if j != i and gap > (0.1 if lateral < 0.88 else 4.0) and gap < 70.0 and cost < wheel_cost:
                wheel = j
                wheel_gap = gap
                wheel_cost = cost
        var target: float = cp[i] * (0.76 if sheltered else 0.92)
        if wheel >= 0 and remaining > 200.0:
            var wanted_speed: float = maxf(0.0, speeds[wheel] + clampf((wheel_gap - 3.2) * 0.28, -1.0, 2.0))
            var aero: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
            target = clampf(road_power(wanted_speed, aero) / 0.975, 0.0, cp[i] + minf(130.0, wprime[i] / 22.0))
        if not final_pair and remaining > 200.0 and clock >= 14.0 and distances[i] - distances[bunch_middle] > 10.0:
            # The front eases to keep the cruising bunch together. Chasers
            # still have to close the gap using their own CP/W' and physics.
            var bunch_speed: float = maxf(5.0, speeds[bunch_middle] - 1.0)
            var aero: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
            target = minf(target, road_power(bunch_speed, aero) / 0.975)
        if remaining < 200.0:
            var kick: float = pcurve(maxf(6.0, remaining / maxf(speeds[i], 7.0)), cp[i], wprime[i], pmax[i])
            var strength: float = (0.62 + 0.33 * risk) if not final_pair else 0.99
            target = maxf(target, lerpf(cp[i], kick * strength, imminent))
        if rank == n and remaining < 130.0:
            target = maxf(target, minf(pmax[i], cp[i] + 0.90 * wprime[i] / maxf(5.0, remaining / maxf(speeds[i], 7.0))))
        if not final_pair and reserve < 0.14 and rank <= maxi(2, n - 3):
            target = minf(target, cp[i] * 1.04)

        # Same standing-start envelope as scratch and points; W' and Pmax
        # still apply through _phys_power below. Never rearm at an elimination.
        if clock < 14.0 and speeds[i] < 11.0 and distances[i] < 170.0:
            var launch_time_weight: float = clampf((14.0 - clock) / 7.0, 0.0, 1.0)
            var launch_speed_weight: float = clampf((11.0 - speeds[i]) / 3.0, 0.0, 1.0)
            var launch_watts: float = minf(450.0, maxf(350.0, cp[i] * 1.65))
            var steady_watts: float = cp[i] * (0.76 if drafts[i] > 0.12 else 0.91)
            var launch_target: float = lerpf(steady_watts, launch_watts, launch_time_weight * launch_speed_weight)
            target = maxf(target, launch_target)

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
        if blocked_by >= 0 and (imminent > 0.10 or (distances[active[0]] - distances[i] > 15.0 and speeds[i] > speeds[blocked_by] + 0.5)):
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
        elif remaining > 200.0:
            # Acquire the nearest wheel without cutting across occupied lanes.
            var wheel_lane: float = lanes[wheel] if wheel >= 0 and wheel_gap > 6.0 else lanes[i]
            candidate = wheel_lane if _inner_corridor_clear(i, wheel_lane, distances, speeds, lanes, finished) else lanes[i]
        # Avoid burning the launch in repeated uphill/downhill lane changes.
        if clock < 14.0:
            candidate = lanes[i]
        lane_targets[i] = candidate
        output[i] = _phys_power(i, target * (difficulty / 80.0), dt)
        power_w[i] = output[i]
    return output
