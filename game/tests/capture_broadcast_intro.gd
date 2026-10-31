extends SceneTree
class CaptureGame extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(0)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var choice := 2 if "team" in args else (1 if "pursuit" in args else 0)
	var prefix: String = ["scratch", "pursuit", "team"][choice]
	var output := "res://verification/intro_tour_v4/"
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var game := CaptureGame.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.setup_panel.select_mode(choice)
	if choice == 2 and "four" in args: game.setup_panel.team_options.teammates.select(1)
	game._confirm_start()
	assert(game.broadcast_intro.active, "Capture did not enter intro")
	game._update_visuals(0.0)
	var intro = game.broadcast_intro
	var b: float = intro.tour_start()
	var samples := [1.0, b, b+2.0, b+3.0, b+4.0, b+5.0, b+6.0, b+7.0, b+8.0, b+9.0, b+10.0, b+11.0, intro.duration-0.01]
	if choice > 0: samples.insert(1, 8.5)
	if "quick" in args: samples = [5.6, 8.0, b+3.0, b+5.5, b+7.5, b+10.0, b+12.0]
	if "turns" in args: samples = [b+5.5, b+6.5, b+8.5, b+9.5, b+10.0]
	for time in samples:
		intro.elapsed = time; intro.advance(0.0)
		game._update_visuals(0.0)
		for i in range(3): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(output + "%s_%05.2f.jpg" % [prefix, time], 0.9)
	if "video" in args:
		var frames: String = output + prefix + "_frames/"
		DirAccess.make_dir_recursive_absolute(frames)
		intro.elapsed = 0.0
		var first_frame := int((b + 7.5) * 24) if "tail" in args else 0
		for frame in range(first_frame, int(intro.duration * 24) + 1):
			intro.elapsed = minf(float(frame) / 24.0, intro.duration - 0.00001); intro.advance(0.0)
			game._update_visuals(0.0)
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_jpg(frames + "%04d.jpg" % frame, 0.84)
	intro.cancel()
	if "podium" in args:
		var podium: Node3D = game.arena.get_node("LevendigMiddenterrein/Podium")
		game.camera.global_position = podium.global_transform * Vector3(0, 3.3, 6.0)
		game.camera.look_at(podium.global_transform * Vector3(0, 1.35, -0.2))
		game.camera.fov = 43.0
		for i in range(3): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output + "Podium_sponsorachtergrond.png")
	if "settings" in args:
		viewport.size = Vector2i(1920, 1080)
		var settings = game.get_node("GameSettings")
		settings.appearance_tabs.current_tab = 1
		settings.panel_root.show()
		for i in range(3): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(output + "instellingen.jpg", 0.9)
	viewport.free()
	print("INTRO_REFRESH_CAPTURE_OK")
	quit()
