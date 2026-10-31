@tool
extends Node3D
signal activity_changed(active: bool)
## One metre = one Godot unit. Front = local +Z.
## Reuses the game's Blender Bike meshes from res://assets/riders/.

const COUNTRIES := ["belgium", "netherlands", "france", "italy", "germany", "great_britain", "denmark", "australia", "new_zealand", "portugal", "united_states"]
const BOX_SIZE := Vector3(2.60, 2.10, 2.50)
const ZONE_SIZE := Vector2(8.60, 3.80)
const Themes = preload("res://rennersboxen/themes.gd")
const BIKE_SCENES := {"track": preload("res://assets/riders/velodrome_rider.glb"), "pursuit": preload("res://assets/riders/velodrome_pursuit.glb")}
const BIKE_PATHS := {"track":"res://assets/riders/velodrome_rider.glb", "pursuit":"res://assets/riders/velodrome_pursuit.glb"}

@export_enum("belgium", "netherlands", "france", "italy", "germany", "great_britain", "denmark", "australia", "new_zealand", "portugal", "united_states") var country: String = "belgium":
	set(value):
		if value not in COUNTRIES: return
		country = value
		_schedule_build()
@export_range(0.0, 1.0, 0.01) var curtain_open: float = 1.0:
	set(value):
		curtain_open = clampf(value, 0.0, 1.0)
		_update_curtains()
		if not is_instance_valid(_tween) or not _tween.is_running(): _set_activity(curtain_open>0.001)
@export_enum("track", "pursuit") var bike_variant: String = "track":
	set(value):
		if value not in BIKE_SCENES or value==bike_variant:return
		bike_variant = value
		_schedule_build()
@export var include_equipment: bool = true:
	set(value):
		include_equipment = value
		_schedule_build()
@export var include_barriers: bool = true:
	set(value):
		include_barriers = value
		_schedule_build()
@export var collision_enabled: bool = false:
	set(value):
		collision_enabled = value
		_schedule_build()

static var _materials: Dictionary = {}
static var _curtain_cache: Dictionary = {}
static var _bike_parts: Dictionary = {}
var _geometry: Node3D
var _exterior: Node3D
var _draw_target: Node3D
var _active := true
var _curtains: Array[MeshInstance3D] = []
var _build_pending := false
var _tween: Tween

func _ready() -> void:
	rebuild()

func _schedule_build() -> void:
	if is_inside_tree() and not _build_pending:
		_build_pending = true
		call_deferred("rebuild")

func set_country(id: String) -> bool:
	if id not in COUNTRIES: return false
	if country != id: country = id
	return true

func set_open(open: bool, seconds: float = 0.45) -> void:
	if _tween: _tween.kill()
	_set_activity(open)
	if seconds <= 0.0 or not is_inside_tree():
		curtain_open = 1.0 if open else 0.0
	else:
		_tween = create_tween()
		_tween.tween_property(self, "curtain_open", 1.0 if open else 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func is_active() -> bool:
	return _active

func _set_activity(active: bool) -> void:
	var changed := _active!=active
	_active = active
	if is_instance_valid(_exterior):_exterior.visible = active
	if changed:activity_changed.emit(active)

func _mat(hex: String, metal: float = 0.0) -> StandardMaterial3D:
	# Small shared palette: retain national colours, batch similar hardware finishes.
	if metal > 0.0:
		hex = "515b65" if Color(hex).v < 0.5 else "acb7c1"
		metal = 0.7
	elif hex in ["252c35","252e38","151c24","19212b","26313b","242f3b","131c2a","18212d","303c49"]:
		hex = "171c23"
	elif hex in ["e8e9e3","eeeee8"]:
		hex = "f1eee2"
	var key := hex + str(metal)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.metallic = metal
		m.roughness = 0.34 if metal > 0.0 else 0.86
		_materials[key] = m
	return _materials[key]

func _print(part: String) -> StandardMaterial3D:
	var key := country + "/" + part
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Themes.DATA[country][part]
		m.roughness = 0.88
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_materials[key] = m
	return _materials[key]

func _mesh(mesh: Mesh, pos: Vector3, material: Material, node_name: String = "Detail") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	n.name = node_name
	(_draw_target if is_instance_valid(_draw_target) else _geometry).add_child(n)
	return n

func _box(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, pos, material)

func _rod(a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = a.distance_to(b)
	m.radial_segments = 8
	var n := _mesh(m, (a+b)*0.5, material)
	var up := (b-a).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	n.basis = Basis(right, up, right.cross(up))
	return n

func _ball(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 6
	var n := _mesh(m, pos, material)
	n.scale = size
	return n

func _ensure_bike_parts() -> void:
	if _bike_parts.has(bike_variant):return
	# The live racer is an integrated Blender rig. Take only its actual Bike mesh,
	# retaining every surface/material and bind-position vertex, without the cyclist.
	var imported: Node3D = BIKE_SCENES[bike_variant].instantiate()
	var bike := imported.find_child("Bike",true,false) as MeshInstance3D
	assert(bike!=null and bike.skin!=null)
	var rear_bind := -1
	for i in bike.skin.get_bind_count():
		if bike.skin.get_bind_name(i)==&"wheel_r":rear_bind=i
	assert(rear_bind>=0)
	var parts: Array[Dictionary] = []
	for surface in bike.mesh.get_surface_count():
		var original := bike.mesh.surface_get_arrays(surface)
		var arrays := original.duplicate()
		# Clear skin attributes to use the existing geometry as a static parked bike.
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var wheel := _rear_wheel_surface(original,rear_bind)
		parts.append({"mesh":mesh,"wheel":wheel,"material":bike.get_active_material(surface)})
	_bike_parts[bike_variant] = parts
	imported.free()

func _rear_wheel_surface(arrays: Array, bind_index: int) -> ArrayMesh:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stride: int = bones.size()/vertices.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for face in range(0,indices.size(),3):
		var rear := true
		for j in range(3):
			var weight := 0.0
			for k in stride:
				var at: int = indices[face+j]*stride+k
				if bones[at]==bind_index:weight+=weights[at]
			if weight<0.999:rear=false
		if not rear:continue
		for j in range(3):
			var index := indices[face+j]
			st.set_normal(normals[index])
			st.add_vertex(vertices[index])
		triangles+=1
	if triangles==0:return null
	# Match the indexed source meshes before batching with complete bicycles.
	# Mixing unindexed stock wheels and indexed bikes drops the former's faces.
	st.index()
	return st.commit()

func _existing_bike_meshes(transform_here: Transform3D, wheels_only: bool = false) -> void:
	_ensure_bike_parts()
	for part in _bike_parts[bike_variant]:
		var mesh: Mesh = part.wheel if wheels_only else part.mesh
		if mesh==null:continue
		var n := _mesh(mesh,Vector3.ZERO,part.material,"RaceBikePart")
		n.transform = transform_here
		n.set_meta("source_asset",BIKE_PATHS[bike_variant])

func _wheel(center: Vector3) -> void:
	# Rear-wheel triangles come from the same Blender Bike mesh, at native scale.
	var basis := Basis(Vector3.UP,PI/2.0)
	_existing_bike_meshes(Transform3D(basis,center-basis*Vector3(0,0.335,-0.40)),true)

func _bike(at: Vector3, rollers: bool = false) -> void:
	var basis := Basis(Vector3.UP,PI/2.0)
	var origin := at-basis*Vector3(0,0,0.09)
	if rollers:
		# Race Blender model: wheelbase .98 m, tyre radius/hub height .335 m.
		# Three drums touch both tyres; pitch accounts for the two rear contact points.
		var rear_hub_y := 0.055+sqrt(pow(0.335+0.048,2)-pow(0.12,2))
		var front_hub_y := 0.055+0.335+0.048
		var pitch := asin((front_hub_y-rear_hub_y)/0.98)
		var tilt := Basis(Vector3.BACK,pitch)
		basis = tilt*basis
		origin = at+Vector3(0,(rear_hub_y+front_hub_y)*0.5,0)-basis*Vector3(0,0.335,0.09)
		var metal := _mat("b3bec8",0.7)
		for z in [-0.34,0.34]:
			_box(at+Vector3(0,0.025,z),Vector3(1.65,0.05,0.035),_mat("252e38"))
		for x in [-0.49*cos(pitch)-0.12,-0.49*cos(pitch)+0.12,0.49*cos(pitch)]:
			_rod(at+Vector3(x,0.055,-0.32),at+Vector3(x,0.055,0.32),0.048,metal)
	_existing_bike_meshes(Transform3D(basis,origin))

func _barrier(a: Vector3, b: Vector3) -> void:
	var m := _mat("aeb7bf",0.65)
	_rod(a+Vector3.UP,b+Vector3.UP,0.023,m)
	_rod(a+Vector3.UP*0.2,b+Vector3.UP*0.2,0.019,m)
	for i in range(9):
		var p := a.lerp(b,float(i)/8.0)
		_rod(p+Vector3.UP*0.20,p+Vector3.UP,0.009,m)
	for p in [a,b]:
		_rod(p,p+Vector3.UP,0.024,m)
		_rod(p+Vector3(0,0.035,-0.23),p+Vector3(0,0.035,0.23),0.022,m)

func _panel(pos: Vector3, width: float, height: float, yaw: float, material: Material) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width,height)
	_mesh(mesh,pos,material).rotation.y = yaw

func rebuild() -> void:
	_build_pending = false
	if not is_inside_tree(): return
	_curtains.clear()
	if is_instance_valid(_geometry):
		remove_child(_geometry)
		_geometry.free()
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)
	_draw_target = _geometry
	_exterior = Node3D.new()
	_exterior.name = "ExteriorEquipment"
	_geometry.add_child(_exterior)
	var silver := _mat("acb7c1",0.75)
	var inside := _mat("c4c6c5")
	var navy := _mat("16243c")
	var base: Color = _print("panel").albedo_texture.get_image().get_pixel(4,4)
	var frame := _mat(base.to_html(false))
	# Structural dimensions: outside faces x ±1.30, z ±1.25, top rail y 2.10.
	_box(Vector3(0,0.035,0),Vector3(2.60,0.07,2.50),_mat("323c44"))
	_box(Vector3(0,1.03,-1.22),Vector3(2.60,2.06,0.06),inside)
	_panel(Vector3(0,1.03,-1.255),2.60,2.06,PI,_print("panel"))
	for side in [-1.0,1.0]:
		_box(Vector3(side*1.27,1.03,0),Vector3(0.06,2.06,2.50),inside)
		_panel(Vector3(side*1.305,1.03,0),2.50,2.06,side*PI/2.0,_print("panel"))
		for z in [-1.23,1.23]: _rod(Vector3(side*1.28,0.04,z),Vector3(side*1.28,2.10,z),0.022,silver)
		_rod(Vector3(side*1.28,2.10,-1.23),Vector3(side*1.28,2.10,1.23),0.021,silver)
	_rod(Vector3(-1.30,2.10,1.26),Vector3(1.30,2.10,1.26),0.025,silver)
	# Bed long side parallel to opening; 2.00 x 0.85 m mattress.
	_box(Vector3(0,0.35,-0.63),Vector3(2.06,0.12,0.91),silver)
	_box(Vector3(0,0.455,-0.63),Vector3(2.00,0.14,0.85),navy)
	for x in [-0.93,0.93]:
		for z in [-1.0,-0.26]:_rod(Vector3(x,0.06,z),Vector3(x,0.32,z),0.035,silver)
	_ball(Vector3(-0.68,0.56,-0.63),Vector3(0.48,0.14,0.63),_mat("f1eee2"))
	_box(Vector3(0.72,0.56,-0.65),Vector3(0.35,0.07,0.64),_mat("4a5b77"))
	_box(Vector3(0.72,0.605,-0.65),Vector3(0.31,0.025,0.59),navy)
	_box(Vector3(0.60,0.13,-0.58),Vector3(0.55,0.22,0.45),_mat("303c49"))
	# Shelf top at 1.50 m, distinct from wheel rack above wall.
	_box(Vector3(0,1.47,-0.92),Vector3(2.28,0.06,0.52),silver)
	for x in [-0.94,0.94]:
		_rod(Vector3(x,1.22,-1.16),Vector3(x,1.44,-0.72),0.012,silver)
	for i in range(4):
		var x := -0.91+float(i)*0.22
		var bottle := _mat(["162f55","eeeee8","e5c321","1d6583"][i])
		_rod(Vector3(x,1.53,-0.92),Vector3(x,1.72,-0.92),0.055,bottle)
		_rod(Vector3(x,1.72,-0.92),Vector3(x,1.765,-0.92),0.027,_mat("151f2a"))
	for i in range(2):
		var hp := Vector3(0.41+i*0.48,1.61,-0.92)
		_ball(hp,Vector3(0.30,0.23,0.36),_mat("e8e9e3" if i==0 else "18212d"))
		for k in range(3):
			_box(hp+Vector3(-0.075+k*0.075,0.111,0),Vector3(0.025,0.012,0.17),_mat("26313b"))
	# Wheel rail: no canopy; wheels stand above the rear wall.
	if include_equipment:
		_draw_target = _exterior
		for x in [-1.13,1.13]:_rod(Vector3(x,2.10,-1.10),Vector3(x,2.62,-1.10),0.019,silver)
		_rod(Vector3(-1.15,2.29,-1.10),Vector3(1.15,2.29,-1.10),0.022,silver)
		for i in range(6):_wheel(Vector3(-0.95+float(i)*0.38,2.48,-1.10))
	_draw_target = _geometry
	_panel(Vector3(0,2.125,1.295),0.70,0.12,0,_print("header"))
	if include_equipment:
		_draw_target = _exterior
		_bike(Vector3(-2.72,0.0,0.20),true)
		_bike(Vector3(2.72,0.0,-0.20))
		_bike(Vector3(2.72,0.0,-0.92))
		for z in [-0.33,-0.81]:_box(Vector3(2.72,0.045,z),Vector3(1.55,0.09,0.035),silver)
		_box(Vector3(-1.85,0.21,0.98),Vector3(0.56,0.42,0.40),frame)
		for y in [0.04,0.38]:_box(Vector3(-1.85,y,0.98),Vector3(0.59,0.035,0.43),silver)
		_box(Vector3(-1.85,0.24,1.19),Vector3(0.12,0.05,0.015),silver)
		_box(Vector3(1.85,0.17,0.93),Vector3(0.50,0.34,0.42),_mat("242f3b"))
	_draw_target = _geometry
	if include_barriers:
		for start in [-4.2,-1.4,1.4]:_barrier(Vector3(start,0,-1.65),Vector3(start+2.8,0,-1.65))
		for side in [-1.0,1.0]:_barrier(Vector3(side*4.2,0,-1.65),Vector3(side*4.2,0,0.92))
	if collision_enabled: _build_collision()
	_merge_static(_geometry)
	_merge_static(_exterior)
	_exterior.visible = _active
	for i in range(2):
		var node := MeshInstance3D.new()
		node.name = "CurtainLeft" if i==0 else "CurtainRight"
		node.material_override = _print("curtain")
		_geometry.add_child(node)
		_curtains.append(node)
	_update_curtains()
	set_meta("footprint",ZONE_SIZE if include_equipment or include_barriers else Vector2(2.60,2.50))
	set_meta("bike_source",BIKE_PATHS[bike_variant])

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BoxCollision"
	_geometry.add_child(body)
	for item in [[Vector3(0,1.03,-1.22),Vector3(2.6,2.06,0.06)],
		[Vector3(-1.27,1.03,0),Vector3(0.06,2.06,2.5)],
		[Vector3(1.27,1.03,0),Vector3(0.06,2.06,2.5)],
		[Vector3(0,0.27,-0.63),Vector3(2.06,0.52,0.91)]]:
		var n := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = item[1]
		n.shape = shape
		n.position = item[0]
		body.add_child(n)

func _merge_static(parent: Node3D) -> void:
	# A material batch replaces hundreds of individual mesh draw calls.
	var groups: Dictionary = {}
	var originals: Array[Node] = []
	for n in parent.get_children():
		if n is MeshInstance3D:
			var material: Material = n.material_override
			if not groups.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(material)
				groups[material] = st
			groups[material].append_from(n.mesh,0,n.transform)
			originals.append(n)
	for n in originals:
		parent.remove_child(n)
		n.free()
	for material in groups:
		var n := MeshInstance3D.new()
		n.name = "StaticBatch"
		n.mesh = groups[material].commit()
		parent.add_child(n)

func _update_curtains() -> void:
	if _curtains.size()!=2: return
	for side in range(2):
		# Reuse the same pleated mesh; lateral scaling compresses the fabric at the posts.
		var key := str(side)
		if not _curtain_cache.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(48):
				for uv in [Vector2(float(i)/48.0,0),Vector2(float(i)/48.0,1),Vector2(float(i+1)/48.0,0),Vector2(float(i+1)/48.0,0),Vector2(float(i)/48.0,1),Vector2(float(i+1)/48.0,1)]:
					var x: float = uv.x*1.26
					var z: float = 1.285+sin(uv.x*TAU*10.0)*0.028
					st.set_uv(Vector2((float(side)+uv.x)*0.5,uv.y))
					st.add_vertex(Vector3(x,2.055-uv.y*2.015,z))
			st.generate_normals()
			_curtain_cache[key] = st.commit()
		var n := _curtains[side]
		n.mesh = _curtain_cache[key]
		var width := lerpf(1.26,0.18,curtain_open)
		n.scale.x = width/1.26
		n.position.x = -1.26 if side==0 else 1.26-width
