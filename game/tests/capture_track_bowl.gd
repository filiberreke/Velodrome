extends SceneTree
class NewTrack extends "res://main.gd":
	func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ProjectSettings.globalize_path("res://verification/track_bowl/")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400,900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	for version in ["before","after"]:
		var game = load("res://tests/track_bowl_before.gd").new() if version=="before" else NewTrack.new()
		viewport.add_child(game)
		game.set_physics_process(false)
		game._build_realistic_track()
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("dce5eb")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.75
		game.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50,-25,0)
		light.light_energy = 1.2
		game.add_child(light)
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.current = true
		for view in ["overview","entry"]:
			if view=="overview":
				camera.position = Vector3(65,61,77)
				camera.look_at(Vector3(0,1,0))
				camera.fov = 62.0
			else:
				camera.position = Vector3(35,11,12)
				camera.look_at(Vector3(10,2,43))
				camera.fov = 68.0
			for i in range(6): await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output+version+"_"+view+".png")
		game.queue_free()
		await process_frame
	print("TRACK_BOWL_CAPTURES_OK")
	quit()
