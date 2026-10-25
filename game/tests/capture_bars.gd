extends SceneTree
## Genuine Godot GPU viewport captures, never mockups or Blender substitutes.
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
const OUTPUT := "res://verification/bars/"

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
	assert(DisplayServer.get_name() != "headless","GPU display required for real screenshots")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for title in ["SjampanjeBar","PursoetBar"]:
		make_view(true)
		var packed: PackedScene = load("res://scenes/bars/"+title+".tscn")
		stage.add_child(packed.instantiate())
		var size := 6.8 if title=="SjampanjeBar" else 5.1
		var target := Vector3(0,2.10,0) if title=="SjampanjeBar" else Vector3(0,1.45,0)
		await snapshot(title+"_voor",Vector3(-6,4.1,-8),target,size)
		await snapshot(title+"_achter",Vector3(-6,4.1,8),target,size)
		viewport.free()
	# Two actual-scene galleries, left rear and right front, no image compositing.
	for title in ["SjampanjeBar","PursoetBar"]:
		make_view(true); viewport.size = Vector2i(1600,850)
		var packed: PackedScene = load("res://scenes/bars/"+title+".tscn")
		var spacing := 3.7 if title=="SjampanjeBar" else 2.1
		for index in range(2):
			var bar := packed.instantiate() as Node3D; stage.add_child(bar)
			bar.position.x = -spacing if index==0 else spacing
			if index==1: bar.rotation.y = PI
		var target := Vector3(0,2.1,0) if title=="SjampanjeBar" else Vector3(0,1.5,0)
		await snapshot(title+"_voor_en_achter",Vector3(0,3.8,-13),target,7.8 if title=="SjampanjeBar" else 4.8)
		viewport.free()
	make_view(true)
	for entry in [["sjampanje_tooguitbater",-0.8],["sjampanje_plateauuitbater",0.8]]:
		var actor := load("res://assets/bars/hosts/"+entry[0]+".glb").instantiate() as Node3D
		stage.add_child(actor); actor.position.x = entry[1]; actor.rotation.y = PI
	await snapshot("Sjampanje_uitbaters",Vector3(0,1.7,-6),Vector3(0,0.95,0),3.0)
	viewport.free()
	make_view(false)
	var game = preload("res://main.gd").new(); stage.add_child(game)
	game.set_process(false); game.set_physics_process(false); game._set_menu_visible(false); hide_ui(game)
	await process_frame; hide_ui(game)
	await snapshot("Noordplein_voorkant",Vector3(-4,19,18),Vector3(-2.0,1,37),31)
	await snapshot("Noordplein_pistekant",Vector3(0,24,59),Vector3(-2,1,36.5),35)
	await snapshot("Pursoet_zuidplein",Vector3(4,9,-8),Vector3(-7,1,-16),17)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 82
	await snapshot("Noordbocht_boarding",Vector3(8,9.2,45),Vector3(0,8.8,60),30)
	viewport.free()
	print("BARS_SCREENSHOTS_OK"); quit()
