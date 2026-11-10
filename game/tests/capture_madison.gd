extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass

func _initialize() -> void: call_deferred("capture")

func snapshot(name: String) -> void:
	for i in range(5): await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://verification/madison/" + name + ".png")
	assert(error == OK)
	print("CAPTURED ", name)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://verification/madison")
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.setup_panel.select_mode(4)
	game.madison_progress.advanced_unlocked = false
	game.setup_panel.refresh_madison_difficulty()
	await snapshot("01_training_menu")
	game.madison_progress.advanced_unlocked = true
	game.setup_panel.refresh_madison_difficulty()
	game.setup_panel.madison_difficulty.select(1)
	game.setup_panel.madison_count.select(1)
	await snapshot("04_unlocked_options")
	game._confirm_start()
	game.broadcast_intro.finish()
	game._begin_riding()
	game.broadcast_intro.holding_chase = false
	game.clock = 10.0
	game.distances.assign([20.0, 20.0])
	game.speeds.assign([12.0, 10.0]); game.baseline_speed = 12.0
	game.madison.step(game, 0.1)
	game._madison_button("capture", true)
	game.madison.step(game, game.madison.grab_seconds)
	game.madison.step(game, game.madison.sling_seconds * 0.6)
	game._update_visuals(1.0)
	game._update_hud()
	await snapshot("02_advanced_peak")
	var centre: Vector3 = (game.bikes[0].global_position + game.bikes[1].global_position) * 0.5
	var forward: Vector3 = game.bikes[0].global_basis.z.normalized()
	var side: Vector3 = (game.bikes[1].global_position - game.bikes[0].global_position).normalized()
	game.camera.global_position = centre + forward * 3.0 + side * 3.0 + Vector3.UP * 2.0
	game.camera.look_at(centre + Vector3.UP * 1.0, Vector3.UP)
	game.camera.fov = 45.0
	await snapshot("05_animated_hand_contact")
	game._madison_button("capture", false)
	game.madison.step(game, 0.7)
	game._update_visuals(1.0 / 60.0)
	game._update_hud()
	await snapshot("03_release")
	game.free()
	print("MADISON_CAPTURES_OK")
	quit()
