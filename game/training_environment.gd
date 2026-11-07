extends Node3D
## Separate training presentation. Never enters the race start/finish state machine.
const Kit := preload("res://crowd_kit.gd")
const Themes := preload("res://rennersboxen/themes.gd")
const CAMP := Vector3(-12.6, 0.0, -10.0)
var game: Node3D
var active := false
var distance := 0.0
var start_distance := 0.0
var saved: Array[Dictionary] = []
var camp: Node3D
var coach: Node3D
var mechanic: Node3D

func _ready() -> void:
	game = get_parent()
	name = "TrainingEnvironment"
	visible = false
	# Reuse the empty floor and safety strip, without copying race-day props.
	var infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	for floor_name in ["Middenterrein vloer", "Veiligheidszone naast de cote d azur"]:
		var floor_node: Node3D = infield.get_node(floor_name).duplicate()
		add_child(floor_node)
	camp = Node3D.new()
	camp.name = "EigenPloegtent"
	camp.position = CAMP
	add_child(camp)
	var outfit: Dictionary = game.player_appearance.resolve(game.get_player_appearance_base())
	var country: String = game.RaceCountries.from_kit(outfit)
	var colour := Color(Themes.DATA[country].base) if Themes.DATA.has(country) else Color("164e98")
	camp.set_meta("country", country)
	# One compact open-sided team canopy, no crowd or extra equipment stalls.
	for x in [-2.0, 2.0]:
		for z in [-2.0, 2.0]: _box(camp, Vector3(x, 1.25, z), Vector3(0.055, 2.5, 0.055), Color("b8c8d0"))
	var vertices := PackedVector3Array()
	var corners := [Vector3(-2.2, 2.5, -2.2), Vector3(2.2, 2.5, -2.2), Vector3(2.2, 2.5, 2.2), Vector3(-2.2, 2.5, 2.2)]
	for i in range(4):
		vertices.append(corners[i]); vertices.append(Vector3(0, 3.35, 0)); vertices.append(corners[(i + 1) % 4])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		if normal.y < 0.0: normal = -normal
		for j in range(3): normals.append(normal)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var roof := MeshInstance3D.new()
	roof.name = "Canopy"
	roof.mesh = mesh
	roof.material_override = _material(colour)
	camp.add_child(roof)
	_box(camp, Vector3(0, 2.34, 2.1), Vector3(4.4, 0.32, 0.08), colour)
	var sign := Label3D.new()
	sign.text = "EIGEN PLOEG · TRAINING"
	sign.position = Vector3(0, 2.35, 2.16)
	sign.pixel_size = 0.004
	sign.font_size = 45
	camp.add_child(sign)
	coach = _staff("Trainer", "coach", "staff_official_m", Vector3(-17.0, 0, -9.0), colour)
	mechanic = _staff("Mecanicien", "mechanic", "stand_m_relaxed", Vector3(-14.8, 0, -11.5), colour)
	# Locate the actual track point alongside the tent, independent of finish offset.
	var nearest := INF
	for metre in range(250):
		var point: Vector3 = game._at(float(metre), 1.18)
		var separation := Vector2(point.x - CAMP.x, point.z - CAMP.z).length_squared()
		if separation < nearest:
			nearest = separation
			start_distance = float(metre)
	distance = start_distance

func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _box(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _material(colour)
	parent.add_child(node)

func _staff(label: String, role: String, pose: String, at: Vector3, colour: Color) -> Node3D:
	var actor := Node3D.new()
	actor.name = label
	actor.position = at
	actor.rotation.y = -PI * 0.5 # Watch the rider on the western straight.
	actor.set_meta("role", role)
	add_child(actor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	var group := {}
	Kit.add_to_group(group, pose, Transform3D.IDENTITY, game.arena.crowd.staff_look(rng, colour, 0.0))
	game.arena.crowd.emit_group(actor, group, label, [[0, 0.0, 0.0]])
	return actor

func _hide(node: Node3D) -> void:
	saved.append({"node": node, "visible": node.visible})
	node.hide()

func enter() -> void:
	if active:
		distance = start_distance
		advance(0.0)
		return
	active = true
	distance = start_distance
	for person in get_tree().get_nodes_in_group("stadium_people"):
		if not is_ancestor_of(person): _hide(person)
	for path in ["LevendigMiddenterrein", "EuroMaxCyclingCommentaryBox", "VelodromeStadiumShow"]:
		var node: Node3D = game.arena.get_node_or_null(path)
		if node != null: _hide(node)
	for bike in game.bikes: _hide(bike)
	show()
	game.bikes[0].show()
	advance(0.0)

func leave() -> void:
	if not active: return
	active = false
	hide()
	for item in saved:
		if is_instance_valid(item.node): item.node.visible = item.visible
	saved.clear()

func advance(dt: float) -> void:
	if not active: return
	var page = game.setup_panel.ftp_page
	var live: bool = page.test.running() and page.fresh(page.now_s())
	var speed: float = clampf(game.trainer_speed_kmh / 3.6, 0.0, 35.0) if live else 0.0
	distance += speed * dt / game._path_metric(distance, 1.18)
	var bike: Node3D = game.bikes[0]
	var point: Vector3 = game._at(distance, 1.18)
	var forward: Vector3 = game._direction(distance, 1.18)
	bike.position = point + Vector3.UP * 0.10
	bike.rotation = Vector3(0, atan2(forward.x, forward.z), -0.18 * game._curve_factor(distance))
	var visual := bike.get_child(0)
	visual.call("set_victory", false)
	visual.call("pedal", dt, maxf(0.0, game.cadence) if live else 0.0, page.measured if live else 0.0)
	game.camera.position = point - forward * 7.0 + Vector3(9, 5, 0)
	game.camera.look_at(point + forward * 5.0 + Vector3.UP)
	game.camera.fov = 70.0
