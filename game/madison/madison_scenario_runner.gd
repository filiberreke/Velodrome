class_name MadisonScenarioRunner
extends Node3D
## Runs the test scenarios A-D through the real MadisonDemoExchange controller with two real rider_visuals, at 60 fps,
## with simulated gameplay (receiver ahead / speeds) and a scripted player input. Returns metrics + a per-frame timeline
## (the timeline is also exported to JSON and replayed in Blender: docs/madison/measurements/timeline_*.json).
##   A  perfect: Advanced, A held until sling_t 0.6, released at the peak
##   B  too early: released at sling_t 0.2
##   C  held too long: released at sling_t 0.95 (efficiency has dropped), release from a late pose
##   D  lateral gap (0.60 / 1.20 / 1.80 m): Easy mode, controller does the visual correction

const FPS := 60.0
var giver: Node3D
var receiver: Node3D
var ex: MadisonDemoExchange
var rpm := 70.0
var power := 250.0
var v_giver := 16.0
var v_receiver := 14.0

func build(tree: SceneTree) -> void:
	if get_parent() == null:
		tree.root.add_child(self)
	giver = _rider(0)
	receiver = _rider(2)
	ex = MadisonDemoExchange.new()
	add_child(ex)
	await tree.process_frame

func _rider(index: int) -> Node3D:
	var v: Node3D = load("res://rider_visual.gd").new()
	v.set_meta("rider_index", index)
	add_child(v)
	return v

func run(scenario: String, gap: float = 1.2, record: bool = true, drift_rate: float = 0.0) -> Dictionary:
	var mode := MadisonDemoExchange.Mode.ADVANCED if scenario in ["A", "B", "C", "M"] else MadisonDemoExchange.Mode.EASY
	var hold_until: float = {"A": MadisonProfile.PEAK_T, "B": 0.2, "C": 0.95}.get(scenario, 0.0)
	var events: Array = []
	var timeline: Array = []
	var m := {"scenario": scenario, "gap": gap, "max_err_mm": 0.0, "max_stretch": 0.0, "min_visual_gap": 9.0, "max_visual_gap": 0.0,
		"max_err_approach_mm": 0.0, "events": events, "timeline": timeline, "release_reason": "", "release_efficiency": -1.0,
		"release_sling_t": -1.0, "approach_end_stretch": 0.0, "grab_ok": false, "separated": false, "frames": 0,
		"max_lean_deg": 0.0, "max_visual_shift_m": 0.0}
	ex.grab_failed.connect(func(r: String) -> void: events.append("grab_failed:" + r))
	ex.grab_window_opened.connect(func() -> void: events.append("grab_window_opened"))
	ex.grabbed.connect(func() -> void:
		events.append("grabbed")
		m["grab_ok"] = true)
	ex.sling_peak.connect(func() -> void: events.append("sling_peak"))
	ex.released.connect(func(e: float) -> void:
		events.append("released:%.3f" % e)
		m["release_efficiency"] = e
		m["release_sling_t"] = ex.sling_t
		m["release_reason"] = ex.release_reason)
	ex.separated.connect(func() -> void:
		events.append("separated")
		m["separated"] = true)
	events.append("approach_started")
	ex.start(giver, receiver, mode, "", v_giver, v_receiver)
	var ahead := 1.0
	var ahead_release := 0.0
	var f := 0
	var dt := 1.0 / FPS
	while (ex.state != MadisonDemoExchange.State.IDLE or ex._post) and f < 900:
		# scripted player input (Advanced)
		if scenario == "M":      # manual Advanced: hold A (or Space) yourself
			ex.a_held = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_SPACE)
		elif mode == MadisonDemoExchange.Mode.ADVANCED:
			match ex.state:
				MadisonDemoExchange.State.APPROACH:
					ex.a_held = ex.approach_t >= 0.85
				MadisonDemoExchange.State.GRAB:
					ex.a_held = true
				MadisonDemoExchange.State.SLING:
					ex.a_held = ex.sling_t < hold_until
				_:
					ex.a_held = false
		# simulated gameplay: receiver closes in during the approach, nominal during the sling, then drifts with the speeds
		match ex.state:
			MadisonDemoExchange.State.APPROACH:
				ahead = (1.0 - ex.approach_t) * 1.0
			MadisonDemoExchange.State.GRAB:
				ahead = 0.0
			MadisonDemoExchange.State.SLING:
				ahead = MadisonProfile.delta_f(ex.sling_t) + drift_rate * ex._t_state
				ahead_release = ahead
			_:
				ahead += (ex.speed_receiver - ex.speed_giver) * dt
		giver.position = Vector3.ZERO
		receiver.position = Vector3(-gap, 0.0, ahead)
		ex.set_gameplay(gap, ahead)
		ex.tick(dt)
		giver.pedal(dt, rpm, power)
		receiver.pedal(dt, rpm, power)
		await get_tree().process_frame
		f += 1
		if ex.rig_g != null and is_instance_valid(ex.rig_g) and ex.state != MadisonDemoExchange.State.IDLE:
			var e := maxf((ex.rig_g.anchor_world() - ex.contact.global_position).length(), (ex.rig_r.anchor_world() - ex.contact.global_position).length()) * 1000.0
			var st := ex._stretch()
			if ex.state in [MadisonDemoExchange.State.GRAB, MadisonDemoExchange.State.SLING] and ex.ik_active_both():
				m["max_err_mm"] = maxf(m["max_err_mm"], e)
			if ex.state == MadisonDemoExchange.State.APPROACH and ex.approach_t >= 0.8:
				m["approach_end_stretch"] = maxf(m["approach_end_stretch"], st)
				m["max_err_approach_mm"] = e
			if ex.state in [MadisonDemoExchange.State.GRAB, MadisonDemoExchange.State.SLING]:
				m["max_stretch"] = maxf(m["max_stretch"], st)
			m["min_visual_gap"] = minf(m["min_visual_gap"], ex.visual_gap)
			m["max_visual_gap"] = maxf(m["max_visual_gap"], ex.visual_gap)
			m["max_lean_deg"] = maxf(m["max_lean_deg"], absf(rad_to_deg((giver.get("rig_scene") as Node3D).rotation.z)))
			m["max_visual_shift_m"] = maxf(m["max_visual_shift_m"], absf((giver.get("rig_scene") as Node3D).position.x) * 2.0)
			if record:
				timeline.append({"f": f, "state": int(ex.state), "approach_t": ex.approach_t, "sling_t": ex.sling_t, "release_t": ex.release_t,
					"mix_sling": ex.rig_g.mix_sling, "mix_release": ex.rig_g.mix_release, "overlay": ex.rig_g.overlay, "ik": ex.rig_g.ik_weight,
					"eff": MadisonProfile.efficiency(ex.sling_t), "slider": MadisonProfile.slider_width(ex.sling_t),
					"recv_x": receiver.position.x, "recv_z": receiver.position.z, "off_g": (giver.get("rig_scene") as Node3D).position.x,
					"off_r": (receiver.get("rig_scene") as Node3D).position.x, "lean": (giver.get("rig_scene") as Node3D).rotation.z,
					"phase_g": giver.get("cadence_phase"), "phase_r": receiver.get("cadence_phase")})
		elif record and ex.state == MadisonDemoExchange.State.IDLE:
			pass
	m["frames"] = f
	m["cleaned_up"] = ex.rig_g == null and giver.get("exchange_overlay") == null and receiver.get("exchange_overlay") == null
	for c in ["grab_failed", "grab_window_opened", "grabbed", "sling_peak", "released", "separated"]:
		for conn in ex.get_signal_connection_list(c):
			ex.disconnect(c, conn["callable"])
	return m
