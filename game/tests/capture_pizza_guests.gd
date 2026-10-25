extends SceneTree
## Genuine Godot GPU viewport captures, never mockups or Blender substitutes.
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
const OUTPUT := "res://verification/pizza_guests/"

func _initialize() -> void: call_deferred("capture_all")

func make_view(studio: bool) -> void:
	viewport = SubViewport.new(); viewport.size = Vector2i(1440,1050)
	viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new(); viewport.add_child(stage)
	if studio:
		var world := WorldEnvironment.new(); var env := Environment.new()
		env.background_mode = Environment.BG_COLOR; env.background_color = Color("d9ddd8")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.40
		world.environment = env; stage.add_child(world)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-42,-25,0)
		light.light_energy = 0.90; light.shadow_enabled = true; stage.add_child(light)
		var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(30,30)
		floor_mesh.mesh = plane; floor_mesh.position.y = -0.015
		var material := StandardMaterial3D.new(); var color := Image.create(2,2,false,Image.FORMAT_RGB8); color.fill(Color("bfc4b6"))
		material.albedo_texture = ImageTexture.create_from_image(color)
		floor_mesh.material_override = material; stage.add_child(floor_mesh)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 250; stage.add_child(camera); camera.make_current()

func snapshot(file_name: String, position: Vector3, target: Vector3, size: float) -> void:
	camera.position = position; camera.look_at(target,Vector3.UP); camera.size = size
	camera.make_current()
	for i in range(12): await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(OUTPUT+file_name+".png") == OK)
	print("SCREENSHOT "+file_name)

func hide_ui(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	if node is Control: node.visible = false
	for child in node.get_children(): hide_ui(child)

func capture_all() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	make_view(true)
	stage.add_child(preload("res://assets/people/pizza_vrienden_statafel.glb").instantiate())
	await snapshot("Pizza_vrienden_model",Vector3(0,2.4,6),Vector3(0,0.95,0),2.7)
	viewport.free()
	make_view(false)
	var game = preload("res://main.gd").new(); stage.add_child(game)
	game.set_process(false);game.set_physics_process(false);game._set_menu_visible(false);hide_ui(game)
	await process_frame; hide_ui(game)
	await snapshot("Pizzaoven_voorkant",Vector3(7.2,2.7,31.2),Vector3(7.2,1.4,36.5),4.2)
	await snapshot("Pizzaoven_aansluiting",Vector3(11.0,3.0,32.5),Vector3(7.2,1.6,36.2),4.0)
	await snapshot("Pizza_vrienden_op_pisteplein",Vector3(15.5,3.5,39.2),Vector3(9.5,1.0,36.9),5.3)
	var arena: Node3D = game.arena
	var details: Node3D = arena.get_node("TourBochtDetails")
	var dog: Node3D = details.get_node("ChihuahuaLasagne")
	var fan: Node3D = details.get_node("WoutSupporter")
	await snapshot("Chihuahua_lasagne_op_trap",dog.position-arena._outward(147.15)*2.5+Vector3.UP*0.9,dog.position+Vector3.UP*0.19,1.25)
	await snapshot("Supporter_WOUT",fan.position-arena._outward(152.4)*3.0+Vector3.UP*1.9,fan.position+Vector3.UP*1.5,4.2)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 58
	await snapshot("Tourbocht_vanaf_piste",arena._point(150,5.5)+Vector3.UP*5.0,(dog.position+fan.position)*0.5+Vector3.UP*0.55,8.5)
	viewport.free();print("PIZZA_SCREENSHOTS_OK");quit()
