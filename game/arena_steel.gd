extends RefCounted
## Shared, static steelwork batches. Unit boxes keep GPU geometry reusable.
var batches := {}
var materials := {}

func material(key: String, color: String, metallic := 0.65, glow := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = 0.43
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = glow
	materials[key] = m
	batches[key] = []

func box(key: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	batches[key].append(Transform3D(basis.scaled_local(size), center))

func beam(key: String, a: Vector3, b: Vector3, width: float, depth := -1.0) -> void:
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z).normalized()
	if x.length_squared() < 0.01: x = Vector3.RIGHT
	box(key, (a + b) * 0.5, Vector3(width, width if depth < 0.0 else depth, a.distance_to(b)), Basis(x, z.cross(x), z))

func flush(parent: Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	for key in batches:
		var poses: Array = batches[key]
		if poses.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = poses.size()
		for i in poses.size(): mm.set_instance_transform(i, poses[i])
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.multimesh = mm
		node.material_override = materials[key]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
