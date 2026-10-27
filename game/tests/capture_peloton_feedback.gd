extends SceneTree
func _initialize() -> void: call_deferred("capture")
func snap(viewport: SubViewport, name: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://verification/peloton_feedback/"+name+".png")
func capture() -> void:
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification/peloton_feedback"))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=preload("res://main.gd").new()
	viewport.add_child(game); game.set_physics_process(false)
	game.setup_panel.select_mode(3); game._confirm_start()
	game.start_state="RACING"; game.clock=235.; game.watts=315.
	for i in range(game.rider_count):
		game.distances[i]=2380.+i*2.1
		game.speeds[i]=11.
		game.ai_power_w[i]=265.+i*8.
		game.x_ai.wprime[i]=game.x_ai.wmax[i]*(0.25+0.04*i)
		game.points_rules.points[i]=i*3
	game.points_rules.points[0]=8
	for i in range(20): game._update_visuals(0.1)
	game._update_hud()
	await snap(viewport,"points_hud")
	game.distances[0]+=250.
	game.points_rules.credits[0]+=1
	game.points_rules.points[0]+=20
	game._announce_race_event("RONDE GEWONNEN · +20 PUNTEN · TERUG IN HET PELOTON")
	game._update_visuals(0.1); game._update_hud()
	await snap(viewport,"lap_gain")
	game.race_mode=0; game.race_laps=25; game.rider_count=8
	game._configure_peloton()
	game.start_state="RACING"; game._set_menu_visible(false)
	for i in range(game.rider_count):
		game.distances[i]=2380.+i*2.1
		game.speeds[i]=11.; game.ai_power_w[i]=250.+i*10.
		game.x_ai.wprime[i]=game.x_ai.wmax[i]*(0.15+0.1*i)
	for i in range(10): game._update_visuals(0.1)
	game._update_hud()
	await snap(viewport,"scratch_hud")
	print("PELOTON_CAPTURE_OK")
	quit()
