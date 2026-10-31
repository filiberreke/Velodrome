extends RefCounted
## Static, editable low-poly concessions. No collision or gameplay dependencies.
const FRIES: Texture2D = preload("res://assets/kiosks/chasse-patate-boarding.png")
const COFFEE: Texture2D = preload("res://assets/kiosks/kopwerk-koffie-boarding.png")
const GREEN := "07512d"
const YELLOW := "ffd019"
const BROWN := "3c2012"
const CREAM := "fff0d1"
const ORANGE := "ec7e24"
var materials := {}
var people_meshes := {}
var host: Node3D

func build(infield: Node3D) -> Array[Node3D]:
	host = infield
	var fries := _root("ChassePatate", Vector3(-5.5, 0, -27.5))
	_fries(fries)
	_terrace(fries, false)
	var coffee := _root("Kopwerk", Vector3(5.5, 0, -27.5))
	_coffee(coffee)
	_terrace(coffee, true)
	for root in [fries, coffee]:
		host.blockers.append([Vector2(root.position.x, root.position.z), 3.5])
		_batch_static(root)
	return [fries, coffee]

func _root(title: String, position: Vector3, parent: Node3D = null) -> Node3D:
	var root := Node3D.new()
	root.name = title; root.position = position
	(host if parent == null else parent).add_child(root)
	return root

func _mat(hex: String, metallic: bool = false) -> StandardMaterial3D:
	var key := hex + ("_metal" if metallic else "")
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.albedo_color = Color(hex)
	material.roughness = 0.44 if metallic else 0.85
	material.metallic = 0.55 if metallic else 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = material
	return material

func _texture(texture: Texture2D) -> StandardMaterial3D:
	var key := texture.resource_path
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = texture.resource_path.get_file().get_basename()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_repeat = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = material
	return material

func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material, title: String = "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape; node.position = pos; node.material_override = material
	if not title.is_empty(): node.name = title
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, metal: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	return _mesh(parent, mesh, pos, _mat(hex, metal))

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius; mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = height; mesh.radial_segments = 24; mesh.rings = 1
	return _mesh(parent, mesh, pos, _mat(hex))

func _surface(parent: Node3D, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, material: Material, title: String) -> MeshInstance3D:
	# Godot uses clockwise front faces. Match winding to supplied outward normals
	# so the cream counter and rim are lit on their visible side.
	for i in range(0, vertices.size(), 3):
		var face := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i])
		if face.dot(normals[i] + normals[i + 1] + normals[i + 2]) > 0.0:
			var vertex := vertices[i + 1]; vertices[i + 1] = vertices[i + 2]; vertices[i + 2] = vertex
			var normal := normals[i + 1]; normals[i + 1] = normals[i + 2]; normals[i + 2] = normal
			if not uvs.is_empty():
				var uv := uvs[i + 1]; uvs[i + 1] = uvs[i + 2]; uvs[i + 2] = uv
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	if not uvs.is_empty(): arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, mesh, Vector3.ZERO, material, title)

func _panel(parent: Node3D, pos: Vector3, width: float, texture: Texture2D, yaw: float = 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width * float(texture.get_height()) / float(texture.get_width()))
	var node := _mesh(parent, mesh, pos, _texture(texture), "Merkpaneel")
	node.rotation.y = yaw
	return node

func _ring(parent: Node3D, y: float, height: float, outer: float, inner: float, hex: String) -> void:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for i in range(48):
		var a: float = TAU * float(i) / 48.0; var b := TAU * float(i + 1) / 48.0
		for side in range(4):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var angle: float = lerpf(a, b, corner.x)
				var direction := Vector3(sin(angle), 0, cos(angle))
				var radius := outer if side == 0 else inner
				var elevation: float = y + (corner.y - 0.5) * height
				var normal := direction if side == 0 else -direction
				if side >= 2:
					radius = lerpf(inner, outer, corner.y)
					elevation = y + (height * 0.5 if side == 2 else -height * 0.5)
					normal = Vector3.UP if side == 2 else Vector3.DOWN
				vertices.append(direction * radius + Vector3.UP * elevation); normals.append(normal)
	_surface(parent, vertices, normals, PackedVector2Array(), _mat(hex), "Ring")

func _brand_band(parent: Node3D) -> void:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	var height := (TAU * 2.015 / 4.0) * float(COFFEE.get_height()) / float(COFFEE.get_width())
	for panel in range(4):
		for segment in range(24):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var u: float = (float(segment) + corner.x) / 24.0
				var angle: float = -PI * 0.25 + (float(panel) + u) * PI * 0.5
				var normal := Vector3(sin(angle), 0, cos(angle))
				vertices.append(normal * 2.015 + Vector3.UP * (2.94 + (corner.y - 0.5) * height))
				normals.append(normal); uvs.append(Vector2(u, 1.0 - corner.y))
	_surface(parent, vertices, normals, uvs, _texture(COFFEE), "RondomKopwerkLogo")

func _handle(parent: Node3D, z: float, tube: float, hex: String) -> void:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for i in range(28):
		for j in range(8):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var a: float = -PI * 0.5 + PI * (float(i) + corner.x) / 28.0
				var t: float = TAU * (float(j) + corner.y) / 8.0
				var outward := Vector3(cos(a), sin(a), 0)
				var normal := outward * cos(t) + Vector3.BACK * sin(t)
				vertices.append(Vector3(1.8 + 1.32 * cos(a), 2.0 + 1.32 * sin(a), z) + normal * tube)
				normals.append(normal)
	_surface(parent, vertices, normals, PackedVector2Array(), _mat(hex), "KoffiekopOor")

func _cup(parent: Node3D, pos: Vector3, coffee: bool) -> void:
	_cylinder(parent, pos + Vector3.UP * 0.08, 0.055, 0.16, CREAM, 0.078)
	_cylinder(parent, pos + Vector3.UP * 0.165, 0.08, 0.018, BROWN if coffee else YELLOW)
	_box(parent, pos + Vector3(0, 0.085, 0.065), Vector3(0.04, 0.045, 0.012), ORANGE if coffee else GREEN)

func _fries_cone(parent: Node3D, pos: Vector3) -> void:
	_cylinder(parent, pos + Vector3.UP * 0.12, 0.018, 0.24, CREAM, 0.10)
	for i in range(7):
		var a: float = float(i) * 2.4
		var stick := _box(parent, pos + Vector3(cos(a) * 0.055, 0.27, sin(a) * 0.055), Vector3(0.032, 0.18, 0.032), "f4c13b")
		stick.rotation.z = cos(a) * 0.2

func _staff_mesh(variant: String, shirt: String, accent: String, lod: int = 0) -> Mesh:
	var key := variant + shirt + accent + str(lod)
	if people_meshes.has(key): return people_meshes[key]
	var source: Mesh = host.crowd.mesh(variant, lod)
	var mesh := ArrayMesh.new()
	var colors := ["e5b58d", "633c23", shirt, "273038", "29231e", "1c1714", CREAM, "804034", accent, "222324", shirt, "bfc6c8", "ca6c68", "51351e"]
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var vertex_colors := PackedColorArray()
		for point in uv: vertex_colors.append(Color(colors[clampi(int(point.x * 16), 0, colors.size() - 1)]).srgb_to_linear())
		arrays[Mesh.ARRAY_COLOR] = vertex_colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	people_meshes[key] = mesh
	return mesh

func _person(parent: Node3D, pos: Vector3, yaw: float, coffee: bool, seated: bool = false) -> void:
	if not materials.has("people"):
		var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true; material.roughness = 0.9
		materials["people"] = material
	var mesh := _staff_mesh("seat_f_drink" if seated else "staff_vendor_m", CREAM if coffee else GREEN, ORANGE if coffee else YELLOW, 1 if seated else 0)
	var node := _mesh(parent, mesh, pos, materials["people"], "Gast" if seated else "Verkoper")
	node.rotation.y = yaw

func _fries(parent: Node3D) -> void:
	_box(parent, Vector3(0, 0.50, 0), Vector3(4.4, 1, 2.65), GREEN)
	_box(parent, Vector3(0, 1.95, -1.3), Vector3(4.4, 1.9, 0.12), YELLOW)
	for x in [-2.2, 2.2]:
		_box(parent, Vector3(x, 1.95, -0.20), Vector3(0.12, 1.9, 2.3), YELLOW)
		_box(parent, Vector3(x, 1.65, 1.2), Vector3(0.12, 1.3, 0.12), GREEN)
	for x in range(12): _box(parent, Vector3(-2.0 + float(x) * 0.365, 0.48, 1.335), Vector3(0.018, 0.94, 0.025), "064027")
	_box(parent, Vector3(0, 1.06, 1.44), Vector3(4.8, 0.12, 0.68), "bec8ca", true)
	var roof := _box(parent, Vector3(0, 2.85, -0.05), Vector3(4.85, 0.18, 3.15), GREEN)
	roof.rotation.x = -0.12
	_box(parent, Vector3(0, 2.64, 1.55), Vector3(4.95, 0.17, 0.28), YELLOW)
	_panel(parent, Vector3(0, 3.10, 1.78), 4.6, FRIES)
	_panel(parent, Vector3(0, 1.95, -1.37), 4.15, FRIES, PI)
	_panel(parent, Vector3(-2.27, 1.72, -0.15), 2.35, FRIES, -PI * 0.5)
	_panel(parent, Vector3(2.27, 1.72, -0.15), 2.35, FRIES, PI * 0.5)
	var roof_logo := _panel(parent, Vector3(0, 2.97, -0.1), 3.2, FRIES)
	roof_logo.rotation.x = -PI * 0.5 - 0.12
	# Fryer and hood sit behind the counter, rather than replacing the vendor.
	_box(parent, Vector3(-1.25, 0.96, -0.20), Vector3(1.30, 0.42, 0.74), "abb7bc", true)
	for x in [-1.55, -0.96]:
		_box(parent, Vector3(x, 1.19, -0.2), Vector3(0.48, 0.035, 0.55), "393b35")
		_box(parent, Vector3(x, 1.23, 0.13), Vector3(0.055, 0.065, 0.39), "798281", true)
	_box(parent, Vector3(-1.25, 2.20, -0.35), Vector3(1.55, 0.25, 0.95), "c8d1d2", true)
	_box(parent, Vector3(-1.25, 2.52, -0.60), Vector3(0.35, 0.54, 0.32), "a2afb3", true)
	for x in [-1.0, -0.5, 0.0]: _fries_cone(parent, Vector3(x, 1.12, 1.53))
	for i in range(3):
		var x := 1.30 + float(i) * 0.18
		_cylinder(parent, Vector3(x, 1.28, 1.48), 0.065, 0.31, ["c33824", YELLOW, CREAM][i])
		_cylinder(parent, Vector3(x, 1.47, 1.48), 0.025, 0.09, CREAM)
	_person(parent, Vector3(0.40, 0, 0.72), 0.0, false)

func _coffee(parent: Node3D) -> void:
	_ring(parent, 0.52, 1.0, 1.88, 1.30, BROWN)
	_ring(parent, 0.09, 0.16, 1.94, 1.27, ORANGE)
	var counter := _root("VrijeRondomToog", Vector3.ZERO, parent)
	_ring(counter, 1.08, 0.14, 2.20, 1.30, CREAM)
	var pillar := _root("CentraleDaksteun", Vector3.ZERO, parent)
	_cylinder(pillar, Vector3(0, 1.75, 0), 0.25, 3.50, BROWN)
	parent.set_meta("roof_support_count", 1)
	parent.set_meta("counter_outer_radius", 2.20)
	parent.set_meta("service_open_min_y", 1.15)
	parent.set_meta("service_open_max_y", 2.35)
	_cylinder(parent, Vector3(0, 2.94, 0), 2.0, 1.18, BROWN)
	_brand_band(parent)
	_ring(parent, 3.58, 0.14, 2.08, 1.86, CREAM)
	_cylinder(parent, Vector3(0, 3.59, 0), 1.89, 0.08, BROWN)
	# Crop the existing logo area via UVs; the PNG remains unchanged.
	var roof_vertices := PackedVector3Array(); var roof_normals := PackedVector3Array(); var roof_uv := PackedVector2Array()
	for point in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		roof_vertices.append(Vector3((point.x - 0.5) * 2.25, 3.638, (point.y - 0.5) * 2.7))
		roof_normals.append(Vector3.UP); roof_uv.append(Vector2(point.x * 0.30, point.y))
	_surface(parent, roof_vertices, roof_normals, roof_uv, _texture(COFFEE), "DaklogoKopwerk")
	_handle(parent, 0, 0.18, CREAM)
	_handle(parent, 0.14, 0.075, ORANGE)
	_handle(parent, -0.14, 0.075, ORANGE)
	_box(parent, Vector3(0.0, 1.20, -0.66), Vector3(0.95, 0.80, 0.50), "727a7b", true)
	_box(parent, Vector3(0, 1.62, -0.66), Vector3(1.01, 0.07, 0.55), "d6d7ce", true)
	for x in [-0.24, 0.24]:
		_box(parent, Vector3(x, 1.22, -0.35), Vector3(0.11, 0.09, 0.22), "222526")
		_cup(parent, Vector3(x, 0.99, -0.28), true)
	_box(parent, Vector3(0.90, 1.19, -0.63), Vector3(0.28, 0.67, 0.35), "303639")
	_cylinder(parent, Vector3(0.9, 1.68, -0.63), 0.18, 0.30, "643f26", 0.24)
	_cylinder(parent, Vector3(0.9, 1.85, -0.63), 0.25, 0.04, "222526")
	for x in [-0.45, 0.0, 0.45]: _cup(parent, Vector3(x, 1.16, 1.72), true)
	_person(parent, Vector3(-0.35, 0, 0.72), 0.0, true)

func _chair(parent: Node3D, position: Vector3, yaw: float, color: String) -> void:
	var chair := _root("Stoel", position, parent); chair.rotation.y = yaw
	chair.set_meta("terrace_chair", true)
	_box(chair, Vector3(0, 0.45, 0), Vector3(0.46, 0.075, 0.46), color)
	_box(chair, Vector3(0, 0.78, -0.24), Vector3(0.46, 0.53, 0.065), color)
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]: _box(chair, Vector3(x, 0.22, z), Vector3(0.045, 0.44, 0.045), color)

func _terrace(parent: Node3D, coffee: bool) -> void:
	var spots := [Vector3(-3.8, 0, 0), Vector3(3.8, 0, 0), Vector3(-3.65, 0, 3.7), Vector3(3.65, 0, 3.7), Vector3(0, 0, 4.6), Vector3(0, 0, -4.5)]
	if coffee: spots[1].x = 4.7 # Keep the parasol clear of the large cup handle.
	var colors := [CREAM, BROWN, ORANGE] if coffee else [YELLOW, GREEN]
	for i in range(6):
		var table := _root("Tafel%02d" % (i + 1), spots[i], parent)
		table.set_meta("terrace_table", true)
		_cylinder(table, Vector3(0, 0.73, 0), 0.59, 0.075, "ae7842")
		_cylinder(table, Vector3(0, 0.36, 0), 0.055, 0.72, "394044")
		_cylinder(table, Vector3(0, 0.035, 0), 0.29, 0.07, "394044")
		var parasol := _root("Parasol", Vector3.ZERO, table)
		_cylinder(parasol, Vector3(0, 1.13, 0), 0.028, 2.26, "b5b3a4")
		for sector in range(8):
			var a: float = TAU * float(sector) / 8.0; var b := TAU * float(sector + 1) / 8.0
			var peak := Vector3(0, 2.50, 0)
			var left := Vector3(sin(a) * 1.22, 2.13, cos(a) * 1.22)
			var right := Vector3(sin(b) * 1.22, 2.13, cos(b) * 1.22)
			var normal := (right - peak).cross(left - peak).normalized()
			if normal.y < 0.0: normal = -normal
			_surface(parasol, PackedVector3Array([peak, right, left, left, right, right - Vector3.UP * 0.12, left, right - Vector3.UP * 0.12, left - Vector3.UP * 0.12]), PackedVector3Array([normal, normal, normal, normal, normal, normal, normal, normal, normal]), PackedVector2Array(), _mat(colors[sector % colors.size()]), "Parasolvlak")
		for seat in range(3):
			var angle: float = TAU * float(seat) / 3.0 + float(i % 2) * 0.5
			var position := Vector3(sin(angle), 0, cos(angle)) * 0.97
			_chair(table, position, angle + PI, colors[(seat + i) % colors.size()])
			_person(table, position, angle + PI, coffee, true)
		if coffee: _cup(table, Vector3(0.29, 0.77, 0.15), true)
		else: _fries_cone(table, Vector3(0.29, 0.77, 0.15))
		host.blockers.append([Vector2(parent.position.x + spots[i].x, parent.position.z + spots[i].z), 1.65])

func _batch_static(root: Node3D) -> void:
	# Merge by material so the terraces do not add hundreds of individual draw calls.
	var groups := {}
	var pending: Array[Node] = [root]
	var sources: Array[MeshInstance3D] = []
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh != null: sources.append(node)
	for source in sources:
		var transform: Transform3D = root.global_transform.affine_inverse() * source.global_transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		for surface in range(source.mesh.get_surface_count()):
			var material: Material = source.material_override if source.material_override != null else source.mesh.surface_get_material(surface)
			var key: int = material.get_instance_id()
			if not groups.has(key):
				groups[key] = {"material": material, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uv": PackedVector2Array(), "colors": PackedColorArray()}
			var group: Dictionary = groups[key]
			var arrays: Array = source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for n in range(indices.size() if not indices.is_empty() else vertices.size()):
				var i: int = indices[n] if not indices.is_empty() else n
				group["vertices"].append(transform * vertices[i])
				group["normals"].append((normal_basis * normals[i]).normalized())
				group["uv"].append(uv[i] if uv.size() == vertices.size() else Vector2.ZERO)
				group["colors"].append(colors[i] if colors.size() == vertices.size() else Color.WHITE)
	for source in sources: source.free()
	var index := 0
	for group in groups.values():
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group["vertices"]; arrays[Mesh.ARRAY_NORMAL] = group["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = group["uv"]; arrays[Mesh.ARRAY_COLOR] = group["colors"]
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh(root, mesh, Vector3.ZERO, group["material"], "StaticBatch%02d" % index)
		index += 1
	root.set_meta("geometry_batches", index)
