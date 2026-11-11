extends SceneTree
## Hand contact over the whole sling: nominal 1.20 m, other gaps, and DYNAMIC speed differences
## (the riders drift away from the authored relative position while the hands stay connected).
## Set MADISON_WRITE_DOCS=1 to (re)write docs/madison/measurements/*.csv
var failures := 0
const CONTACT_LIMIT_MM := 5.0        # required: hands within 10 mm; we assert 5 mm while the arm is not clamped
const CLAMP_STRETCH := 0.97
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var h := MadisonHarness.new()
	await h.build(self)
	var write_docs := OS.get_environment("MADISON_WRITE_DOCS") == "1"
	var rest_len := {}   # arm bone lengths (no-stretch check)
	for r in [h.rg, h.rr]:
		var sk: Skeleton3D = r.skeleton
		var side := MadisonProfile.grab_side(r.role)
		rest_len[r.role] = [sk.get_bone_rest(sk.find_bone("forearm." + side)).origin.length(), sk.get_bone_rest(sk.find_bone("hand." + side)).origin.length()]

	# ---- A. nominal gap, FK only vs IK, over the whole sling
	var worst_fk := 0.0
	var worst_ik := 0.0
	var csv := "sling_t,fk_giver_mm,fk_receiver_mm,ik_giver_mm,ik_receiver_mm,stretch_giver,stretch_receiver\n"
	for i in 51:
		h.sling_t = float(i) / 50.0
		h.ik_weight = 0.0
		await h.step()
		var fk := h.errors_mm()
		h.ik_weight = 1.0
		await h.step()
		var ik := h.errors_mm()
		var st := h.stretch()
		worst_fk = maxf(worst_fk, maxf(fk.x, fk.y))
		worst_ik = maxf(worst_ik, maxf(ik.x, ik.y))
		csv += "%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f\n" % [h.sling_t, fk.x, fk.y, ik.x, ik.y, st.x, st.y]
	check(worst_ik < CONTACT_LIMIT_MM, "A: nominal 1.20 m, hands within %.0f mm of HandContact over the whole sling with IK (worst %.2f mm)" % [CONTACT_LIMIT_MM, worst_ik])
	print("A nominal gap 1.20 m: worst error FK-only %.1f mm, with IK %.2f mm" % [worst_fk, worst_ik])
	if write_docs:
		_write("sling_contact_godot_nominal.csv", csv)

	# ---- B. other lateral gaps (visual correction / steering differences), pose from the 1.20 m clip
	var tab_b := "gap_m,worst_ik_giver_mm,worst_ik_receiver_mm,max_stretch,clamped_any\n"
	for gap in [1.0, 1.1, 1.2, 1.3, 1.4, 1.5]:
		h.gap = gap
		var wk := Vector2.ZERO
		var mx := 0.0
		var cl := false
		for i in 26:
			h.sling_t = float(i) / 25.0
			h.ik_weight = 1.0
			await h.step()
			wk = Vector2(maxf(wk.x, h.errors_mm().x), maxf(wk.y, h.errors_mm().y))
			mx = maxf(mx, maxf(h.stretch().x, h.stretch().y))
			cl = cl or h.rg.ik.last_clamped or h.rr.ik.last_clamped
		tab_b += "%.2f,%.2f,%.2f,%.3f,%s\n" % [gap, wk.x, wk.y, mx, cl]
		if gap <= 1.4:
			check(maxf(wk.x, wk.y) < CONTACT_LIMIT_MM and mx < CLAMP_STRETCH, "B: gap %.2f m keeps contact (worst %.2f mm, stretch %.2f)" % [gap, maxf(wk.x, wk.y), mx])
	h.gap = MadisonProfile.REF_GAP
	print("B lateral gaps:\n", tab_b)
	if write_docs:
		_write("sling_contact_gap_table.csv", tab_b)

	# ---- C. dynamic speed difference: while the sling runs (2 s) the receiver drifts away from / towards the giver
	# (relative speed differs from the authored one), plus jitter. Hands must stay connected frame by frame.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for amp in [0.15, 0.30, 0.45]:
		var worst := 0.0
		var max_stretch := 0.0
		var clamped_frames := 0
		var frames := 120
		var jitter := 0.0
		var prev_anchor := [Vector3.ZERO, Vector3.ZERO]
		var max_step := 0.0
		for f in frames + 1:
			var t := float(f) / frames
			jitter = lerpf(jitter, rng.randf_range(-0.04, 0.04), 0.2)
			h.sling_t = t
			h.deviation = Vector3(0.0, 0.0, amp * sin(PI * t) * (1.0 if f % 2 == 0 or true else 1.0) + jitter)
			h.ik_weight = 1.0
			await h.step()
			var e := h.errors_mm()
			var st := h.stretch()
			max_stretch = maxf(max_stretch, maxf(st.x, st.y))
			if h.rg.ik.last_clamped or h.rr.ik.last_clamped:
				clamped_frames += 1
			worst = maxf(worst, maxf(e.x, e.y))
			var a: Array = [h.rg.anchor_world() - h.giver.global_position, h.rr.anchor_world() - h.recv.global_position]
			if f > 0:
				max_step = maxf(max_step, maxf((a[0] - prev_anchor[0]).length(), (a[1] - prev_anchor[1]).length()))
			prev_anchor = a
		check(clamped_frames == 0 and worst < CONTACT_LIMIT_MM, "C: dynamic drift +-%.2f m keeps hands connected (worst %.2f mm, %d clamped frames)" % [amp, worst, clamped_frames])
		check(max_step < 0.05, "C: hand moves smoothly relative to its body under drift (max %.1f mm/frame)" % (max_step * 1000.0))
		print("C dynamic drift amplitude %.2f m: worst contact error %.2f mm, max arm stretch %.2f, clamped frames %d, max hand step %.1f mm/frame" % [amp, worst, max_stretch, clamped_frames, max_step * 1000.0])
	h.deviation = Vector3.ZERO

	# ---- D. longitudinal deviation table + no-stretch guarantee when the target is out of reach
	var tab_d := "deviation_m,t,giver_err_mm,receiver_err_mm,stretch_giver,stretch_receiver,clamped\n"
	for dz in [-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
		for t in [0.0, 0.6, 1.0]:
			h.sling_t = t
			h.deviation = Vector3(0, 0, dz)
			h.ik_weight = 1.0
			await h.step()
			var e2 := h.errors_mm()
			var s2 := h.stretch()
			var cl2: bool = h.rg.ik.last_clamped or h.rr.ik.last_clamped
			tab_d += "%.1f,%.1f,%.2f,%.2f,%.3f,%.3f,%s\n" % [dz, t, e2.x, e2.y, s2.x, s2.y, cl2]
			if not cl2 and maxf(s2.x, s2.y) < CLAMP_STRETCH:
				check(maxf(e2.x, e2.y) < CONTACT_LIMIT_MM, "D: deviation %.1f m at t=%.1f within reach keeps contact (%.2f mm)" % [dz, t, maxf(e2.x, e2.y)])
			# bones never stretch, also when clamped: rest length of forearm + hand offset, measured in the final pose
			for r in [h.rg, h.rr]:
				var sk: Skeleton3D = r.skeleton
				var side := MadisonProfile.grab_side(r.role)
				var fa := sk.get_bone_pose_position(sk.find_bone("forearm." + side)).length()
				var ha := sk.get_bone_pose_position(sk.find_bone("hand." + side)).length()
				check(absf(fa - float(rest_len[r.role][0])) < 1e-4 and absf(ha - float(rest_len[r.role][1])) < 1e-4, "D: bone lengths never change (no stretch)")
	print("D longitudinal deviation table:\n", tab_d)
	if write_docs:
		_write("dynamic_contact_table.csv", tab_d)
	var h_clamp := false
	h.sling_t = 0.6
	h.deviation = Vector3(0, 0, 1.4)
	await h.step()
	h_clamp = h.rg.ik.last_clamped or h.rr.ik.last_clamped
	check(h_clamp, "D: an out-of-reach target is reported as clamped (controller must release early)")
	print("contact test: failures=", failures)
	h.rg.detach(); h.rr.detach()
	h.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

func _write(file: String, text: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/madison/measurements")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
	if f != null:
		f.store_string(text)
