extends SceneTree

const Visual = preload("res://rider_visual.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := OS.get_environment("NATIONAL_KIT_CAPTURES")
	if output.is_empty(): output = "res://verification/national_kits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("4c535d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.55
	stage.add_child(environment)
	for rotation in [Vector3(-35, -35, 0), Vector3(-20, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = 0.8
		stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.65
	stage.add_child(camera)
	camera.make_current()
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/riders/national_kits/catalog.json"))
	var count := 0
	for entry in entries:
		for pursuit in [false, true]:
			var rider = Visual.new()
			rider.set_meta("pursuit_mode", pursuit)
			rider.set_meta("jersey_config", entry)
			stage.add_child(rider)
			await process_frame
			var bike := rider.rig_scene.find_child("Bike", true, false) as MeshInstance3D
			if bike != null: bike.visible = false
			rider.cadence_phase = 1.3
			rider._apply_phase()
			for view in ["front", "back"]:
				camera.position = Vector3(0, 1.0, 3.5) if view == "front" else Vector3(0, 2.7, -3.5)
				camera.look_at(Vector3(0, 1.02, 0.12), Vector3.UP)
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				var file := "%s/%s_%s_%s.png" % [output, entry.id, "pursuit" if pursuit else "rider", view]
				if image.save_png(file) != OK:
					push_error("Could not save " + file)
					quit(1)
					return
				count += 1
			rider.queue_free()
			await process_frame
	print("NATIONAL_KIT_GPU_CAPTURES: ", count)
	quit(0 if count == 40 else 1)
