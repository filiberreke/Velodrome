extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
var viewport: SubViewport
var game: Screen
const FOLDER := "res://verification/pursuit_start"
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FOLDER + "/" + name + ".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.setup_panel.select_mode(1)
	game.setup_panel.pursuit_flow.next_step()
	game._confirm_start()
	game.broadcast_intro.finish()
	game.broadcast_intro.cancel()
	game.bikes[0].get_child(0).set_country_kit("belgium")
	game.bikes[1].get_child(0).set_country_kit("netherlands")
	game._update_visuals(0.0)
	game._set_race_hud_visible(false)
	game.camera.set_cull_mask_value(2, false)
	var gate: Node3D = game.pursuit_start.gates[0]
	var position := gate.global_position
	var basis := gate.global_basis
	game.camera.global_position = position + basis * Vector3(3.8, 2.8, 4.2)
	game.camera.look_at(position + basis * Vector3(0, .85, .15))
	game.camera.fov = 43.0
	await shot("01_held_on_track")
	game.camera.global_position = position + basis * Vector3(2.2, 1.7, 2.6)
	game.camera.look_at(position + basis * Vector3(0, 1.05, -.05))
	await shot("03_helper_detail")
	var opponent: Node3D = game.pursuit_start.gates[1]
	game.camera.global_position = opponent.global_position + opponent.global_basis * Vector3(3.8, 2.8, 4.2)
	game.camera.look_at(opponent.global_position + opponent.global_basis * Vector3(0, .85, .15))
	await shot("04_opponent_team")
	game.camera.global_position = position + basis * Vector3(3.8, 2.8, 4.2)
	game.camera.look_at(position + basis * Vector3(0, .85, .15))
	game._begin_riding()
	game.pursuit_start.update(game, 1.23)
	await shot("02_helpers_withdraw")
	print("PURSUIT_START_CAPTURES_OK")
	quit()
