extends Node3D
## Existing Blender crowd poses, scoped to a single country's active equipment zone.
const Kit = preload("res://crowd_kit.gd")
const Themes = preload("res://rennersboxen/themes.gd")
const MEMBERS := [
	{"name":"Mecanicien1","role":"mechanic","variant":"staff_mechanic","at":Vector3(-2.72,0,-0.55),"yaw":0.0},
	{"name":"Mecanicien2","role":"mechanic","variant":"staff_mechanic","at":Vector3(2.72,0,0.28),"yaw":PI},
	{"name":"Verzorger","role":"carer","variant":"staff_mechanic_f","at":Vector3(-1.85,0,1.75),"yaw":0.0},
	{"name":"Trainer","role":"coach","variant":"staff_official_f","at":Vector3(1.85,0,1.35),"yaw":0.0},
	# The existing leaning pose puts hands +0.52 m forward and 1.07 m high.
	# Local z 2.43 therefore meets the actual glass rail at z 2.95 / world x -17.55.
	{"name":"Supporter1","role":"supporter","variant":"stand_m_rail","at":Vector3(-3.55,0,2.43),"yaw":0.0},
	{"name":"Supporter2","role":"supporter","variant":"stand_f_rail","at":Vector3(-2.55,0,2.43),"yaw":0.0},
	{"name":"Supporter3","role":"supporter","variant":"stand_m_rail","at":Vector3(2.55,0,2.43),"yaw":0.0},
	{"name":"Supporter4","role":"supporter","variant":"stand_f_rail","at":Vector3(3.55,0,2.43),"yaw":0.0},
]
const FLAG_ACCENTS := {"belgium":0.0,"netherlands":0.375,"france":0.125,"italy":0.625,"germany":0.0,"great_britain":0.125,"denmark":0.125,"australia":0.0,"new_zealand":0.25,"portugal":0.125,"united_states":0.125}
var kit: RefCounted
var country := ""
var actors: Array[Node3D] = []

func setup(box: Node3D, shared_kit: RefCounted) -> void:
	kit = shared_kit
	box.activity_changed.connect(set_active)
	configure(box.country,box.is_active())

func set_active(active: bool) -> void:
	visible = active

func configure(id: String, active: bool) -> void:
	visible = active
	if id==country:return
	country = id
	for child in get_children():
		remove_child(child)
		child.free()
	actors.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(country.hash())
	var shirt := Color(Themes.DATA[country].base)
	for member in MEMBERS:
		var actor := Node3D.new()
		actor.name = member.name
		actor.position = member.at
		actor.rotation.y = member.yaw
		actor.set_meta("role",member.role)
		actor.set_meta("country",country)
		actor.set_meta("shirt",shirt)
		add_child(actor)
		var look: Array = kit.staff_look(rng,shirt,FLAG_ACCENTS[country],0.16)
		var group: Dictionary = {}
		Kit.add_to_group(group,member.variant,Transform3D.IDENTITY,look)
		# Only 48 box people at most: keep their existing detailed mesh visible
		# from every racing camera, independently of grandstand LOD cutoffs.
		kit.emit_group(actor,group,member.name,[[0,0.0,0.0]])
		actors.append(actor)
		if member.role=="carer":_bidons(actor,shirt)
		if member.role=="coach":_stopwatch(actor)

func _solid(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mat.metallic = metallic
	return mat

func _bidons(parent: Node3D, color: Color) -> void:
	var carrier := Node3D.new()
	carrier.name = "Bidons"
	parent.add_child(carrier)
	# Two plainly visible sports bottles at the carer's relaxed hand/waist.
	for i in range(2):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.05
		mesh.height = 0.20
		mesh.radial_segments = 10
		var bottle := MeshInstance3D.new()
		bottle.name = "Bidon%d" % (i+1)
		bottle.mesh = mesh
		bottle.position = Vector3(-0.27 if i==0 else 0.27,0.49,0.06)
		bottle.material_override = _solid(color if i==0 else Color("e6e9e5"))
		carrier.add_child(bottle)
		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.022
		cap_mesh.bottom_radius = 0.028
		cap_mesh.height = 0.05
		cap_mesh.radial_segments = 8
		cap.mesh = cap_mesh
		cap.position = bottle.position+Vector3.UP*0.125
		cap.material_override = _solid(Color("172330"))
		carrier.add_child(cap)

func _stopwatch(parent: Node3D) -> void:
	# The Blender coach already carries a clipboard; add a small timing watch.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = 0.015
	mesh.radial_segments = 12
	var watch := MeshInstance3D.new()
	watch.name = "Stopwatch"
	watch.mesh = mesh
	watch.rotation.x = PI/2.0
	watch.position = Vector3(0.04,1.17,0.16)
	watch.material_override = _solid(Color("d9c473"),0.4)
	parent.add_child(watch)
