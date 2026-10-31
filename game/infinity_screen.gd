extends Node3D
## Suspended, double-faced oval LED ring. Public Texture2D content API is ready
## for a future SubViewport without coupling display content to race rules.
const Steel := preload("res://arena_steel.gd")
const SEGMENTS := 320
const BOTTOM := 13.0
const HEIGHT := 2.6
const THICKNESS := 0.60
const WIDTH_SCALE := 7.0 / 11.0
const LENGTH_SCALE := 0.39
var arena: Node3D
var display_materials: Array[ShaderMaterial] = []
var perimeter := 0.0

func point(u: float, inset := 0.0) -> Vector3:
	var p: Vector3 = arena._point(u * 250.0, -7.0)
	var n: Vector3 = arena._outward(u * 250.0)
	return Vector3(p.x * WIDTH_SCALE - n.x * inset, BOTTOM, p.z * LENGTH_SCALE - n.z * inset)

func set_content(texture: Texture2D) -> void:
	if texture == null: return
	for material in display_materials:
		material.set_shader_parameter("content_texture", texture)
		material.set_shader_parameter("content_aspect", float(texture.get_width()) / maxf(1.0, float(texture.get_height())))

func build(owner_arena: Node3D) -> void:
	arena = owner_arena
	name = "InfinityScreen"
	arena.add_child(self)
	var kit := Steel.new()
	kit.material("RingFrame", "263440")
	kit.material("PanelSpines", "4b5a68")
	kit.material("HoistCables", "8b969e")
	kit.material("HoistMotors", "404b56")
	kit.material("TurquoiseEdge", "4ed6d9", 0.0, 0.45)
	kit.material("GoldEdge", "f2c05e", 0.0, 0.35)
	for i in SEGMENTS:
		var u := float(i) / SEGMENTS
		var v := float(i + 1) / SEGMENTS
		var a := point(u)
		var b := point(v)
		perimeter += a.distance_to(b)
		for inset in [0.0, THICKNESS]:
			var p := point(u, inset)
			var q := point(v, inset)
			for h in [-0.12, HEIGHT + 0.12]:
				kit.beam("RingFrame", p + Vector3.UP * h, q + Vector3.UP * h, 0.18, 0.22)
			for h in [-0.06, HEIGHT + 0.06]:
				var n: Vector3 = arena._outward(u * 250.0) * (0.12 if inset == 0.0 else -0.12)
				kit.beam("TurquoiseEdge" if h < 0 else "GoldEdge", p + n + Vector3.UP * h, q + n + Vector3.UP * h, 0.045)
		# Underside cabinet closure with ventilation slots between cross ribs.
		kit.beam("RingFrame", a.lerp(point(u, THICKNESS), 0.5) - Vector3.UP * 0.1, b.lerp(point(v, THICKNESS), 0.5) - Vector3.UP * 0.1, THICKNESS, 0.10)
		if i % 4 == 0:
			for h in [0.0, HEIGHT]: kit.beam("PanelSpines", a + Vector3.UP * h, point(u, THICKNESS) + Vector3.UP * h, 0.09)
			kit.beam("PanelSpines", point(u, THICKNESS * 0.5), point(u, THICKNESS * 0.5) + Vector3.UP * HEIGHT, 0.08)
			for vent in [-0.22, 0.0, 0.22]:
				kit.box("PanelSpines", a.lerp(point(u, THICKNESS), 0.5) + Vector3(vent, -0.165, 0), Vector3(0.06, 0.018, 0.27))
	# Twelve paired wire-rope suspensions, clevises, and hoists at the service ring.
	for i in 12:
		var u := (float(i) + 0.5) / 12.0
		var p := point(u, THICKNESS * 0.5) + Vector3.UP * (HEIGHT + 0.2)
		var top := point(u)
		top.y = 24.0
		for side in [-0.16, 0.16]:
			kit.beam("HoistCables", p + Vector3(side, 0, 0), top + Vector3(side, 0, 0), 0.032)
		kit.box("HoistMotors", top - Vector3.UP * 0.3, Vector3(0.6, 0.42, 0.42))
		kit.box("PanelSpines", p, Vector3(0.5, 0.16, 0.5))
	kit.flush(self)
	make_display(false)
	make_display(true)
	set_content(preload("res://assets/boarding/velodrome-boarding.png"))

func make_display(inner: bool) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var distance := 0.0
	var total := 0.0
	for i in SEGMENTS: total += point(float(i) / SEGMENTS, THICKNESS if inner else 0.0).distance_to(point(float(i + 1) / SEGMENTS, THICKNESS if inner else 0.0))
	for i in range(SEGMENTS + 1):
		var u := float(i) / SEGMENTS
		var p := point(u, THICKNESS if inner else 0.0)
		if i > 0: distance += p.distance_to(point(float(i - 1) / SEGMENTS, THICKNESS if inner else 0.0))
		var normal: Vector3 = arena._outward(u * 250.0) * (-1.0 if inner else 1.0)
		# Reverse inner UV traversal so artwork reads correctly from the infield.
		var x := total - distance if inner else distance
		vertices.append_array(PackedVector3Array([p, p + Vector3.UP * HEIGHT]))
		normals.append_array(PackedVector3Array([normal, normal]))
		uv.append_array(PackedVector2Array([Vector2(x, 1), Vector2(x, 0)]))
		if i < SEGMENTS:
			var j := i * 2
			indices.append_array(PackedInt32Array([j,j+2,j+1,j+1,j+2,j+3]) if inner else PackedInt32Array([j,j+1,j+2,j+1,j+3,j+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://infinity_screen.gdshader")
	mat.set_shader_parameter("screen_height", HEIGHT)
	mat.set_shader_parameter("panel_pitch", total / roundf(total / (HEIGHT * 3.0)))
	display_materials.append(mat)
	var node := MeshInstance3D.new()
	node.name = "InnerLED" if inner else "OuterLED"
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
