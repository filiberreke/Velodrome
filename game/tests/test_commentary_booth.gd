extends SceneTree
## Godot.exe --headless --path . --script res://tests/test_commentary_booth.gd   -> COMMENTARY_BOOTH_OK

func _init() -> void:
	var ok := true
	var scene: PackedScene = load("res://assets/commentary/commentary_booth.tscn")
	if scene == null:
		print("FAIL: scene did not load"); quit(1); return
	var booth: Node3D = scene.instantiate()
	root.add_child(booth)
	await process_frame
	for who in ["CommentatorLinks", "CommentatorRechts"]:
		var c: Node3D = booth.get_node(who)
		var mesh: MeshInstance3D = c._mesh
		if mesh == null:
			print("FAIL ", who, ": no mesh with blend shapes"); ok = false; continue
		var names := []
		for i in mesh.mesh.get_blend_shape_count():
			names.append(mesh.mesh.get_blend_shape_name(i))
		for n in ["open", "wide", "round", "smile", "blink_L", "blink_R", "brow_up"]:
			if not names.has(n):
				print("FAIL ", who, ": blend shape missing ", n); ok = false
		var anim: AnimationPlayer = c._anim
		if anim == null or not anim.has_animation("idle") or not anim.has_animation("talk"):
			print("FAIL ", who, ": animations missing"); ok = false
		var skel := c.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel == null or skel.find_bone("head") < 0:
			print("FAIL ", who, ": skeleton/head bone missing"); ok = false
		var vc := 0
		for s in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(s) as BaseMaterial3D
			if m and m.vertex_color_use_as_albedo and m.resource_name.ends_with("_skin"):
				vc += 1
		if vc == 0:
			print("FAIL ", who, ": skin material without vertex colours"); ok = false
		var aabb := mesh.get_aabb()
		print(who, " blend shapes ", names, " aabb ", aabb, " surfaces ", mesh.mesh.get_surface_count())
	var glass := booth.find_child("BoothGlass", true, false)
	if glass == null:
		print("FAIL: BoothGlass node missing"); ok = false
	# drive a procedural announcement for a few frames and make sure the mouth moves
	var r: Node3D = booth.get_node("CommentatorRechts")
	r.talking = true
	var maxopen := 0.0
	for i in 60:
		await process_frame
		maxopen = maxf(maxopen, r._mesh.get_blend_shape_value(r._mesh.find_blend_shape_by_name("open")))
	print("max open while talking ", maxopen, " anim ", r._anim.current_animation)
	if r._anim.current_animation != "talk":
		print("FAIL: talk animation not playing"); ok = false
	if maxopen < 0.3:
		print("FAIL: mouth does not move while talking"); ok = false
	booth.frame_shot("rechts")
	print("COMMENTARY_BOOTH_OK" if ok else "COMMENTARY_BOOTH_FAIL")
	quit(0 if ok else 1)
