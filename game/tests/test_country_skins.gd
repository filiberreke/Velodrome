extends SceneTree

const Visual = preload("res://rider_visual.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for pursuit in [false, true]:
		var first = Visual.new()
		var other = Visual.new()
		first.set_meta("pursuit_mode", pursuit)
		other.set_meta("pursuit_mode", pursuit)
		# Same profile index: outfit must still affect only the chosen rider.
		first.set_meta("rider_index", 2)
		other.set_meta("rider_index", 2)
		root.add_child(first)
		root.add_child(other)
		await process_frame
		var mesh: MeshInstance3D = first.body_mesh
		check(mesh != null, "Missing body")
		check(mesh.mesh.get_blend_shape_count() == 6, "Six morphs required")
		check(first.resolved_poses.size() == 4, "Four animation clips required")
		var defaults: Array[Material] = []
		var other_materials: Array[Material] = []
		for surface in range(mesh.mesh.get_surface_count()):
			defaults.append(mesh.get_surface_override_material(surface))
			other_materials.append(other.body_mesh.get_surface_override_material(surface))
		check(first.set_country_kit("belgium"), "Belgium must load")
		var count := 0
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.mesh.surface_get_material(surface)
			if source.resource_name.ends_with("_kit"):
				count += 1
				var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
				check(material != null and material.albedo_texture != null, "Full outfit texture missing")
				check(material.albedo_color == Color.WHITE, "Texture tinted by profile")
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				check(uvs.size() > 0, "Missing UVs")
				for uv in uvs:
					check(uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "UV outside atlas")
			elif not source.resource_name.begins_with("decal_"):
				check(mesh.get_surface_override_material(surface) == defaults[surface], "Non-clothing changed")
			check(other.body_mesh.get_surface_override_material(surface) == other_materials[surface], "Other rider changed")
		check(count >= 3, "Clothing surfaces not tagged")
		for pose in range(4):
			first._play_pose(pose)
			first.cadence_phase = 1.4
			first._apply_phase()
			check(first.current_pose == pose, "Pose switching broken")
		for shape in range(6):
			mesh.set_blend_shape_value(shape, 0.7)
		check(not first.set_country_kit("../missing"), "Invalid ID accepted")
		check(first.country_kit == "belgium", "Failed selection replaced current kit")
		check(first.set_country_kit(""), "Restore failed")
		for surface in range(mesh.mesh.get_surface_count()):
			check(mesh.get_surface_override_material(surface) == defaults[surface], "Original material not restored")
		for shape in range(6):
			check(is_equal_approx(mesh.get_blend_shape_value(shape), 0.7), "Selection changed morph")
		var atlas_path := "res://assets/riders/national_kits/belgium/skinsuit.png"
		check(first.set_skinsuit_png(atlas_path), "Explicit PNG selection failed")
		check(first.skinsuit_png == atlas_path, "PNG path not stored")
		for pose in range(4):
			first._play_pose(pose)
			first._apply_phase()
			for surface in range(mesh.mesh.get_surface_count()):
				if mesh.mesh.surface_get_material(surface).resource_name.ends_with("_kit"):
					var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
					check(material.albedo_texture != null, "PNG lost during pose switch")
				check(other.body_mesh.get_surface_override_material(surface) == other_materials[surface], "PNG changed another rider")
		check(not first.set_skinsuit_png("res://missing_skin.png"), "Missing PNG accepted")
		for surface in range(mesh.mesh.get_surface_count()):
			check(mesh.get_surface_override_material(surface) == defaults[surface], "Missing PNG did not restore fallback")
		check(first.set_skinsuit_png("assets/riders/national_kits/belgium/skinsuit.png"), "Relative PNG failed")
		var source := load(atlas_path) as Texture2D
		check(source.get_image().save_png("user://test_skinsuit.png") == OK, "Could not create raw PNG test fixture")
		check(first.set_skinsuit_png("user://test_skinsuit.png"), "Unimported user PNG failed")
		check(first.set_skinsuit_png(ProjectSettings.globalize_path("user://test_skinsuit.png")), "Absolute PNG failed")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_skinsuit.png"))
		check(first.set_skinsuit_png(""), "Empty PNG reset failed")
		for surface in range(mesh.mesh.get_surface_count()):
			check(mesh.get_surface_override_material(surface) == defaults[surface], "Empty PNG did not restore fallback")
		check(first.set_skinsuit_png(atlas_path), "Suit selection before helmet failed")
		check(first.set_helmet_png(atlas_path), "Helmet PNG failed")
		var helmet_surfaces: Array[int] = []
		for surface in range(mesh.mesh.get_surface_count()):
			var source_material := mesh.mesh.surface_get_material(surface)
			if source_material.resource_name in ["helmet", "helmet2"]:
				helmet_surfaces.append(surface)
				var helmet_uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
				check(helmet_uvs.size() > 0, "Helmet has no UVs")
				for uv in helmet_uvs:
					check(uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "Helmet UV out of range")
		check(helmet_surfaces.size() == 2, "Helmet shell panels missing")
		for style in ["donker", "doorzichtig"]:
			check(first.set_visor(style), "Visor option failed")
			for pose in range(4):
				first._play_pose(pose)
				first._apply_phase()
				for surface in range(mesh.mesh.get_surface_count()):
					var source_material := mesh.mesh.surface_get_material(surface)
					var active := mesh.get_active_material(surface) as StandardMaterial3D
					if source_material.resource_name == "visor":
						check(is_equal_approx(active.albedo_color.a, 0.88 if style == "donker" else 0.16), "Visor appearance wrong")
					elif source_material.resource_name.ends_with("_kit") or surface in helmet_surfaces:
						check(active.albedo_texture != null, "Helmet/suit lost during visor or pose switch")
					check(other.body_mesh.get_surface_override_material(surface) == other_materials[surface], "Helmet/visor changed other rider")
		check(first.set_skinsuit_png(""), "Suit reset with helmet failed")
		for surface in helmet_surfaces:
			check((mesh.get_active_material(surface) as StandardMaterial3D).albedo_texture != null, "Suit reset removed helmet PNG")
		check(first.set_skinsuit_png(atlas_path), "Suit reload failed")
		check(not first.set_helmet_png("res://missing_helmet.png"), "Missing helmet accepted")
		for surface in helmet_surfaces:
			check(mesh.get_surface_override_material(surface) == defaults[surface], "Helmet fallback not restored")
		check(not first.set_visor("invalid"), "Invalid visor accepted")
		check(first.set_visor(""), "Visor default reset failed")
		first.set_skinsuit_png("")
		first.free()
		other.free()
	# Selection through metadata/config before ready.
	var configured = Visual.new()
	configured.set_meta("jersey_config", {"skinsuit_png": "res://assets/riders/national_kits/belgium/skinsuit.png", "country_kit": "unused", "helmet_png": "res://assets/riders/national_kits/belgium/skinsuit.png", "visor": "donker"})
	root.add_child(configured)
	await process_frame
	check(configured.skinsuit_png.ends_with("/belgium/skinsuit.png"), "Config PNG selection ignored")
	check(configured.helmet_png.ends_with("skinsuit.png") and configured.visor == "donker", "Helmet/visor config ignored")
	configured.set_country_kit("")
	configured.set_helmet_png("")
	configured.set_visor("")
	await process_frame
	configured.free()
	print("COUNTRY_SKINS_TEST: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
