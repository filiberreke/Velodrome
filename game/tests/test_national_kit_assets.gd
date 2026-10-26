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
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/riders/national_kits/catalog.json"))
	check(entries.size() == 10, "Expected ten new countries")
	var ids: Array[String] = []
	for entry in entries:
		check(not ids.has(entry.id), "Duplicate country")
		ids.append(entry.id)
		check(ResourceLoader.exists(entry.skinsuit_png) and ResourceLoader.exists(entry.helmet_png), "Missing PNG: " + entry.id)
		for pursuit in [false, true]:
			var rider = Visual.new()
			var neighbor = Visual.new()
			rider.set_meta("pursuit_mode", pursuit)
			neighbor.set_meta("pursuit_mode", pursuit)
			rider.set_meta("rider_index", 2)
			neighbor.set_meta("rider_index", 2)
			rider.set_meta("jersey_config", entry)
			root.add_child(neighbor)
			root.add_child(rider)
			await process_frame
			check(rider.skinsuit_png == entry.skinsuit_png and rider.helmet_png == entry.helmet_png, "Config path ignored")
			var body: MeshInstance3D = rider.body_mesh
			var mesh: Mesh = body.mesh
			check(mesh.get_blend_shape_count() == 6 and rider.resolved_poses.size() == 4, "Morphs/poses changed")
			var before: Array[Material] = []
			for surface in range(mesh.get_surface_count()):
				before.append(neighbor.body_mesh.get_surface_override_material(surface))
			var image: Image = (load(entry.skinsuit_png) as Texture2D).get_image()
			if image.is_compressed(): image.decompress()
			check((image.detect_alpha() != Image.ALPHA_NONE) == (entry.sleeves == "short"), "Wrong sleeve coverage: " + entry.id)
			for pose in range(4):
				rider._play_pose(pose)
				rider.cadence_phase = 1.3
				rider._apply_phase()
				for shape in range(6): body.set_blend_shape_value(shape, 0.4)
				for surface in range(mesh.get_surface_count()):
					var name := mesh.surface_get_material(surface).resource_name
					var active := body.get_active_material(surface)
					if name.ends_with("_kit"):
						if entry.sleeves == "short":
							check(active is ShaderMaterial, "Short sleeve did not use opaque skin coverage")
							if active is ShaderMaterial:
								check(active.get_shader_parameter("skinsuit_atlas") != null, "Coverage atlas missing")
								check(active.get_shader_parameter("skin_color").a == 1.0, "Skin must be opaque")
						else:
							check(active is StandardMaterial3D and active.albedo_texture != null, "Long sleeve texture missing")
					elif name in ["helmet", "helmet2"]:
						check(active is StandardMaterial3D and active.albedo_texture != null, "Helmet texture missing")
					elif name == "visor":
						check(is_equal_approx(active.albedo_color.a, 0.88), "Dark visor missing")
					elif not name.begins_with("decal_"):
						check(body.get_surface_override_material(surface) == rider._default_materials[surface], "Unrelated material changed")
					check(neighbor.body_mesh.get_surface_override_material(surface) == before[surface], "Neighbor changed")
			rider.set_skinsuit_png("")
			rider.set_helmet_png("")
			rider.set_visor("")
			for surface in range(mesh.get_surface_count()):
				check(body.get_surface_override_material(surface) == rider._default_materials[surface], "Fallback restore failed")
			rider.queue_free()
			neighbor.queue_free()
			await process_frame
	print("NATIONAL_KIT_ASSETS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures; 10 countries x 2 rigs x 4 poses)")
	quit(0 if failures == 0 else 1)
