extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.setup_panel.select_mode(7)
	game.setup_panel.time_trial_distance.select(1)
	game._confirm_start()
	game.broadcast_intro.finish()
	game.start_state = "RACING"
	game.running = true
	game.clock = 47.821
	game.distances[0] = 625.0
	game.speeds[0] = 14.5
	game.watts = 428.0
	game.pursuit_half_crossings[0] = [11.320, 20.412, 29.581, 38.750, 47.821]
	game.time_trial_reference_kind = "last"
	game.time_trial_reference = {"splits": [11.550, 20.200, 29.800, 38.900, 48.191, 57.4, 66.5, 75.8]}
	game._update_hud()
	game._update_visuals(0.0)
	for i in range(6): await RenderingServer.frame_post_draw
	var output := "res://verification/solo_time_trial/"
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output + "hud.png")
	print("SOLO_HUD_CAPTURE_OK")
	game.free()
	quit()
