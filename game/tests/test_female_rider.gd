extends SceneTree
# Female rider variant: same rig/clips as the original, three hair meshes, config keys.
const Visual := preload("res://rider_visual.gd")
const Catalog := preload("res://rider_catalog.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

# name -> [parent name, global rest origin]; bone order may differ between Blender versions
func _skeleton(scene: Node) -> Dictionary:
	var skel := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var out := {}
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		out[skel.get_bone_name(i)] = [skel.get_bone_name(parent) if parent >= 0 else "", skel.get_bone_global_rest(i).origin]
	return out

func _same_skeleton(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for bone in a:
		if not b.has(bone) or a[bone][0] != b[bone][0] or not (a[bone][1] as Vector3).is_equal_approx(b[bone][1]):
			push_warning("Skeleton differs at " + String(bone))
			return false
	return true

func run_test() -> void:
	var male = Visual.new()
	root.add_child(male)
	var woman = Visual.new()
	woman.set_meta("jersey_config", {"sex": "female", "hair_style": "ponytail", "hair_color": "blond", "country_kit": "belgium"})
	root.add_child(woman)
	await process_frame
	check(male.rig_scene.scene_file_path.ends_with("velodrome_rider.glb") and not male.female, "Default stays the original rider")
	check(male.rig_scene.find_child("Hair_ponytail", true, false) == null, "Original rider has no female hair meshes")
	check(woman.female and woman.rig_scene.scene_file_path.ends_with("velodrome_rider_female.glb"), "sex=female selects female GLB")
	check(_same_skeleton(_skeleton(male), _skeleton(woman)), "Same bones, parents and rest positions")
	check(woman.resolved_poses.size() == 4 and woman.animator != null, "All four clips resolve on the female rider")
	var body: MeshInstance3D = woman.rig_scene.find_child("Rider", true, false)
	var shapes := []
	for i in body.mesh.get_blend_shape_count():
		shapes.append(String(body.mesh.get_blend_shape_name(i)))
	check(shapes == Visual.SHAPE_KEYS, "Body shape keys preserved: " + str(shapes))
	check(woman.get_visible_hair_style() == "ponytail", "Configured hair style visible")
	var visible := 0
	for style in Visual.HAIR_STYLES:
		var node: MeshInstance3D = woman.rig_scene.find_child("Hair_" + style, true, false)
		check(node != null and node.skin != null, "Hair mesh %s present and skinned" % style)
		if node != null and node.visible: visible += 1
	check(visible == 1, "Exactly one hair style visible")
	var tail: MeshInstance3D = woman.rig_scene.find_child("Hair_ponytail", true, false)
	var tinted := tail.get_surface_override_material(0) as StandardMaterial3D
	check(tinted != null and tinted.albedo_color.is_equal_approx(Visual.HAIR_COLORS["blond"]), "Hair colour by name")
	check(woman.set_hair_style("short") and woman.get_visible_hair_style() == "short", "Hair style switch at runtime")
	check(woman.set_hair_color("#7a5230"), "Hair colour by hex")
	check(not woman.set_hair_style("mohawk") and woman.get_visible_hair_style() == "short", "Unknown style ignored")
	check(not male.set_hair_style("ponytail"), "Male rider reports no hair meshes")
	woman.pedal(0.25, 90.0, 1200.0)
	check(woman.current_pose == 2 and woman.standing_active, "Female rider uses the same pose switching")
	var sprinter = Visual.new()
	sprinter.set_meta("rider_index", 2)
	sprinter.set_meta("sex", "female")
	root.add_child(sprinter)
	var custom = Visual.new()
	custom.set_meta("rider_index", 2)
	custom.set_meta("sex", "female")
	custom.set_meta("body_shapes", {"ShoulderWidth": 0.9})
	root.add_child(custom)
	await process_frame
	var sb: MeshInstance3D = sprinter.rig_scene.find_child("Rider", true, false)
	var cb: MeshInstance3D = custom.rig_scene.find_child("Rider", true, false)
	check(is_equal_approx(sb.get_blend_shape_value(sb.find_blend_shape_by_name("ShoulderWidth")), 0.75 * 0.7), "Sprinter profile shoulders toned down for rensters")
	check(is_equal_approx(sb.get_blend_shape_value(sb.find_blend_shape_by_name("ArmMass")), 0.57 * 0.7), "Sprinter profile arms toned down for rensters")
	check(is_equal_approx(sb.get_blend_shape_value(sb.find_blend_shape_by_name("ThighMass")), 0.9), "Other profile shapes unchanged")
	check(is_equal_approx(cb.get_blend_shape_value(cb.find_blend_shape_by_name("ShoulderWidth")), 0.9), "Explicit config value never scaled")
	var pursuit = Visual.new()
	pursuit.set_meta("pursuit_mode", true)
	pursuit.set_meta("jersey_config", {"sex": "female"})
	root.add_child(pursuit)
	await process_frame
	check(pursuit.rig_scene.scene_file_path.ends_with("velodrome_pursuit.glb") and not pursuit.female, "Pursuit falls back to pursuit model")
	var cfg := ConfigFile.new()
	cfg.set_value("rider_01", "name", "Test Renster")
	cfg.set_value("rider_01", "sex", "female")
	cfg.set_value("rider_01", "hair_style", "low_bun")
	cfg.set_value("rider_01", "hair_color", "rood")
	var entry: Dictionary = Catalog.entry(cfg, 1, 1)
	check(entry.jersey.get("sex") == "female" and entry.jersey.get("hair_style") == "low_bun" and entry.jersey.get("hair_color") == "rood", "Catalog passes appearance keys: " + str(entry.jersey))
	for n in [male, woman, sprinter, custom, pursuit]:
		n.free()
	print("FEMALE_RIDER_OK" if failures == 0 else "FEMALE_RIDER_FAILED")
	quit(0 if failures == 0 else 1)
