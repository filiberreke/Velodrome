extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game := Game.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game._set_race_hud_visible(false)
	game.setup_panel.hide()
	for layer in game.find_children("*","CanvasLayer",true,false):
		layer.hide()
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	game.camera.current = true
	var line: Vector3 = game._at(0.0,1.18)
	game.camera.position = line + Vector3(19,12,22)
	game.camera.look_at(line + Vector3(-3,0.4,2))
	game.camera.fov = 68
	for i in range(10): await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://verification/track_bowl/")
	viewport.get_texture().get_image().save_png("res://verification/track_bowl/finish_line_straight.png")
	print("FINISH_LINE_CAPTURE_OK")
	game.queue_free()
	await process_frame
	quit()
