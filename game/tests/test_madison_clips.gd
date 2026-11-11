extends SceneTree
## Madison clips: library loads, track paths match the existing rig, only upper-body bones are keyed,
## shared profile (efficiency curve) is identical in Blender JSON and GDScript, peak == 0.6 == max slider width.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var lib := MadisonProfile.load_library()
	check(lib != null and not lib.get_animation_list().is_empty(), "madison_anims.glb loads as AnimationLibrary")
	var base: Node = load("res://assets/riders/velodrome_rider.glb").instantiate()
	var skel := base.find_child("Skeleton3D", true, false) as Skeleton3D
	var base_player := base.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var cruise := base_player.get_animation("cruise")
	var base_prefix := String(cruise.track_get_path(0)).get_slice(":", 0)
	var profile := MadisonProfile.load_profile()
	check(not profile.is_empty(), "madison_profile.json loads")
	var frames := {"approach": int(profile.get("approach_frames", 30)), "sling": int(profile.get("sling_frames", 60)),
		"release": int(profile.get("release_frames", 30))}
	for role in ["giver", "receiver"]:
		for kind in ["approach", "sling", "release"]:
			var name := MadisonProfile.clip_name(role, kind)
			check(lib.has_animation(name), "clip exists: %s" % name)
			if not lib.has_animation(name):
				continue
			var a := lib.get_animation(name)
			check(is_equal_approx(a.length, float(frames[kind]) / 30.0), "%s length = frames/30fps" % name)
			var seen := {}
			for i in a.get_track_count():
				var path := String(a.track_get_path(i))
				var bone := path.get_slice(":", 1)
				check(path.get_slice(":", 0) == base_prefix, "%s track path prefix matches velodrome_rider.glb (%s)" % [name, path])
				check(skel.find_bone(bone) >= 0, "%s: bone exists in skeleton: %s" % [name, bone])
				check(bone in MadisonProfile.KEYED_BONES, "%s keys only upper-body bones (found %s)" % [name, bone])
				for bad in MadisonProfile.FORBIDDEN_TRACK_PARTS:
					check(not bone.begins_with(bad), "%s has no track on %s" % [name, bad])
				check(a.track_get_type(i) == Animation.TYPE_ROTATION_3D, "%s %s is rotation-only (no root-motion capable position track)" % [name, bone])
				var kc := a.track_get_key_count(i)
				check(kc == 1 or (kc >= 8 and kc <= int(frames[kind]) + 1), "%s %s: constant track or dense key strip (Godot import thins keys; got %d)" % [name, bone, kc])
				seen[bone] = true
			check(seen.size() == MadisonProfile.KEYED_BONES.size(), "%s keys all %d upper-body bones" % [name, MadisonProfile.KEYED_BONES.size()])

	base.free()
	# --- shared profile: Blender table == GDScript formula (HUD and pose use ONE curve)
	var n := int(profile["table_n"])
	var worst := 0.0
	for i in n + 1:
		var t := float(i) / n
		worst = maxf(worst, absf(MadisonProfile.efficiency(t) - float(profile["efficiency"][i])))
		worst = maxf(worst, absf(MadisonProfile.delta_f(t) - float(profile["delta_f"][i])))
		worst = maxf(worst, (MadisonProfile.contact_giver(t) - MadisonProfile.to_godot(profile["contact_giver"][i])).length())
		worst = maxf(worst, (MadisonProfile.contact_receiver(t) - MadisonProfile.to_godot(profile["contact_receiver"][i])).length())
	check(worst < 1e-4, "GDScript profile equals Blender profile table (worst delta %s)" % str(worst))
	check(is_equal_approx(float(profile["peak_t"]), MadisonProfile.PEAK_T), "peak_t in JSON == PEAK_T")

	# --- peak: efficiency / slider width maximum exactly at sling_t = 0.6
	var best_t := 0.0
	var best := -1.0
	for i in 1001:
		var t := float(i) / 1000.0
		var e := MadisonProfile.efficiency(t)
		if e > best:
			best = e
			best_t = t
	check(absf(best_t - 0.6) < 0.0005, "efficiency peaks at sling_t 0.6 (got %.4f)" % best_t)
	check(is_equal_approx(MadisonProfile.efficiency(0.6), 1.0), "efficiency(0.6) == 1.0")
	check(is_equal_approx(MadisonProfile.slider_width(0.6), MadisonProfile.MAX_SLIDER_WIDTH), "HUD slider is at maximum width at 0.6")
	check(MadisonProfile.slider_width(0.0) < MadisonProfile.slider_width(0.3) and MadisonProfile.slider_width(0.3) < MadisonProfile.slider_width(0.6), "slider grows monotonically to the peak")
	check(MadisonProfile.slider_width(0.6) > MadisonProfile.slider_width(0.8) and MadisonProfile.slider_width(0.8) > MadisonProfile.slider_width(1.0), "slider shrinks after the peak (over-holding)")
	check(is_equal_approx(MadisonProfile.efficiency(1.0), MadisonProfile.E_END), "controlled fall-off ends at E_END")

	# --- the VISIBLE peak of the animation is the same moment / same curve as the HUD slider:
	# the giver's clasp point pushes forward by 0.10 m * efficiency(t); normalised, that must follow the slider width.
	var h := MadisonHarness.new()
	await h.build(self)
	h.ik_weight = 0.0                      # pure animation, no IK help
	h.rpm = 0.0                            # frozen crank: no pedalling sway in the measurement
	var samples := 60
	var push: Array[float] = []
	for i in samples + 1:
		h.sling_t = float(i) / samples
		await h.step()
		push.append((h.giver.global_transform.affine_inverse() * h.rg.anchor_world()).z)
	var lo: float = push[0]
	var hi: float = push.max()
	var worst_dev := 0.0
	var push_t := 0.0
	for i in samples + 1:
		var norm := (push[i] - lo) / (hi - lo)
		worst_dev = maxf(worst_dev, absf(norm - MadisonProfile.efficiency(float(i) / samples)))
		if push[i] >= hi - 1e-9:
			push_t = float(i) / samples
	var at_peak := (push[36] - lo) / (hi - lo)       # sling_t 0.6
	check(worst_dev < 0.08, "visible push follows the slider-width curve over the whole sling (max deviation %.3f)" % worst_dev)
	check(at_peak > 0.97, "visible push is at its maximum at sling_t 0.6 (%.3f of maximum)" % at_peak)
	check(absf(push_t - 0.6) < 0.08, "argmax of the visible push is within 0.08 of 0.6 (got %.3f; the top is flat)" % push_t)
	print("visible-vs-slider max deviation ", worst_dev, " push at 0.6 = ", at_peak)
	print("clips test: failures=", failures, " best_t=", best_t, " visual_peak_t=", push_t, " dev=", worst_dev)
	h.rg.detach(); h.rr.detach()
	h.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
