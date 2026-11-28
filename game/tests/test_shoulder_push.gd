extends SceneTree
# Shoulder push ("schouderduwtje"): additive upper-body layer for the male and the female rider.
# Run with a fixed frame time:  godot --headless --fixed-fps 60 --path game --script res://tests/test_shoulder_push.gd
const Visual := preload("res://rider_visual.gd")
const Layer := preload("res://contact/shoulder_push_layer.gd")
const DT := 1.0 / 60.0
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("  ok  ", message)

func _initialize() -> void:
	call_deferred("run_test")

func make_rider(women: bool, extra: Dictionary = {}) -> Node3D:
	var v = Visual.new()
	if women:
		v.set_meta("category", "women")
	for k in extra:
		v.set_meta(k, extra[k])
	root.add_child(v)
	return v

## run frames (all riders pedalling at `power`) and collect each push layer's measurements
func ride(riders: Array, seconds: float, power: float) -> Array:
	var out := []
	for v in riders:
		var r := {"chest_max": 0.0, "wrist_max": 0.0, "clamped": 0, "frames": 0, "contact_t": -1.0, "finished_t": -1.0, "now": 0.0}
		v.shoulder_contact.connect(func(_s): if r.contact_t < 0.0: r.contact_t = r.now, CONNECT_ONE_SHOT)
		v.shoulder_push_finished.connect(func(_a, _b): r.finished_t = r.now, CONNECT_ONE_SHOT)
		out.append(r)
	var t := 0.0
	while t < seconds:
		for v in riders:
			v.pedal(DT, 95.0, power)
		await process_frame
		t += DT
		for i in riders.size():
			var r: Dictionary = out[i]
			r.now = t
			var layer = riders[i].shoulder_push_layer
			if layer != null and is_instance_valid(layer) and not layer.done:
				r.frames += 1
				r.chest_max = maxf(r.chest_max, layer.last_chest_angle)
				r.wrist_max = maxf(r.wrist_max, maxf(layer.last_wrist_error["L"], layer.last_wrist_error["R"]))
				if layer.last_clamped:
					r.clamped += 1
	return out

func run_test() -> void:
	# --- clip contract
	check(Layer.load_clips(), "shoulder_push_anims.glb loads")
	for role in ["give", "take"]:
		for side in ["L", "R"]:
			var a: Animation = Layer._clips.get(Layer.clip_name(role, side))
			check(a != null and is_equal_approx(a.length, 2.0), "clip %s exists, 2.0 s" % Layer.clip_name(role, side))
			if a == null:
				continue
			var only_upper := true
			var neutral_ends := true
			for i in a.get_track_count():
				var bone := String(a.track_get_path(i).get_concatenated_subnames())
				only_upper = only_upper and bone in Layer.KEYED_BONES and a.track_get_type(i) == Animation.TYPE_ROTATION_3D
				for tt in [0.0, a.length]:
					var d: Quaternion = Layer._rest_inv[bone] * a.rotation_track_interpolate(i, tt)
					neutral_ends = neutral_ends and minf(d.get_angle(), TAU - d.get_angle()) < deg_to_rad(0.2)   # q and -q: same rotation
			check(only_upper, "%s keys only upper-body rotations" % a.resource_name)
			check(neutral_ends, "%s starts and ends in the riding pose (identity delta)" % Layer.clip_name(role, side))
	# --- timing: only the hold stretches
	var l3 = Layer.new()
	l3.duration = 3.0
	var l2 = Layer.new()
	check(is_equal_approx(l3.clip_time(0.30), 0.30) and is_equal_approx(l2.clip_time(0.30), 0.30), "push out takes 0.30 s at any duration")
	check(is_equal_approx(l3.clip_time(3.0 - 0.4), 2.0 - 0.4), "return keeps its speed with a longer hold")
	check(is_equal_approx(l2.clip_time(1.0), 1.0) and is_equal_approx(l2.clip_time(2.0), 2.0), "2.0 s plays the clip 1:1")
	l3.free()
	l2.free()

	for women in [false, true]:
		var label := "renster" if women else "renner"
		var giver := make_rider(women)
		var taker := make_rider(women)
		await process_frame
		check(giver.female == women, "%s model selected" % label)
		await ride([giver, taker], 0.3, 200.0)
		check(giver.shoulder_push("L"), "%s: shoulder_push starts" % label)
		check(taker.receive_shoulder_push("R"), "%s: receive_shoulder_push starts" % label)
		var both: Array = await ride([giver, taker], 2.3, 200.0)
		var rg: Dictionary = both[0]
		var rt: Dictionary = both[1]
		check(rg.contact_t > 0.18 and rg.contact_t < 0.27, "%s: contact signal at ~0.22 s (%.3f)" % [label, rg.contact_t])
		check(absf(rg.finished_t - 2.0) < 0.05, "%s: give finishes after 2.0 s (%.3f)" % [label, rg.finished_t])
		check(absf(rt.finished_t - 2.0) < 0.05, "%s: take finishes after 2.0 s (%.3f)" % [label, rt.finished_t])
		check(rg.chest_max > 5.0, "%s: giver's upper body clearly moves (chest %.1f deg)" % [label, rg.chest_max])
		check(rt.chest_max > 3.0, "%s: receiver reacts (chest %.1f deg)" % [label, rt.chest_max])
		check(rg.wrist_max < 0.003 and rt.wrist_max < 0.003, "%s: hands stay on the bars (max %.1f / %.1f mm)" % [label, rg.wrist_max * 1000.0, rt.wrist_max * 1000.0])
		check(not giver.is_shoulder_push_active() and giver.find_child("ShoulderPush", true, false) == null, "%s: layer removed afterwards" % label)
		# standing sprint + longer hold
		check(giver.shoulder_push("R", 3.0), "%s: push while sprinting out of the saddle" % label)
		var rs: Dictionary = (await ride([giver], 3.3, 950.0))[0]
		check(giver.standing_active, "%s: rider was standing" % label)
		check(absf(rs.finished_t - 3.0) < 0.05, "%s: 3.0 s push lasts 3.0 s (%.3f)" % [label, rs.finished_t])
		check(rs.wrist_max < 0.003, "%s: standing, hands stay on the bars (max %.1f mm, %d clamped frames)" % [label, rs.wrist_max * 1000.0, rs.clamped])
		giver.free()
		taker.free()

	# --- refusals
	var pursuit := make_rider(false, {"pursuit_mode": true})
	await process_frame
	check(not pursuit.shoulder_push("L"), "no push on the pursuit bike")
	pursuit.free()
	var busy := make_rider(false)
	await process_frame
	busy.exchange_overlay = Node.new()
	check(not busy.shoulder_push("L"), "no push during a Madison exchange")
	busy.exchange_overlay.free()
	busy.exchange_overlay = null
	check(busy.receive_shoulder_push("L"), "a rider can start a receive clip")
	check(busy.shoulder_push("R"), "a give clip can replace a receive clip")
	check(not busy.receive_shoulder_push("L") and busy.shoulder_push_layer.role == "give",
		"a new receive clip cannot interrupt an ongoing give clip")
	await process_frame
	busy.set_shoulder_push_paused(true)
	var paused_at: float = busy.shoulder_push_layer.elapsed
	for i in range(5):
		await process_frame
	check(is_equal_approx(busy.shoulder_push_layer.elapsed, paused_at), "pause holds the clip's playhead")
	busy.set_shoulder_push_paused(false)
	for i in range(5):
		await process_frame
	check(busy.shoulder_push_layer.elapsed > paused_at, "resuming advances the same clip")
	busy.finish_pose(false)
	check(not busy.is_shoulder_push_active() and not busy.shoulder_push("R"), "finishing cancels the clip and prevents a new one")
	busy.free()
	print("SHOULDER_PUSH_OK" if failures == 0 else "SHOULDER_PUSH_FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
