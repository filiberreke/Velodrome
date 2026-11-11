extends SceneTree
## RELEASE can start from ANY point of the sling and blends smoothly (no pose jump, no hand pop):
## sling_t is frozen at the release moment, release clip + crossfade + IK fade-out run, then SEPARATE fades the overlay out.
## Set MADISON_WRITE_DOCS=1 to write docs/madison/measurements/release_continuity.csv
var failures := 0
const MAX_ROT_STEP_DEG := 6.0      # per 60 fps frame, any upper-body bone
const MAX_HAND_STEP_M := 0.030     # per 60 fps frame (= 2.1 m/s), grab hand relative to its rider
const C0_ROT_DEG := 0.5            # first release frame vs last hold frame
const C0_HAND_M := 0.005
const RELEASE_FRAMES := 45         # 0.75 s release_t sweep 0 -> 1 (Godot-side duration; the clip is a pose strip), starts after the crossfade
const SEPARATE_FRAMES := 18        # 0.3 s overlay -> 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")

func _snap(r: MadisonRiderRig) -> Dictionary:
	var rot := {}
	for b in MadisonProfile.KEYED_BONES:
		rot[b] = r.skeleton.get_bone_pose_rotation(r.skeleton.find_bone(b))
	var rider: Node3D = r.visual
	return {"rot": rot, "hand": rider.global_transform.affine_inverse() * r.anchor_world()}

func _delta(a: Dictionary, b: Dictionary) -> Vector2:   # x = max bone rotation step (deg), y = hand step (m)
	var worst := 0.0
	for k in a["rot"]:
		worst = maxf(worst, rad_to_deg((a["rot"][k] as Quaternion).angle_to(b["rot"][k])))
	return Vector2(worst, (a["hand"] - b["hand"]).length())

func run_test() -> void:
	var h := MadisonHarness.new()
	await h.build(self)
	var csv := "start_sling_t,c0_rot_deg,c0_hand_mm,max_rot_step_deg,max_hand_step_mm,end_hand_to_bars_mm\n"
	var worst_rot := 0.0
	var worst_hand := 0.0
	var starts: Array[float] = []
	for i in 21:
		starts.append(float(i) / 20.0)
	for extra in [0.2, 0.6, 0.95]:
		if not starts.has(extra):
			starts.append(extra)
	starts.sort()
	for t0 in starts:
		# fresh state: grabbed, holding at sling_t = t0
		for r in [h.rg, h.rr]:
			r.release_t = 0.0
			r.mix_release = 0.0
			r.overlay = 1.0
		h.sling_t = t0
		h.ik_weight = 1.0
		for i in 8:
			await h.step()
		var prev := [_snap(h.rg), _snap(h.rr)]
		var c0 := Vector2.ZERO
		var worst := Vector2.ZERO
		var XFADE_FRAMES := roundi(60.0 * MadisonProfile.release_crossfade_seconds(t0))   # crossfade; IK weight fades in the same time
		var IK_FADE_FRAMES := XFADE_FRAMES
		var total := XFADE_FRAMES + RELEASE_FRAMES
		for f in total + SEPARATE_FRAMES + 1:
			var x := clampf(float(f - XFADE_FRAMES) / RELEASE_FRAMES, 0.0, 1.0)
			for r in [h.rg, h.rr]:
				r.release_t = x
				r.mix_release = smoothstep(0.0, 1.0, float(f) / XFADE_FRAMES)
				r.overlay = 1.0 if f <= total else 1.0 - smoothstep(0.0, 1.0, float(f - total) / SEPARATE_FRAMES)
			h.ik_weight = 1.0 - smoothstep(0.0, 1.0, float(f) / IK_FADE_FRAMES)
			await h.step()
			var cur := [_snap(h.rg), _snap(h.rr)]
			for k in 2:
				var d := _delta(prev[k], cur[k])
				if f == 0:
					c0 = Vector2(maxf(c0.x, d.x), maxf(c0.y, d.y))
				worst = Vector2(maxf(worst.x, d.x), maxf(worst.y, d.y))
			prev = cur
		# end state of the release clip: hand back at the bars (rest position of the hand on the tops)
		var bars := _hand_on_bars(h)
		csv += "%.2f,%.3f,%.2f,%.2f,%.2f,%.1f\n" % [t0, c0.x, c0.y * 1000.0, worst.x, worst.y * 1000.0, bars * 1000.0]
		worst_rot = maxf(worst_rot, worst.x)
		worst_hand = maxf(worst_hand, worst.y)
		check(c0.x <= C0_ROT_DEG and c0.y <= C0_HAND_M, "RELEASE from sling_t %.2f starts without a jump (rot %.3f deg, hand %.2f mm)" % [t0, c0.x, c0.y * 1000.0])
		check(worst.x <= MAX_ROT_STEP_DEG and worst.y <= MAX_HAND_STEP_M, "RELEASE from sling_t %.2f is smooth (max %.2f deg/frame, %.1f mm/frame)" % [t0, worst.x, worst.y * 1000.0])
	print("release continuity from %d start points: worst rotation step %.2f deg/frame, worst hand step %.1f mm/frame" % [starts.size(), worst_rot, worst_hand * 1000.0])
	print(csv)
	if OS.get_environment("MADISON_WRITE_DOCS") == "1":
		var dir := ProjectSettings.globalize_path("res://").path_join("../docs/madison/measurements")
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("release_continuity.csv"), FileAccess.WRITE)
		f.store_string(csv)
	print("release test: failures=", failures)
	h.rg.detach(); h.rr.detach()
	h.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

## after SEPARATE the overlay is 0: the rider shows the plain pedal pose. Compare the grab hand to the rider's
## own hand position with the overlay forced to 0 (what the normal flow would show).
func _hand_on_bars(h: MadisonHarness) -> float:
	var before: Vector3 = h.rg.visual.global_transform.affine_inverse() * h.rg.anchor_world()
	var saved: float = h.rg.overlay
	h.rg.overlay = 0.0
	h.ik_weight = 0.0
	h.giver.pedal(1.0 / 60.0, h.rpm, h.power)
	var pure: Vector3 = h.giver.global_transform.affine_inverse() * h.rg.anchor_world()
	h.rg.overlay = saved
	return (before - pure).length()
