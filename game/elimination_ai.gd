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
    # A finalist must keep pedalling after the other finalist has finished.
    if active.is_empty():
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
        # Only the rear of the field needs to gain places. Use the leader's
        # distance to the jury line: a dropped rider has less time, not more.
        var jury_remaining: float = maxf(0.0, deadline - distances[active[0]])
        var danger_count: int = mini(3, maxi(1, n / 4))
        var risk: float = clampf(float(rank - (n - danger_count)) / float(danger_count), 0.0, 1.0)
        var positioning: bool = (final_pair and remaining < 200.0) or (not final_pair and remaining > 0.0 and risk > 0.0 and jury_remaining < 110.0)
        var imminent: float = clampf((110.0 - jury_remaining) / 85.0, 0.0, 1.0) * risk
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
        if wheel >= 0:
            var wanted_speed: float = maxf(0.0, speeds[wheel] + clampf((wheel_gap - 3.2) * 0.28, -1.0, 1.2))
            var aero: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
            target = clampf(road_power(wanted_speed, aero) / 0.975, 0.0, cp[i] + minf(130.0, wprime[i] / 22.0))
        if not final_pair and not positioning and clock >= 14.0 and distances[i] - distances[bunch_middle] > 8.0:
            # The front eases to keep the cruising bunch together. Chasers
            # still have to close the gap using their own CP/W' and physics.
            var bunch_speed: float = maxf(5.0, speeds[bunch_middle] - 1.0)
            var aero: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
            target = minf(target, road_power(bunch_speed, aero) / 0.975)
        if positioning:
            var kick: float = pcurve(maxf(6.0, remaining / maxf(speeds[i], 7.0)), cp[i], wprime[i], pmax[i])
            var urgency: float = clampf((200.0 - remaining) / 160.0, 0.0, 1.0) if final_pair else imminent
            target = maxf(target, lerpf(target, kick * 0.99, urgency))
            if not final_pair:
                # This is a fight for a safe place, never a breakaway. Once
                # moving faster than the first safe rider, stop accelerating.
                # Account for both drag and acceleration with the real mass.
                var safe_rider: int = active[n - danger_count - 1]
                var survival_speed: float = speeds[safe_rider] + 0.8
                var aero: float = maxf(0.31, 1.0 - 0.69 * drafts[i])
                var survival_power: float = (road_power(survival_speed, aero) + MASS * maxf(speeds[i], 1.0) * (survival_speed - speeds[i]) * 0.6) / DRIVETRAIN
                target = minf(target, maxf(0.0, survival_power))
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

        # Use the inherited scratch/points traffic policy; elimination only
        # supplies its next-jury-line positioning and keeps its own pace demand.
        var traffic_mode: int = MODE_DRAFT if wheel >= 0 else MODE_SOLO
        # Elimination has no attack, chase, breakaway or pull-off tactics.
        # A temporarily exposed rider only returns to a wheel in the bunch.
        modes[i] = MODE_DRAFT
        target = _traffic_power(i, target, distances, speeds, lanes, finished, maxf(0.31, 1.0 - 0.69 * drafts[i]))
        _update_rider_line(i, clock, distances, speeds, lanes, finished, traffic_mode, wheel, wheel_gap, positioning, not positioning, distances[bunch_middle], distances[active[0]], [], positioning)
        output[i] = _phys_power(i, target * (difficulty / 80.0), dt)
        power_w[i] = output[i]
    return output
