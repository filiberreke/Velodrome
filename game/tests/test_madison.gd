extends SceneTree
const Exchange := preload("res://madison_exchange.gd")
var failures := 0

class Pair extends RefCounted:
	var distances: Array[float] = [20.0, 20.0]
	var speeds: Array[float] = [12.0, 10.0]
	var lane_offsets: Array[float] = [2.38, 3.58]
	var finish_times: Array[float] = [-1.0, -1.0]
	var baseline_speed := 12.0
	var finished := false
	func _at(d: float, lane: float) -> Vector3:
		return Vector3(d, lane * 0.22, lane)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func prepared(advanced: bool = true) -> Array:
	var pair := Pair.new()
	var model := Exchange.new()
	model.advanced = advanced
	model.step(pair, 0.01)
	return [model, pair]

func _initialize() -> void:
	var setup := prepared()
	var m = setup[0]; var p = setup[1]
	check(m.phase == Exchange.Phase.APPROACH and m.can_grab, "Aligned pair starts reachable approach")
	m.button(true)
	var frozen: float = m.marker
	check(m.phase == Exchange.Phase.GRAB and is_equal_approx(m.precision, 1.0), "Perfect grab captures precision")
	m.step(p, m.grab_seconds)
	check(m.phase == Exchange.Phase.SLING, "GRAB transitions into SLING")
	m.step(p, m.sling_seconds * m.peak_t)
	check(is_equal_approx(m.marker, frozen), "Marker freezes after grab")
	var total: float = p.speeds[0] + p.speeds[1]
	var before: float = p.speeds[1]
	m.button(false)
	m.apply_release(p, m.giver, m.receiver, m.efficiency)
	check(m.phase == Exchange.Phase.RELEASE and is_equal_approx(m.efficiency, 1.0), "Advanced perfect release reaches 100 percent")
	check(p.speeds[1] > before and is_equal_approx(total, p.speeds[0] + p.speeds[1]), "Release accelerates receiver with equal giver loss")
	m.button(false)
	check(is_equal_approx(total, p.speeds[0] + p.speeds[1]), "Duplicate release cannot apply extra impulse")
	m.step(p, m.release_seconds)
	check(m.phase == Exchange.Phase.SEPARATE, "Release enters separation")
	m.step(p, m.separate_seconds)
	check(not m.active and m.active_rider == 1, "Separation completes and receiver becomes active")
	setup = prepared(false); m = setup[0]; p = setup[1]
	m.button(true); m.button(false)
	m.step(p, m.grab_seconds); m.step(p, m.sling_seconds * m.peak_t)
	check(m.phase == Exchange.Phase.RELEASE and is_equal_approx(m.efficiency, 0.7), "Easy tap automatically releases at 70 percent")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.button(true); m.step(p, m.grab_seconds)
	m.step(p, m.sling_seconds * 0.8)
	check(m.efficiency < 0.6 and m.efficiency > 0.0, "Holding beyond peak loses momentum")
	m.step(p, m.sling_seconds)
	check(m.phase == Exchange.Phase.RELEASE and is_zero_approx(m.efficiency), "Overhold times out without bonus")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.button(true); m.button(false)
	check(m.phase == Exchange.Phase.RELEASE and is_zero_approx(m.efficiency), "Release during GRAB safely gives zero bonus")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.button(true); p.lane_offsets[0] = 4.0; m.step(p, 0.02)
	check(m.phase == Exchange.Phase.SEPARATE and not m.parameters().hand_contact, "Steering away breaks contact")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.reset(); p.distances[1] += 8.0; m.step(p, 0.1)
	m.button(true)
	check(m.phase == Exchange.Phase.APPROACH and not m.can_grab, "Out of range press cannot grab")
	p.distances[1] = p.distances[0] - 3.0; m.step(p, 0.1)
	check(m.phase == Exchange.Phase.SEPARATE, "Missed spatial window cancels")
	for lanes in [[1.18, 2.98], [2.38, 3.58]]:
		setup = prepared(); m = setup[0]; p = setup[1]
		m.reset(); p.lane_offsets.assign(lanes)
		var prior := 0.0
		for tick in range(40):
			m.step(p, 0.02)
			check(absf(m.visual_offsets[0] - prior) <= m.convergence_mps * 0.02 + 0.0001, "Visual convergence is rate limited")
			prior = m.visual_offsets[0]
		if lanes[0] == 1.18: check(not m.can_grab, "True 3D distance beyond 1.8 m rejected on bank")
	check(is_equal_approx(Exchange.new().envelope(0.6), 1.0), "Animation and HUD share peak at sling_t 0.6")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.reset(); p.distances[1] += 0.5; m.step(p, 0.01)
	m.button(true); m.step(p, m.grab_seconds); m.step(p, m.sling_seconds * m.peak_t); m.button(false)
	check(m.efficiency < 0.85 and m.efficiency > 0.75, "Imperfect grab caps even a perfectly timed release")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.reset(); p.lane_offsets.assign([1.83, 3.58]); m.step(p, 0.01)
	check(not m.can_grab, "Reachable pair must converge before grabbing")
	for tick in range(100): m.step(p, 0.01)
	check(m.can_grab and m.visual_offsets[0] <= 0.2, "Convergence reaches 1.4 m without extending arms")
	setup = prepared(); m = setup[0]; p = setup[1]
	m.button(true); m.step(p, m.grab_seconds)
	m.step(p, m.sling_seconds * 0.2)
	p.distances[1] += 2.0
	m.step(p, 0.01)
	check(m.phase == Exchange.Phase.RELEASE and m.release_reason == "reach", "Physical drift releases smoothly before arm overextension")
	print("MADISON_OK" if failures == 0 else "MADISON_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
