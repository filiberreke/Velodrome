extends SceneTree
## Genuine Godot GPU viewport captures, never mockups or Blender substitutes.
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
const OUTPUT := "res://verification/stef_boarding/"

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
	make_view(false); viewport.size = Vector2i(2400,1100)
	var game = preload("res://main.gd").new();stage.add_child(game)
	game.set_process(false);game.set_physics_process(false);game._set_menu_visible(false);hide_ui(game)
	await process_frame;hide_ui(game)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE;camera.fov = 58
	await snapshot("Noordbocht_volledig",Vector3(0,19,8),Vector3(0,8,57),30)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var arena: Node3D = game.arena
	var panels: Array = arena.get_node("NoordbochtSponsors").get_meta("panels")
	var found := {}
	for panel in panels:
		var file: String = panel["texture"].get_file()
		if file not in ["eerlijke-stefs-donker.png","sjampanje-groen.png"] or found.has(file):continue
		found[file]=true
		var centre: float = (panel["start"]+panel["end"])*0.5
		var target: Vector3 = arena._point(centre,9.1)+Vector3.UP*0.62
		await snapshot("Stef_licht_donker_licht" if file.begins_with("eerlijke") else "Sjampanje_licht_groen_licht",target-arena._outward(centre)*12+Vector3.UP*1.6,target,6.0)
	for entry in [["Wielerpraat_bocht",PI*game.RADIUS*0.5],["Peloton_rechte_lijn",(PI*game.RADIUS+125.0)*0.5]]:
		var centre: float = entry[1]
		var target: Vector3 = arena._point(centre,9.1)+Vector3.UP*0.62
		await snapshot(entry[0],target-arena._outward(centre)*12+Vector3.UP*1.8,target,6.0)
	print("NORTH_PANELS "+str(panels.size()))
	viewport.free();print("STEF_SCREENSHOTS_OK");quit()
