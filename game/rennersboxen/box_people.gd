extends Node3D
## Existing Blender crowd poses, scoped to a single country's active equipment zone.
const Kit = preload("res://crowd_kit.gd")
const Themes = preload("res://rennersboxen/themes.gd")
const SUPPORTER_POSES := ["stand_m_cheer","stand_m_clap","stand_f_talk","stand_f_drink"]
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

func _member(label: String, role: String, variant: String, at: Vector3, yaw: float) -> Dictionary:
	return {"name":label,"role":role,"variant":variant,"at":at,"yaw":yaw}

func _lineup(rng: RandomNumberGenerator) -> Array[Dictionary]:
	# Stable per country: a refresh or reopening never shuffles people mid-race.
	var members: Array[Dictionary] = []
	var layout := _country_index()%3
	var mechanic_positions: Array = [
		[Vector3(-2.72,0,-0.55),Vector3(2.72,0,0.35)],
		[Vector3(-3.48,0,0.30),Vector3(2.72,0,-1.48)],
		[Vector3(-2.72,0,0.94),Vector3(3.47,0,-0.55)]
	][layout]
	for i in range(2):
		var at: Vector3 = mechanic_positions[i]+Vector3(rng.randf_range(-0.10,0.10),0,rng.randf_range(-0.08,0.08))
		var target := Vector3(-2.72 if i==0 else 2.72,0,0.20 if i==0 else -0.55)
		var yaw := atan2(target.x-at.x,target.z-at.z)
		members.append(_member("Mecanicien%d"%(i+1),"mechanic","staff_mechanic" if (i+layout)%2==0 else "staff_mechanic_f",at,yaw))
	var side := -1.0 if layout==1 else 1.0
	members.append(_member("Verzorger","carer","staff_mechanic_f" if layout!=2 else "stand_m_relaxed",Vector3(-side*rng.randf_range(1.55,1.85),0,rng.randf_range(1.50,1.75)),rng.randf_range(-0.45,0.45)))
	members.append(_member("Trainer","coach","staff_official_f" if layout==0 else "staff_official_m",Vector3(side*rng.randf_range(1.55,1.80),0,rng.randf_range(1.15,1.40)),rng.randf_range(-0.65,0.65)))
	# Two asymmetric clusters, with at least one leaning supporter on each side.
	var count := rng.randi_range(3,6)
	var starts := [rng.randf_range(-3.85,-3.55),rng.randf_range(1.85,2.05)]
	for i in range(count):
		var cluster := i%2
		var x: float = starts[cluster]+floori(i/2.0)*0.80+rng.randf_range(-0.06,0.06)
		var leaning := i<2
		var yaw := rng.randf_range(-0.12,0.12) if leaning else rng.randf_range(-0.38,0.38)
		var variant: String = Kit.RAIL[rng.randi_range(0,1)] if leaning else SUPPORTER_POSES[rng.randi_range(0,SUPPORTER_POSES.size()-1)]
		var z := 2.95-0.52*cos(yaw) if leaning else rng.randf_range(2.10,2.35)
		members.append(_member("Supporter%d"%(i+1),"supporter",variant,Vector3(x,0,z),yaw))
	return members

func _country_index() -> int:
	return Array(Themes.DATA.keys()).find(country)

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
	for member in _lineup(rng):
		var actor := Node3D.new()
		actor.name = member.name
		actor.position = member.at
		actor.rotation.y = member.yaw
		var leaning: bool = member.variant in Kit.RAIL
		var height := 1.0 if leaning else rng.randf_range(0.94,1.06)
		actor.scale = Vector3(rng.randf_range(0.95,1.05),height,1.0 if leaning else height)
		actor.set_meta("pose",member.variant)
		actor.set_meta("role",member.role)
		actor.set_meta("country",country)
		var top := shirt.lerp(Color.WHITE,rng.randf_range(0.0,0.10)) if rng.randf()<0.5 else shirt.darkened(rng.randf_range(0.0,0.12))
		actor.set_meta("shirt",top)
		add_child(actor)
		var look: Array = kit.staff_look(rng,top,FLAG_ACCENTS[country],rng.randf_range(0.08,0.42))
		var group: Dictionary = {}
		Kit.add_to_group(group,member.variant,Transform3D.IDENTITY,look)
		# Only 60 box people at most: keep their existing detailed mesh visible
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
