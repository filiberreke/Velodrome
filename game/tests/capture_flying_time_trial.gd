extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
var viewport: SubViewport
var game: Screen
const FOLDER := "res://verification/flying_time_trial"
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FOLDER + "/" + name + ".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.setup_panel.select_mode(7)
	game.setup_panel.time_trial_start.select(1)
	await shot("settings")
	game._confirm_start()
	game.broadcast_intro.finish()
	game.broadcast_intro.cancel()
	game._begin_riding()
	game.watts = 500.0
	game.speeds[0] = 14.0
	for marker in [200, 150, 100, 50]:
		game.distances[0] = 250.0 - marker + 0.01
		for tick in range(30): game._update_visuals(0.1)
		game._update_hud()
		game._update_countdown_display()
		await shot("remaining_%d" % marker)
	game.distances[0] = 0.0
	game._finish_flying_start()
	for tick in range(30): game._update_visuals(0.1)
	game._update_hud()
	game._update_countdown_display()
	await shot("go")
	game._reset()
	game.setup_panel.select_mode(9)
	var page = game.setup_panel.records_page
	page.mode_choice.select(2)
	page.start_choice.select(1)
	page.refresh()
	await shot("records")
	print("FLYING_TIME_TRIAL_CAPTURES_OK")
	quit()
