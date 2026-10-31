extends SubViewportContainer
const Visual = preload("res://rider_visual.gd")
const Appearance = preload("res://player_appearance.gd")
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var rider
var back_view := false
var active := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(400, 480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("10253c")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.6
	stage.add_child(world)
	for angle in [Vector3(-35, -35, 0), Vector3(-20, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angle
		light.light_energy = 0.8
		stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.95
	stage.add_child(camera)
	camera.make_current()
	_update_camera()
	set_process(false)

func show_configuration(config: Dictionary) -> void:
	if rider == null:
		rider = Visual.new()
		Appearance.prepare_rider(rider, config)
		stage.add_child(rider)
		var bike := rider.rig_scene.find_child("Bike", true, false) as MeshInstance3D
		if bike != null: bike.visible = false
	else:
		Appearance.apply_to_rider(rider, config)

func set_back_view(back: bool) -> void:
	back_view = back
	_update_camera()

func show_identity(entry: Dictionary) -> void:
	if rider != null: rider.free()
	rider = Visual.new()
	rider.set_meta("rider_index", int(entry.profile))
	rider.set_meta("body_shapes", entry.morphs)
	rider.set_meta("jersey_config", entry.jersey)
	Appearance.prepare_rider(rider, entry.jersey)
	stage.add_child(rider)
	var bike := rider.rig_scene.find_child("Bike", true, false) as MeshInstance3D
	if bike != null: bike.visible = false

func _update_camera() -> void:
	if camera == null: return
	camera.position = Vector3(0, 2.7, -3.5) if back_view else Vector3(0, 1.05, 3.5)
	camera.look_at(Vector3(0, 0.92, 0.12), Vector3.UP)

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	if rider != null and active: rider.call("pedal", delta, 50.0, 100.0)
