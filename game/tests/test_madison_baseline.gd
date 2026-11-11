extends SceneTree
## Existing race animations are unchanged: digest of (a) every clip in velodrome_rider.glb and (b) the full
## skeleton pose of a normal rider_visual over a scripted ride (cruise -> sprint seated -> standing -> victory),
## compared with game/tests/madison_baseline.json (generated from the UNPATCHED rider_visual.gd).
## MADISON_WRITE_BASELINE=1 rewrites the baseline (only do that on a pristine checkout).
var failures := 0
const BASELINE := "res://tests/madison_baseline.json"
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")

func _digest(values: PackedFloat32Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(values.to_byte_array())
	return ctx.finish().hex_encode()

func run_test() -> void:
	var vals := PackedFloat32Array()
	# (a) clips
	var base: Node = load("res://assets/riders/velodrome_rider.glb").instantiate()
	var player := base.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names := Array(player.get_animation_list())
	names.sort()
	for n in names:
		var a := player.get_animation(n)
		vals.append(float(a.get_track_count()))
		vals.append(a.length)
		for i in a.get_track_count():
			vals.append(float(a.track_get_key_count(i)))
			for k in a.track_get_key_count(i):
				var v = a.track_get_key_value(i, k)
				if v is Quaternion:
					vals.append_array(PackedFloat32Array([snappedf(v.x, 1e-4), snappedf(v.y, 1e-4), snappedf(v.z, 1e-4), snappedf(v.w, 1e-4)]))
				elif v is Vector3:
					vals.append_array(PackedFloat32Array([snappedf(v.x, 1e-4), snappedf(v.y, 1e-4), snappedf(v.z, 1e-4)]))
	var clip_digest := _digest(vals)
	base.free()
	# (b) scripted ride through the unmodified rider_visual flow
	var rider: Node3D = load("res://rider_visual.gd").new()
	root.add_child(rider)
	await process_frame
	var ride := PackedFloat32Array()
	var sk := rider.rig_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	for f in 300:
		var power := 100.0 if f < 60 else (500.0 if f < 120 else (900.0 if f < 180 else 100.0))
		if f == 240:
			rider.set_victory(true)
		rider.pedal(1.0 / 60.0, 60.0 + 0.1 * f, power)
		for b in sk.get_bone_count():
			var q := sk.get_bone_pose_rotation(b)
			ride.append_array(PackedFloat32Array([snappedf(q.x, 1e-4), snappedf(q.y, 1e-4), snappedf(q.z, 1e-4), snappedf(q.w, 1e-4)]))
	var ride_digest := _digest(ride)
	check(rider.get("exchange_overlay") == null, "normal rider has no exchange overlay (no extra cost)")
	var current := {"clips": clip_digest, "ride": ride_digest, "clip_names": names}
	if OS.get_environment("MADISON_WRITE_BASELINE") == "1":
		var f := FileAccess.open(BASELINE, FileAccess.WRITE)
		f.store_string(JSON.stringify(current, "\t"))
		print("baseline written: ", current)
	else:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		check(expected is Dictionary, "baseline file loads")
		if expected is Dictionary:
			check(expected["clips"] == clip_digest, "velodrome_rider.glb clips unchanged")
			check(expected["ride"] == ride_digest, "rider_visual race flow (cruise/sprint/standing/victory) produces identical poses")
			check(expected["clip_names"] == names, "clip names unchanged: %s" % str(names))
	print("baseline test: failures=", failures, " clips=", clip_digest.substr(0, 12), " ride=", ride_digest.substr(0, 12))
	rider.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
