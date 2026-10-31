extends "res://tests/capture_infield_boxes.gd"

func run_capture() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	game = Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.setup_panel.select_mode(1)
	for i in range(4): await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT + "menu_ai_renner.png")
	game.setup_panel.select_mode(2)
	for i in range(4): await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT + "menu_ai_land.png")
	game._set_menu_visible(false)
	game._update_visuals(0.0)
	hide_ui(game)
	await process_frame
	await process_frame
	hide_ui(game)
	camera = Camera3D.new()
	camera.far = 250
	viewport.add_child(camera)
	var field: Node3D = game.arena.get_node("LevendigMiddenterrein")
	field.flag_node.visible = true
	await snapshot("veiligheidszone_overzicht",Vector3(59,58,-68),Vector3(0,0,0),56)
	await snapshot("boxen_doorgangen_coaches",Vector3(-26,16,-4),Vector3(-12,0.5,0),47)
	await snapshot("publiek_noordplein",Vector3(27,24,53),Vector3(0,0,30),58)
	viewport.free()
	print("INFIELD_UPDATE_CAPTURES_OK")
	quit()
