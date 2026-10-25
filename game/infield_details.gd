extends Node3D
# Velodrome 250 - beta.16.13: lively infield ("middenterrein").
# Blender-made people and props (assets/crowd/*.glb, sources in assets/source_blender/crowd).
#  - fan zone with food truck, stalls, bar, coffee bike, tables, benches, parasols, string lights
#  - team pits in the four rider colours, mechanics at work stands
#  - finish zone with officials, photographers, TV camera and the flag official
#  - the flag official (female) only appears in the LAST LAP and waves when riders reach the line
# Coordinates: right straight x = +18 (finish at z = -34.2, riders travel towards -Z), left x = -18.

const CrowdKit := preload("res://crowd_kit.gd")
const FLAG_SCENE: PackedScene = preload("res://assets/crowd/flag_official.glb")
const SPONSOR: Texture2D = preload("res://wielerpraat.jpg")
const LAP := 250.0
const GLASS_OFFSET := -0.45
const NEAR_M := 20.0                      # detailed people closer than this, light figures further away
const TEAM_COLOURS := ["eac736", "35ad77", "268cd3", "df504b"]   # same as the four riders
const TEAM_NAMES := ["JIJ", "TIJDRIJDER", "SPRINTER", "AANVALLER"]

var crowd: RefCounted                      # set by arena.gd (shared CrowdKit)
var game: Node3D
var rng := RandomNumberGenerator.new()
var people := {}                           # cell key -> {variant -> [[xforms], [looks]]}
var blockers: Array = []                   # [Vector2 centre, radius] for random placement
var bulbs: Array[Transform3D] = []
var flag_node: Node3D
var flag_anim: AnimationPlayer
var flag_ready := &""
var flag_wave := &""
var flag_state := ""
var wave_timer := 0.0
var finished_seen := 0
var stone: StandardMaterial3D
var steel: StandardMaterial3D
var dark: StandardMaterial3D
var blue: StandardMaterial3D

# ------------------------------------------------------------------ helpers
func _mat(col: String, rough: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col)
	m.roughness = rough
	m.metallic = metallic
	return m

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.position = pos
	o.material_override = mat
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(self if parent == null else parent).add_child(o)
	return o

func _box(pos: Vector3, dims: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = dims
	return _mesh(b, pos, mat, parent)

func _cylinder(pos: Vector3, radius: float, height: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	return _mesh(c, pos, mat, parent)

func _yaw_to(dir: Vector3) -> float:
	# Blender figures and props face model +Z.
	return atan2(dir.x, dir.z)

func _at(s: float, offset: float) -> Vector3:
	var p: Vector3 = game.call("_at", s, offset)
	p.y = 0.0
	return p

func _prop(name_text: String, pos: Vector3, yaw: float, recolour: Dictionary = {}, block_r: float = 0.0) -> Node3D:
	var mesh: Mesh = crowd.call("prop", name_text)
	var node := Node3D.new()
	node.name = name_text
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	if mesh == null:
		push_warning("Velodrome infield: prop ontbreekt: " + name_text)
		return node
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(i)
		if m != null and recolour.has(m.resource_name) and m is StandardMaterial3D:
			var dup: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			dup.albedo_color = Color(recolour[m.resource_name])
			mi.set_surface_override_material(i, dup)
	node.add_child(mi)
	if block_r > 0.0:
		blockers.append([Vector2(pos.x, pos.z), block_r])
	return node

func _label(parent: Node3D, text: String, pos: Vector3, size: int = 64, colour: Color = Color.WHITE, yaw: float = 0.0, outline: Color = Color("0b1a2d")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 10
	l.outline_modulate = outline
	l.modulate = colour
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	parent.add_child(l)
	return l

func _cell_key(p: Vector3) -> String:
	return "%d_%d" % [int(floor(p.x / 20.0)), int(floor(p.z / 20.0))]

func _person(variant: String, pos: Vector3, yaw: float, look: Array = []) -> void:
	if look.is_empty():
		look = crowd.call("random_look", rng)
	var key := _cell_key(pos)
	if not people.has(key):
		people[key] = {}
	CrowdKit.add_to_group(people[key], variant, Transform3D(Basis(Vector3.UP, yaw), pos), look)

func _free_spot(p: Vector3, r: float) -> bool:
	for b in blockers:
		if Vector2(p.x, p.z).distance_to(b[0]) < float(b[1]) + r:
			return false
	return true

func _random_standing() -> String:
	return CrowdKit.STANDING[rng.randi() % CrowdKit.STANDING.size()]

func _group_around(centre: Vector3, count: int, radius: float, variants: Array = []) -> void:
	# A small group of people facing the middle (chatting around a table, a stall, ...)
	var start := rng.randf() * TAU
	for i in range(count):
		var a := start + TAU * float(i) / float(count) + rng.randf_range(-0.25, 0.25)
		var p := centre + Vector3(cos(a), 0.0, sin(a)) * (radius + rng.randf_range(-0.08, 0.12))
		var v: String = variants[i % variants.size()] if not variants.is_empty() else _random_standing()
		_person(v, p, _yaw_to(centre - p) + rng.randf_range(-0.3, 0.3))

# ------------------------------------------------------------------ build
func _ready() -> void:
	game = get_parent().get_parent()
	if crowd == null:
		crowd = CrowdKit.new()
	rng.seed = 1613
	stone = _mat("a9aca3")
	steel = _mat("b8c8d0", 0.39, 0.45)
	dark = _mat("11212e")
	blue = _mat("162e4c")
	_build_floor()
	_build_tunnel()
	_build_south_plaza()
	_build_north_plaza()
	_build_team_pits()
	_build_finish_zone()
	_build_ends()
	_build_rail_public()
	_build_wanderers()
	_emit_people()
	_emit_bulbs()
	_build_flag_official()

func _surface(verts: PackedVector3Array, label: String, colour: String, y_lift: float = 0.0) -> void:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	var mat := _mat(colour)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(mesh, Vector3(0, y_lift, 0), mat).name = label

func _build_floor() -> void:
	# Capsule-shaped infield floor right up to the track (also fills both bends).
	var steps := 240
	var y := -0.03
	var floor_v := PackedVector3Array()
	var strip := PackedVector3Array()
	for i in range(steps):
		var s0 := LAP * float(i) / float(steps)
		var s1 := LAP * float(i + 1) / float(steps)
		var a: Vector3 = _at(s0, 0.05)
		var b: Vector3 = _at(s1, 0.05)
		for v in [Vector3(0, y, 0), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z)]:
			floor_v.append(v)
		# light standing strip along the glass boarding
		var a0: Vector3 = _at(s0, GLASS_OFFSET)
		var a1: Vector3 = _at(s0, -3.2)
		var b0: Vector3 = _at(s1, GLASS_OFFSET)
		var b1: Vector3 = _at(s1, -3.2)
		for v in [a0, b0, a1, a1, b0, b1]:
			strip.append(Vector3(v.x, y + 0.012, v.z))
	_surface(floor_v, "Middenterrein vloer", "5b7772")
	_surface(strip, "Staanstrook langs het glas", "b3ad9c")
	# Two warm-tiled plazas with joints.
	var tile := _mat("b3a481")
	var joint := _mat("9d8f6e")
	for zc in [-19.5, 19.5]:
		_box(Vector3(0, -0.012, zc), Vector3(25.0, 0.04, 22.0), tile)
		for k in range(-5, 6):
			_box(Vector3(0, 0.009, zc + float(k) * 2.0), Vector3(25.0, 0.004, 0.03), joint)
			_box(Vector3(float(k) * 2.27, 0.009, zc), Vector3(0.03, 0.004, 22.0), joint)

func _build_tunnel() -> void:
	# Kept from beta.16.12.5: central rider tunnel with stairs, rails and portal.
	_box(Vector3(0, 0.065, 0), Vector3(8.6, 0.12, 12.4), stone)
	_box(Vector3(0, -0.008, 0), Vector3(4.55, 0.025, 9.4), dark)
	var step_mat := _mat("babcb9")
	var nose_mat := _mat("f5dfab")
	for i in range(9):
		var z: float = -4.0 + float(i) * 0.85
		var h: float = 0.05 + float(i) * 0.075
		_box(Vector3(0, h - 0.035, z), Vector3(3.7, 0.12, 0.76), step_mat)
		_box(Vector3(0, h + 0.028, z - 0.31), Vector3(3.7, 0.012, 0.045), nose_mat)
	_box(Vector3(0, 1.10, 5.12), Vector3(4.9, 2.05, 0.14), dark)
	_box(Vector3(0, 2.23, 5.12), Vector3(5.45, 0.3, 0.35), blue)
	for x in [-2.55, 2.55]:
		_box(Vector3(x, 1.10, 5.12), Vector3(0.33, 2.15, 0.4), steel)
		for z in [-3.7, -1.6, 0.5, 2.6, 4.7]:
			_cylinder(Vector3(x, 0.65, z), 0.038, 1.3, steel)
		_box(Vector3(x, 1.31, 0.5), Vector3(0.06, 0.075, 9.1), steel)
	var sign := Label3D.new()
	sign.text = "TUNNEL  •  EXIT"
	sign.font_size = 42
	sign.pixel_size = 0.003
	sign.position = Vector3(0, 2.42, 5.25)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	blockers.append([Vector2(0, 0.5), 6.6])

func _stall(pos: Vector3, yaw: float, title: String, canopy: String, cloth: String, merch: bool = false) -> Node3D:
	var node := _prop("stall_tent", pos, yaw, {"canopy_a": canopy, "counter_cloth": cloth, "banner": cloth}, 2.3)
	_label(node, title, Vector3(0, 2.55, 1.62), 72, Color.WHITE)
	if merch:
		var rack := _prop("merch_rack", Vector3.ZERO, 0.0)
		remove_child(rack)
		node.add_child(rack)
		rack.position = Vector3(0, 0, -0.6)
	# vendor behind the counter
	var behind: Vector3 = node.transform * Vector3(rng.randf_range(-0.6, 0.6), 0, 0.30)
	_person("staff_vendor_f" if rng.randf() < 0.5 else "staff_vendor_m", behind, yaw,
		crowd.call("staff_look", rng, Color("f2f2ee"), rng.randf(), 0.13))
	# queue / customers in front
	var n := rng.randi_range(2, 4)
	for i in range(n):
		var p: Vector3 = node.transform * Vector3(rng.randf_range(-1.0, 1.0), 0, 2.15 + float(i) * 0.75)
		_person(_random_standing(), p, yaw + PI + rng.randf_range(-0.35, 0.35))
	return node

func _high_table(pos: Vector3, people_count: int) -> void:
	_prop("high_table", pos, rng.randf() * TAU, {"canopy_a": ["ef8736", "268cd3", "df504b", "35ad77"][rng.randi() % 4]}, 0.5)
	_group_around(pos, people_count, 0.72, ["stand_f_drink", "stand_m_drink", "stand_f_talk", "stand_m_relaxed"])

func _bench(pos: Vector3, yaw: float) -> void:
	var node := _prop("picnic_bench", pos, yaw, {}, 1.2)
	# seated people on both benches, facing the table (benches at local z = +-0.62)
	for side in [-1.0, 1.0]:
		for x in [-0.55, 0.45]:
			if rng.randf() < 0.8:
				var p: Vector3 = node.transform * Vector3(x + rng.randf_range(-0.1, 0.1), 0.0, side * 0.62)
				var v: String = ["seat_m_relaxed", "seat_f_drink", "seat_f_phone", "seat_m_crossed", "seat_f_clap"][rng.randi() % 5]
				_person(v, p, yaw + (PI if side > 0.0 else 0.0))

func _light_line(a: Vector3, b: Vector3) -> void:
	# Festoon lights: a sagging cable with warm bulbs.
	var n := int(a.distance_to(b) / 0.65)
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var p := a.lerp(b, t) + Vector3.DOWN * (sin(t * PI) * 0.55)
		bulbs.append(Transform3D(Basis.IDENTITY, p))
		var seg := CylinderMesh.new()
		seg.top_radius = 0.006
		seg.bottom_radius = 0.006
		seg.height = prev.distance_to(p)
		seg.radial_segments = 4
		var mi := _mesh(seg, (prev + p) * 0.5, dark)
		var dir := (p - prev).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		mi.basis = Basis(side, dir, side.cross(dir))
		prev = p

func _build_south_plaza() -> void:
	var z0 := -19.5
	preload("res://branded_kiosks.gd").new().build(self)
	_stall(Vector3(9.4, 0, z0 + 2.5), -PI * 0.5, "MERCH", "1d6fb8", "0b1a2d", true)
	# Keep the other food stalls, with space for the two new six-table terraces.
	preload("res://north_bars.gd").new().build_south(self)
	_stall(Vector3(8.5, 0, -9.0), -PI * 0.5, "SNACKS", "2a9d55", "16492d")
	for bx in [-4.5, 0.0, 4.5]:
		_bench(Vector3(bx, 0, z0 + 7.0), 0.0)
	_plaza_lights(z0, 5.3)
	for p in [Vector3(-11.3, 0, z0 - 5.2), Vector3(11.3, 0, z0 - 5.2), Vector3(-6.8, 0, z0 + 1.0), Vector3(7.0, 0, z0 + 6.0)]:
		_prop("trash_bin", p, rng.randf() * TAU, {}, 0.45)
	for p in [Vector3(-2.0, 0, z0 + 10.3), Vector3(2.0, 0, z0 + 10.3)]:
		_prop("planter", p, 0.0, {}, 0.8)

func _plaza_lights(z0: float, top: float = 4.2) -> void:
	for p in [Vector3(-11.6, 0, z0 - 9.5), Vector3(11.6, 0, z0 - 9.5), Vector3(-11.6, 0, z0 + 9.5), Vector3(11.6, 0, z0 + 9.5)]:
		var pole := _prop("light_pole", p, 0.0, {}, 0.3)
		pole.scale.y = top / 4.2
	_light_line(Vector3(-11.6, top, z0 - 9.5), Vector3(11.6, top, z0 + 9.5))
	_light_line(Vector3(11.6, top, z0 - 9.5), Vector3(-11.6, top, z0 + 9.5))
	_light_line(Vector3(-11.6, top, z0 - 9.5), Vector3(11.6, top, z0 - 9.5))
	_light_line(Vector3(-11.6, top, z0 + 9.5), Vector3(11.6, top, z0 + 9.5))

func _build_north_plaza() -> void:
	var z0 := 19.5
	var bar := _prop("bar_counter", Vector3(0, 0, z0 + 7.0), PI, {"canopy_a": "f2c05e"}, 2.6)
	_label(bar, "BAR  •  BIER  •  FRIS", Vector3(0, 2.25, 0.2), 70, Color("f2c05e"))
	for x in [-1.2, 0.6]:
		_person("staff_vendor_m" if x < 0.0 else "staff_vendor_f", bar.transform * Vector3(x, 0, 0.05), PI,
			crowd.call("staff_look", rng, Color("1d2430"), 0.0, 0.1))
	for i in range(6):
		_person(_random_standing(), Vector3(-1.8 + float(i) * 0.75, 0, z0 + 5.4 - rng.randf() * 0.4), PI + rng.randf_range(-0.3, 0.3))
	for p in [Vector3(-4.0, 0, z0 + 2.6), Vector3(4.0, 0, z0 + 2.6), Vector3(-4.0, 0, z0 - 2.2), Vector3(4.0, 0, z0 - 2.2)]:
		_prop("parasol", p, rng.randf() * TAU, {"parasol_a": ["f2c05e", "4ed6d9", "ef8736", "e0473c"][rng.randi() % 4]}, 0.3)
		_high_table(p, rng.randi_range(2, 4))
	var cart := _prop("coffee_cart", Vector3(-9.6, 0, z0 - 4.0), PI * 0.5, {}, 1.6)
	_label(cart, "ESPRESSO", Vector3(0.35, 1.0, 0.40), 40, Color("2b1d16"), 0.0, Color("ffffff"))
	_person("staff_vendor_f", cart.transform * Vector3(0.35, 0, -0.7), PI * 0.5, crowd.call("staff_look", rng, Color("2b1d16"), 0.45, 0.1))
	for i in range(3):
		_person(_random_standing(), Vector3(-8.0, 0, z0 - 4.8 + float(i) * 0.75), -PI * 0.5 + rng.randf_range(-0.3, 0.3))
	preload("res://north_infield.gd").new().build(self)
	for bx in [-4.5, 0.0, 4.5]:
		_bench(Vector3(bx, 0, z0 - 7.0), 0.0)
	_plaza_lights(z0)
	for p in [Vector3(-6.8, 0, z0 + 4.6), Vector3(7.3, 0, z0 - 8.5)]:
		_prop("trash_bin", p, rng.randf() * TAU, {}, 0.45)
	for p in [Vector3(-2.0, 0, z0 - 10.3), Vector3(2.0, 0, z0 - 10.3)]:
		_prop("planter", p, 0.0, {}, 0.8)

func _build_team_pits() -> void:
	# Four team tents along the back straight (x = -18), open towards the track, in the rider colours.
	for i in range(4):
		var z: float = [-21.0, -9.0, 9.0, 21.0][i]
		var col: String = TEAM_COLOURS[i]
		var tent := _prop("team_tent", Vector3(-13.6, 0, z), -PI * 0.5, {"canopy_a": col, "banner": col}, 2.4)
		_label(tent, TEAM_NAMES[i], Vector3(0, 2.55, 1.62), 64, Color.WHITE)
		var stand := _prop("bike_work_stand", Vector3(-15.6, 0, z - 0.8), PI, {"bike_frame": col}, 1.0)
		_prop("bike_rack", Vector3(-13.6, 0, z + 2.6), -PI * 0.5, {"bike_frame": col}, 1.3)
		_person("staff_mechanic", stand.transform * Vector3(0.0, 0, 0.75), stand.rotation.y + PI, crowd.call("staff_look", rng, Color(col), 0.25, 0.1))
		_person("staff_mechanic_f", Vector3(-14.9, 0, z + 0.9), -PI * 0.5 + 0.4, crowd.call("staff_look", rng, Color(col), 0.25, 0.1))
		_person("stand_m_relaxed", Vector3(-12.4, 0, z - 0.4), -PI * 0.5 + rng.randf_range(-0.4, 0.4), crowd.call("staff_look", rng, Color(col), 0.25, 0.1))
		_person("stand_f_talk", Vector3(-12.6, 0, z + 0.7), -PI * 0.5 - 0.6, crowd.call("staff_look", rng, Color(col).darkened(0.3), 0.25, 0.1))
	for z in [-27.0, -15.0, 15.0, 27.0]:
		_prop("crowd_barrier", Vector3(-14.4, 0, z), PI * 0.5, {"banner": "0b1a2d"}, 1.3)

func _build_finish_zone() -> void:
	var line: Vector3 = _at(0.0, -1.0)
	var inward := (_at(0.0, -2.0) - _at(0.0, 0.0)).normalized()
	var along := (_at(1.0, -1.0) - _at(-1.0, -1.0)).normalized()    # rider direction
	var table := _prop("officials_table", line + inward * 3.2 - along * 1.8, _yaw_to(-inward), {"counter_cloth": "0b1a2d"}, 1.6)
	_label(table, "JURY  •  TIMING", Vector3(0, 0.45, 0.42), 36, Color.WHITE)
	_person("staff_official_m", line + inward * 2.2 - along * 0.6, _yaw_to(-inward + along * 0.4), crowd.call("staff_look", rng, Color("2c4f86"), 0.12, 0.13))
	_person("staff_official_f", line + inward * 2.4 - along * 3.0, _yaw_to(-inward), crowd.call("staff_look", rng, Color("2c4f86"), 0.12, 0.13))
	_person("staff_official_m", line + inward * 4.6 - along * 1.2, _yaw_to(-inward), crowd.call("staff_look", rng, Color("2b2d33"), 0.12, 0.13))
	# photographers on both sides of the line, TV camera looking at the line
	for d in [-3.6, 3.4, 5.0]:
		var p: Vector3 = line + inward * 0.35 + along * float(d)
		_person("staff_photographer", p, _yaw_to(-inward * 0.6 - along * signf(d)), crowd.call("staff_look", rng, Color("2b2d33"), 0.1, 0.13))
	var view := (-along * 0.8 - inward * 0.6).normalized()
	var cam_pos := line + inward * 0.9 + along * 7.5
	_prop("tv_camera", cam_pos, _yaw_to(view), {}, 0.6)
	_person("staff_photographer", cam_pos - view * 0.55, _yaw_to(view), crowd.call("staff_look", rng, Color("1d2430"), 0.1, 0.13))
	blockers.append([Vector2(line.x, line.z), 4.5])

func _build_ends() -> void:
	# North bend: podium with backdrop; south bend: hospitality corner. Beach flags along both arcs.
	# Podium and enlarged beer tent are built by north_infield.gd.
	for i in range(3):
		var p := Vector3(-3.0 + float(i) * 3.0, 0, -40.0)
		_prop("parasol", p, rng.randf() * TAU, {"parasol_a": "4ed6d9"}, 0.3)
		_high_table(p, rng.randi_range(3, 4))
	for z in [-37.0, -43.5]:
		_prop("crowd_barrier", Vector3(-5.6, 0, z + 2.0), PI * 0.5, {"banner": "4ed6d9"}, 1.3)
		_prop("crowd_barrier", Vector3(5.6, 0, z + 2.0), PI * 0.5, {"banner": "4ed6d9"}, 1.3)
	var flags := ["e0473c", "f2c05e", "268cd3", "35ad77"]
	var k := 0
	for end_sign in [-1.0, 1.0]:
		for i in range(7):
			var a := PI * (0.12 + 0.76 * float(i) / 6.0)
			var p := Vector3(cos(a) * 14.2, 0, end_sign * (34.2 + sin(a) * 14.2))
			_prop("beach_flag", p, _yaw_to(-Vector3(p.x, 0, p.z - end_sign * 34.2)), {"beachflag": flags[k % 4]}, 0.4)
			k += 1

func _build_rail_public() -> void:
	# Fans lined up against the glass boarding (leaning on the handrail), 1-2 rows deep.
	var s := 0.0
	while s < LAP:
		var p: Vector3 = _at(s, GLASS_OFFSET - 0.55)
		var outward := (_at(s, GLASS_OFFSET) - _at(s, GLASS_OFFSET - 1.0)).normalized()
		var skip := false
		if p.x < -11.0 and absf(p.z) < 30.0:            # team pits (back straight)
			skip = absf(fposmod(p.z + 30.0, 12.0) - 6.0) < 4.2
		if p.x > 11.0 and p.z < -27.0 and p.z > -42.0:   # finish zone
			skip = true
		if not skip and rng.randf() < 0.78:
			var v: String = CrowdKit.RAIL[rng.randi() % 2]
			if rng.randf() < 0.25:
				v = ["stand_m_cheer", "stand_f_phone", "stand_m_clap"][rng.randi() % 3]
			_person(v, p, _yaw_to(outward) + rng.randf_range(-0.15, 0.15))
			if rng.randf() < 0.45:
				var back := p - outward * rng.randf_range(0.65, 0.9) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
				_person(["stand_m_relaxed", "stand_f_phone", "stand_m_cheer", "stand_f_drink", "stand_m_clap"][rng.randi() % 5],
					back, _yaw_to(outward) + rng.randf_range(-0.3, 0.3))
		s += rng.randf_range(0.62, 0.9)

func _build_wanderers() -> void:
	# Loose groups standing around the plazas.
	var placed := 0
	var tries := 0
	while placed < 40 and tries < 900:
		tries += 1
		var p := Vector3(rng.randf_range(-11.0, 11.0), 0, rng.randf_range(-29.0, 29.0))
		if not _free_spot(p, 0.7):
			continue
		_group_around(p, rng.randi_range(2, 3), 0.55)
		blockers.append([Vector2(p.x, p.z), 1.0])
		placed += 1

func _emit_people() -> void:
	var total := 0
	for key in people.keys():
		total += int(crowd.call("emit_group", self, people[key], "Middenterrein " + String(key), [[0, 0.0, NEAR_M], [1, NEAR_M, 0.0]]))
	people.clear()
	print("Velodrome 250 middenterrein: %d personen" % total)

func _emit_bulbs() -> void:
	var mesh: Mesh = crowd.call("prop", "bulb")
	if mesh == null or bulbs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = bulbs.size()
	for i in range(bulbs.size()):
		mm.set_instance_transform(i, bulbs[i])
	var node := MultiMeshInstance3D.new()
	node.name = "Lichtslingers"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

# ------------------------------------------------------------------ flag official
func _build_flag_official() -> void:
	flag_node = FLAG_SCENE.instantiate()
	flag_node.name = "Vlagdame"
	flag_node.add_to_group("stadium_people")
	var line: Vector3 = _at(0.0, -1.05)
	var outward := (_at(0.0, 0.0) - _at(0.0, -1.0)).normalized()
	var oncoming := -(_at(1.0, -1.0) - _at(-1.0, -1.0)).normalized()   # riders come from here
	flag_node.position = line
	flag_node.rotation.y = _yaw_to(outward + oncoming * 0.45)
	add_child(flag_node)
	flag_anim = _find_player(flag_node)
	if flag_anim != null:
		for a in flag_anim.get_animation_list():
			var clip: Animation = flag_anim.get_animation(a)
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
			# Godot strips the "_loop" suffix on import ("flag_ready"), so match on the stem.
			if String(a).contains("flag_ready"):
				flag_ready = a
			elif String(a).contains("flag_wave"):
				flag_wave = a
	flag_node.visible = false

func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var f := _find_player(c)
		if f != null:
			return f
	return null

func _set_flag_state(state: String) -> void:
	if state == flag_state:
		return
	flag_state = state
	flag_node.visible = state != "hidden"
	if flag_anim == null:
		return
	if state == "ready" and flag_ready != &"":
		flag_anim.play(flag_ready, 0.35)
	elif state == "wave" and flag_wave != &"":
		flag_anim.play(flag_wave, 0.2)
	elif state == "hidden":
		flag_anim.stop()

func _process(delta: float) -> void:
	if game == null or flag_node == null:
		return
	var length: float = float(int(game.get("race_laps"))) * LAP
	var racing: bool = String(game.get("start_state")) == "RACING"
	var finished: bool = bool(game.get("finished"))
	var dists: Array = game.get("distances")
	var times: Array = game.get("finish_times")
	var lead := 0.0
	var done := 0
	for i in range(dists.size()):
		lead = maxf(lead, float(dists[i]))
		if float(times[i]) >= 0.0:
			done += 1
	if done > finished_seen:
		# The winner crossing the line: wave hard. Later finishers get a shorter wave.
		wave_timer = 7.0 if finished_seen == 0 else maxf(wave_timer, 2.5)
	finished_seen = done
	wave_timer = maxf(0.0, wave_timer - delta)
	# Only in the last lap: from the moment the leader starts it until the race is reset.
	var last_lap := (racing or finished) and lead >= length - LAP
	if not last_lap:
		finished_seen = 0
		_set_flag_state("hidden")
	elif wave_timer > 0.0:
		_set_flag_state("wave")
	else:
		_set_flag_state("ready")
