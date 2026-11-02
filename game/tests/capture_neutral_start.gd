extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var folder := "res://verification/neutral_start"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game := Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.setup_panel.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	game.broadcast_intro.cancel()
	game._begin_riding()
	game.watts = 300.0
	for tick in range(200): game.neutral_start.step(game, 0.1)
	for tick in range(30): game._update_visuals(0.1)
	game._update_hud()
	for tick in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(folder + "/neutral_lap.png")
	while game.start_state == "NEUTRAL":
		game.neutral_start.step(game, 0.1)
		game._update_visuals(0.1)
	game._update_visuals(0.1)
	game._update_hud()
	game._update_countdown_display()
	for tick in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(folder + "/flying_start.png")
	print("NEUTRAL_CAPTURES_OK")
	quit()
