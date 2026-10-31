extends SceneTree
## Real game geometry in a GPU SubViewport, with controlled start-list fixtures.
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void:pass
	func _load_rider_config() -> void:
		rider_config = ConfigFile.new()
		rider_config_ready = true
		rider_config.set_value("player","country_kit","belgium")
		for i in range(1,8):rider_config.set_value("rider_%02d" % i,"country_kit",["netherlands","netherlands","netherlands","france","france","germany","italy"][i-1])

const OUTPUT := "res://verification/rennersboxen/"
var viewport: SubViewport
var camera: Camera3D
var game: Node3D

func _initialize() -> void:call_deferred("run_capture")

func hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control:node.visible = false
	for child in node.get_children():hide_ui(child)

func snapshot(file_name: String, position: Vector3, target: Vector3, size: float, orthogonal: bool = false) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthogonal else Camera3D.PROJECTION_PERSPECTIVE
	camera.position = position
	camera.look_at(target)
	camera.size = size
	camera.fov = size
	camera.make_current()
	for i in range(40):await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.save_png(OUTPUT+file_name+".png")==OK)
	print("CAPTURED "+file_name)

func run_capture() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	game = Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	hide_ui(game)
	await process_frame
	await process_frame
	game._set_menu_visible(false)
	hide_ui(game)
	# Physics is frozen for architectural captures; still place the racers on
	# their actual track coordinates instead of leaving them at world origin.
	game._update_visuals(0.0)
	game._update_boost_dog(0.0)
	for bike in game.bikes:assert(Vector2(bike.position.x,bike.position.z).length()>10.0)
	camera = Camera3D.new()
	camera.far = 250
	viewport.add_child(camera)
	await snapshot("zes_boxen_overzicht",Vector3(-24,12,0),Vector3(-14.6,0.8,0),42,true)
	var row: Node3D = game.arena.get_node("LevendigMiddenterrein/Rennersboxen")
	for crew in row.crews:
		for actor in crew.actors:
			var expected: Color = actor.get_meta("shirt")
			for node in actor.get_children():
				if node is MultiMeshInstance3D:
					var actual: Color = node.multimesh.get_instance_color(0)
					assert(absf(actual.r-expected.r)<0.005 and absf(actual.g-expected.g)<0.005 and absf(actual.b-expected.b)<0.005)
	print("CREW_GPU_COLORS_OK")
	var index: int = row.assigned_countries.find("belgium")
	var at: Vector3 = row.boxes[index].global_position
	await snapshot("belgische_box",at+Vector3(-8.5,3.3,3.8),at+Vector3(0,1.15,0),54)
	await snapshot("keldertrap",Vector3(4,11,-7),Vector3(0,-1.05,-0.3),53)
	game.race_mode = 4
	game._configure_peloton()
	await process_frame
	game._update_visuals(0.0)
	game._update_boost_dog(0.0)
	for bike in game.bikes:assert(Vector2(bike.position.x,bike.position.z).length()>10.0)
	await snapshot("achtervolging_twee_open",Vector3(-24,12,0),Vector3(-14.6,0.8,0),42,true)
	viewport.free()
	print("INFIELD_CAPTURES_OK")
	quit()
