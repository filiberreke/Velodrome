extends RefCounted
# Velodrome 250 - crowd kit.
# Loads the Blender-made people (assets/crowd/crowd_people.glb), hands out per-person looks and
# builds MultiMeshes per (area, variant, level of detail). All people share ONE ShaderMaterial,
# so the whole crowd is a few draw calls per area and reacts to `excitement` together.

const PEOPLE_GLB: PackedScene = preload("res://assets/crowd/crowd_people.glb")
const PROPS_GLB: PackedScene = preload("res://assets/crowd/infield_props.glb")
const CROWD_SHADER: Shader = preload("res://crowd.gdshader")

const SEATED := ["seat_m_relaxed", "seat_f_clap", "seat_m_cheer", "seat_f_phone", "seat_m_lean",
	"seat_f_cheer", "seat_m_crossed", "seat_f_drink", "seat_m_point"]
# relative frequency of each seated pose (relaxed people are the majority)
const SEATED_WEIGHTS := [5.0, 3.0, 1.2, 2.0, 2.5, 1.0, 2.5, 2.0, 0.8]
const STANDING := ["stand_m_relaxed", "stand_f_drink", "stand_m_cheer", "stand_f_phone", "stand_m_clap",
	"stand_f_talk", "stand_m_drink", "stand_f_relaxed"]
const RAIL := ["stand_m_rail", "stand_f_rail"]

const SHIRTS := ["1f3a68", "c8382f", "f2f2ee", "2b2d33", "f4b833", "3b8f5a", "6aa5d8", "ef7a2d",
	"8c4f9e", "d9d9d2", "1d6fb8", "e3c84a", "a03a52", "4a5560", "f08ca0", "2f9c9a"]

var meshes := {}
var props := {}
var material: ShaderMaterial

func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = CROWD_SHADER
	_collect(PEOPLE_GLB.instantiate(), meshes)
	_collect(PROPS_GLB.instantiate(), props)

func _collect(root: Node, into: Dictionary) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			into[String(n.name)] = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	root.free()

func mesh(variant: String, lod: int) -> Mesh:
	return meshes.get("%s_lod%d" % [variant, lod], null)

func prop(name_text: String) -> Mesh:
	return props.get(name_text, null)

func pick_weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var x := rng.randf() * total
	for i in range(weights.size()):
		x -= float(weights[i])
		if x <= 0.0:
			return i
	return weights.size() - 1

# A random everyday look: shirt colour + (skin, hair, trousers, accent) in custom data.
func random_look(rng: RandomNumberGenerator) -> Array:
	var shirt := Color(SHIRTS[rng.randi() % SHIRTS.size()])
	shirt = shirt.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.12)
	var custom := Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
	return [shirt, custom]

# Look for staff: fixed top colour, chosen accent (0..1 index into the shader's accent palette).
func staff_look(rng: RandomNumberGenerator, top: Color, accent_index: float, bottom_index: float = 0.15) -> Array:
	return [top, Color(rng.randf(), rng.randf(), bottom_index, accent_index)]

# Builds one MultiMeshInstance3D. Transforms are made relative to the node position so the
# visibility range is measured to the middle of the group.
func multimesh(parent: Node3D, mesh_res: Mesh, xforms: Array, looks: Array, label: String,
		vis_begin: float = 0.0, vis_end: float = 0.0) -> MultiMeshInstance3D:
	if mesh_res == null or xforms.is_empty():
		return null
	var centre := Vector3.ZERO
	for t in xforms:
		centre += (t as Transform3D).origin
	centre /= float(xforms.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh_res
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		var t: Transform3D = xforms[i]
		t.origin -= centre
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, looks[i][0])
		mm.set_instance_custom_data(i, looks[i][1])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.add_to_group("stadium_people")
	node.multimesh = mm
	node.position = centre
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		node.visibility_range_end = vis_end
		node.visibility_range_end_margin = 2.0
	if vis_begin > 0.0:
		node.visibility_range_begin = vis_begin
		node.visibility_range_begin_margin = 2.0
	parent.add_child(node)
	return node

# Groups people (variant -> [xforms], [looks]) and emits near/far LOD MultiMeshes.
# lods: e.g. [[0, 0.0, 22.0], [1, 22.0, 0.0]]  (lod, visible from, visible until; 0 = no limit)
func emit_group(parent: Node3D, group: Dictionary, label: String, lods: Array) -> int:
	var count := 0
	for variant in group.keys():
		var data: Array = group[variant]
		for l in lods:
			multimesh(parent, mesh(variant, int(l[0])), data[0], data[1], "%s %s L%d" % [label, variant, int(l[0])], float(l[1]), float(l[2]))
		count += (data[0] as Array).size()
	return count

static func add_to_group(group: Dictionary, variant: String, xform: Transform3D, look: Array) -> void:
	if not group.has(variant):
		group[variant] = [[], []]
	group[variant][0].append(xform)
	group[variant][1].append(look)

func set_excitement(value: float) -> void:
	material.set_shader_parameter("excitement", clampf(value, 0.0, 1.0))
