extends Node3D
# Velodrome 250 - PROCEDURAL ARENA beta.16.12
# Everything here is generated at runtime with Godot meshes and MultiMesh.
# No changes to the track geometry, race physics, bike rig or Strava integration.
# The first version deliberately uses static spectators: excellent detail / GPU cost.

const LAP := 250.0
const STAND_RIM := 9.1
var crowd_density := 0.60
const RING_STEPS := 300
const SEAT_SPACING := 0.94

const NAVY := "142a43"
const NAVY_DARK := "0b1a2d"
const NAVY_MID := "244968"
const TURQUOISE := "4ed6d9"
const GOLD := "f2c05e"
const ORANGE := "ef8736"
const CONCRETE := "c9c5b6"

const TIERS := [
	# inner row start, row count, row depth, row rise, relative deck height
	{"start": 10.65, "rows": 7, "depth": 1.10, "rise": 0.40, "base": 0.88},
	{"start": 20.25, "rows": 8, "depth": 1.17, "rise": 0.47, "base": 5.15},
	{"start": 32.05, "rows": 7, "depth": 1.27, "rise": 0.55, "base": 11.20}
]

var main: Node3D
var board: Label3D
var sponsor_texture: Texture2D = preload("res://wielerpraat.jpg")
var seat_count := 0
var spectator_count := 0
const CommentaryBox := preload("res://commentary_box.gd")
const CrowdKit := preload("res://crowd_kit.gd")
var crowd: RefCounted
var crowd_sections := {}
const CROWD_SECTION_M := 31.25      # track metres per crowd block (8 blocks per tier)
const CROWD_NEAR_M := 32.0          # closer than this: detailed figures, further: light figures

func _ready() -> void:
	main = get_parent()
	crowd = CrowdKit.new()
	var cfg := ConfigFile.new()
	if cfg.load("user://display_settings.cfg") == OK:
		crowd_density = clampf(float(cfg.get_value("arena", "crowd_density", 0.60)), 0.0, 1.0)
	_build_boarding()
	_build_concourses()
	_build_grandstands()
	CommentaryBox.build(self)
	_emit_stand_crowd()
	_build_aisles()
	preload("res://tour_spectator_details.gd").new().build(self)
	_build_facades_and_railings()
	_build_roof()
	var show := preload("res://stadium_show.gd").new()
	show.name = "VelodromeStadiumShow"
	add_child(show)
	_build_track_banner()
	_build_infield()
	var infield_scene: Node3D = preload("res://infield_details.gd").new()
	infield_scene.name = "LevendigMiddenterrein"
	infield_scene.set("crowd", crowd)
	add_child(infield_scene)
	_build_scoreboard()
	print("Velodrome 250 arena: %d procedurele stoeltjes, %d toeschouwers, MultiMesh" % [seat_count, spectator_count])

func _point(s: float, offset: float) -> Vector3:
	return main.call("_at", s, offset)

func _stadium_point(s: float, offset: float, height_above_rim: float) -> Vector3:
	# Do NOT extend the steep 42-degree cycling bank to the grandstands.
	# Outside the safety barrier the tiers have independent architectural heights.
	var p: Vector3 = _point(s, offset)
	p.y = _point(s, STAND_RIM).y + height_above_rim
	return p

func _outward(s: float) -> Vector3:
	var n: Vector3 = _point(s, 8.0) - _point(s, 7.0)
	n.y = 0.0
	return n.normalized()

func _seat_basis(s: float) -> Basis:
	var t: Vector3 = _point(s + 0.15, 0.0) - _point(s - 0.15, 0.0)
	t.y = 0.0
	t = t.normalized()
	return Basis(t, Vector3.UP, _outward(s))

func _boarding_sign_basis(s: float) -> Basis:
	# Rider direction is counter-clockwise, so the infield-facing side is -outward.
	# QuadMesh has its front face along local +Z. Point it toward the rider,
	# using a proper right-handed basis; otherwise text is mirrored from trackside.
	# Do not change _seat_basis: it also orients seats, spectators and lamps.
	var tangent: Vector3 = _point(s + 0.15, 0.0) - _point(s - 0.15, 0.0)
	tangent.y = 0.0
	tangent = tangent.normalized()
	return Basis(tangent, Vector3.UP, -_outward(s))

func _material(hex: String, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _instanced_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.80
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _emissive(hex: String, strength: float = 0.85) -> StandardMaterial3D:
	var mat: StandardMaterial3D = _material(hex, 0.0, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(hex)
	mat.emission_energy_multiplier = strength
	return mat

func _box_mesh(size3: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size3
	return mesh

func _box(position: Vector3, size3: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _box_mesh(size3)
	node.material_override = material
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		add_child(node)
	else:
		parent.add_child(node)
	return node

func _mesh_surface(verts: PackedVector3Array, normals: PackedVector3Array, material: Material, name_text: String) -> void:
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	var node := MeshInstance3D.new()
	node.name = name_text
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _quad(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	for v in [a, b, c, c, b, d]:
		verts.append(v)
		normals.append(normal)

func _ring_deck(inner: float, outer: float, inner_h: float, outer_h: float, material: Material, label: String, steps: int = RING_STEPS) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for j in range(steps):
		var s0: float = LAP * float(j) / float(steps)
		var s1: float = LAP * float(j + 1) / float(steps)
		_quad(verts, normals,
			_stadium_point(s0, inner, inner_h), _stadium_point(s0, outer, outer_h),
			_stadium_point(s1, inner, inner_h), _stadium_point(s1, outer, outer_h))
	_mesh_surface(verts, normals, material, label)

func _ring_wall(offset: float, low_h: float, high_h: float, material: Material, label: String, steps: int = RING_STEPS) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for j in range(steps):
		var s0: float = LAP * float(j) / float(steps)
		var s1: float = LAP * float(j + 1) / float(steps)
		_quad(verts, normals,
			_stadium_point(s0, offset, low_h), _stadium_point(s0, offset, high_h),
			_stadium_point(s1, offset, low_h), _stadium_point(s1, offset, high_h))
	_mesh_surface(verts, normals, material, label)

func _instances(mesh: Mesh, poses: Array[Transform3D], colors: Array[Color], name_text: String) -> void:
	if poses.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i, poses[i])
		multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = name_text
	node.multimesh = multi
	node.material_override = _instanced_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _solid_instances(mesh: Mesh, poses: Array[Transform3D], hex: String, name_text: String) -> void:
	if poses.is_empty():
		return
	var colors: Array[Color] = []
	for i in range(poses.size()):
		colors.append(Color(hex))
	_instances(mesh, poses, colors, name_text)

func _look_color(tier: int, row: int, s: float) -> Color:
	# Seat colors form large orange/gold/navy architectural sections, not random noise.
	var section: int = int(floor(s / 18.0))
	var diag: int = (section * 3 + row * 2) % 13
	if tier == 0:
		return Color(ORANGE) if diag < 5 else (Color(GOLD) if diag < 9 else Color(NAVY_MID))
	if tier == 1:
		return Color(GOLD) if diag < 5 else (Color(ORANGE) if diag < 8 else Color("234969"))
	return Color("244b72") if diag < 7 else (Color(ORANGE) if diag < 10 else Color(TURQUOISE))

func _noise(seed: int) -> float:
	var x: int = absi(seed * 71 + seed * seed * 13 + 1471)
	return float(x % 1009) / 1009.0

func _aisle(s: float) -> bool:
	# Five uninterrupted radial stairs between seating blocks.
	return fposmod(s + 3.0, 49.7) < 2.1

func _build_grandstands() -> void:
	var riser_material: Material = _material("33465a")
	var floor_materials: Array[Material] = [_material("a8aaa5"), _material("b5b8b2"), _material("a3aaa8")]
	var cushion_mesh: Mesh = _box_mesh(Vector3(0.76, 0.105, 0.54))
	var back_mesh: Mesh = _box_mesh(Vector3(0.76, 0.64, 0.11))
	var rng := RandomNumberGenerator.new()
	rng.seed = 250
	for tier in range(TIERS.size()):
		var config: Dictionary = TIERS[tier]
		var start: float = float(config["start"])
		var num_rows: int = int(config["rows"])
		var depth: float = float(config["depth"])
		var rise: float = float(config["rise"])
		var base: float = float(config["base"])
		var seats: Array[Transform3D] = []
		var backs: Array[Transform3D] = []
		var seats_colors: Array[Color] = []
		for row in range(num_rows):
			var in_off: float = start + float(row) * depth
			var floor_h: float = base + float(row) * rise
			_ring_deck(in_off, in_off + depth, floor_h, floor_h, floor_materials[tier], "Tribune %d rij %d" % [tier + 1, row + 1])
			if row > 0:
				_ring_wall(in_off, floor_h - rise, floor_h, riser_material, "Tribune stootbord %d.%d" % [tier + 1, row])
			# Keep individual seat pitch close to a metre even on the curved ends.
			var s := 0.0
			var seat_index := 0
			while s < LAP:
				var off: float = in_off + depth * 0.51
				var a: Vector3 = _point(s - 0.16, off)
				var b: Vector3 = _point(s + 0.16, off)
				a.y = 0.0
				b.y = 0.0
				var metres_per_s: float = maxf(0.55, a.distance_to(b) / 0.32)
				# Leave a clear first-row spot for the hand-placed WOUT supporter.
				var reserved_supporter := tier == 0 and row == 0 and absf(s-152.4) < 1.4
				if not _aisle(s) and not reserved_supporter and not CommentaryBox.reserves_seat(self, tier, s, off):
					var orientation: Basis = _seat_basis(s)
					var outward: Vector3 = _outward(s)
					var deck: Vector3 = _stadium_point(s, off, floor_h)
					var seat_color: Color = _look_color(tier, row, s)
					seats.append(Transform3D(orientation, deck + Vector3.UP * 0.38))
					backs.append(Transform3D(orientation, deck + outward * 0.32 + Vector3.UP * 0.73))
					seats_colors.append(seat_color)
					seat_count += 1
					var seed: int = tier * 1973 + row * 157 + seat_index * 17
					if _noise(seed) < crowd_density:
						# Blender figure faces model +Z: point it at the track (-outward).
						var facing := Basis(-orientation.x, Vector3.UP, -orientation.z)
						facing = facing.rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
						var variant: String = CrowdKit.SEATED[crowd.pick_weighted(rng, CrowdKit.SEATED_WEIGHTS)]
						var block_key := "%d_%d" % [tier, int(floor(s / CROWD_SECTION_M))]
						if not crowd_sections.has(block_key):
							crowd_sections[block_key] = {}
						CrowdKit.add_to_group(crowd_sections[block_key], variant, Transform3D(facing, deck), crowd.random_look(rng))
						spectator_count += 1
				s += clampf(SEAT_SPACING / metres_per_s, 0.38, 1.25)
				seat_index += 1
		var suffix := "L%d" % (tier + 1)
		_instances(cushion_mesh, seats, seats_colors, "Stoeltjes zitting " + suffix)
		_instances(back_mesh, backs, seats_colors, "Stoeltjes rugleuning " + suffix)
		# Balcony fascia hides underside while outlining each grandstand level.
		var last_off: float = start + float(num_rows) * depth
		var last_floor: float = base + float(num_rows - 1) * rise
		_ring_wall(last_off, last_floor - 1.2, last_floor + 0.42, _material(NAVY), "Balcon gevel " + suffix)
		_ring_deck(last_off - 0.20, last_off + 0.08, last_floor + 0.47, last_floor + 0.47, _material(ORANGE), "Balcon gouden rand " + suffix)

func _emit_stand_crowd() -> void:
	# One MultiMesh per (tier block, pose, detail level). Blocks behind the camera are culled,
	# far blocks switch to the light figures.
	for key in crowd_sections.keys():
		crowd.emit_group(self, crowd_sections[key], "Publiek blok " + String(key),
			[[1, 0.0, CROWD_NEAR_M], [2, CROWD_NEAR_M, 0.0]])
	crowd_sections.clear()

func _build_concourses() -> void:
	# A ring-shaped circulation gallery separates each tier.
	_ring_deck(9.3, 10.6, 0.75, 0.86, _material("77898f"), "Veiligheidsgang aan piste")
	_ring_deck(18.3, 20.25, 5.05, 5.15, _material("a6a99d"), "Omloop eerste verdieping")
	_ring_deck(29.65, 32.05, 11.08, 11.20, _material("aeb0a7"), "Omloop tweede verdieping")
	# Spacious shaded gallery openings and branded fascia underneath the balcony.
	_ring_wall(18.6, 2.40, 4.92, _material("162738"), "Glaswand niveau 1")
	_ring_wall(30.0, 8.70, 10.98, _material("142535"), "Glaswand niveau 2")
	_ring_wall(41.1, 14.8, 16.5, _material(NAVY_DARK), "Buitenwand hoogste tribune")
	_ring_deck(18.6, 20.1, 4.98, 5.12, _material(NAVY_MID), "Balkonportaal 1")
	_ring_deck(30.0, 31.9, 11.03, 11.16, _material(NAVY_MID), "Balkonportaal 2")
	# Slim horizontal turquoise LED bands across the entire gallery frontage.
	_ring_deck(18.51, 18.63, 4.85, 4.85, _emissive(TURQUOISE, 0.65), "LED galerij 1")
	_ring_deck(29.91, 30.03, 10.87, 10.87, _emissive(GOLD, 0.55), "LED galerij 2")

func _build_aisles() -> void:
	# Five light concrete stair-ribbons cut through the grandstands.
	var stair_material: Material = _material("d4d1c5")
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for tier in range(TIERS.size()):
		var config: Dictionary = TIERS[tier]
		for row in range(int(config["rows"])):
			var off0: float = float(config["start"]) + float(row) * float(config["depth"])
			var off1: float = off0 + float(config["depth"])
			var h: float = float(config["base"]) + float(row) * float(config["rise"]) + 0.016
			for section in range(5):
				var s: float = float(section) * 49.7 - 3.0 + 1.05
				_quad(verts, normals, _stadium_point(s - 1.0, off0, h), _stadium_point(s - 1.0, off1, h),
					_stadium_point(s + 1.0, off0, h), _stadium_point(s + 1.0, off1, h))
	_mesh_surface(verts, normals, stair_material, "Radiale tribune trappen")

func _build_facades_and_railings() -> void:
	var rail_poses: Array[Transform3D] = []
	var window_poses: Array[Transform3D] = []
	var vertical_mesh: Mesh = _box_mesh(Vector3(0.10, 1.35, 0.10))
	var glass_material: Material = _material("528f9b", 0.33, 0.32)
	# Glass spandrels and metal railings along gallery edges.
	for edge in [18.45, 29.85]:
		var bottom: float = 5.0 if edge < 20.0 else 10.95
		_ring_wall(edge, bottom, bottom + 1.15, glass_material, "Glazen balustrade %.1f" % edge)
		_ring_deck(edge - 0.05, edge + 0.05, bottom + 1.20, bottom + 1.20,
			_emissive(TURQUOISE, 0.35), "Balustrade LED %.1f" % edge)
		for i in range(125):
			var s: float = LAP * float(i) / 125.0
			rail_poses.append(Transform3D(Basis.IDENTITY, _stadium_point(s, edge, bottom + 0.59)))
	for tier in range(2):
		var offset: float = 18.65 if tier == 0 else 30.05
		var midheight: float = 3.70 if tier == 0 else 9.85
		for i in range(130):
			var s: float = LAP * float(i) / 130.0
			window_poses.append(Transform3D(Basis.IDENTITY, _stadium_point(s, offset, midheight)))
	_solid_instances(vertical_mesh, rail_poses, "b3ccd5", "Verticale balustradestijlen")
	_solid_instances(_box_mesh(Vector3(0.14, 2.12, 0.14)), window_poses, "516776", "Gevel raamstijlen")

func _build_roof() -> void:
	# Large cantilevered roof, with an enclosed high central canopy.
	_ring_deck(28.8, 49.1, 19.2, 23.3, _material("27354b"), "Donker dakvlak")
	_ring_deck(29.0, 49.3, 19.42, 23.62, _material("4c3d32"), "Warm houten dakschild")
	_ring_deck(29.1, 48.9, 19.52, 23.69, _material("76533b"), "Houten plafond tint")
	_build_central_canopy()
	# Navy roof fascia and accent stripes.
	_ring_wall(28.77, 18.73, 19.52, _material(NAVY), "Dakboord donkerblauw")
	_ring_deck(28.64, 28.79, 18.87, 18.87, _emissive(GOLD, 0.9), "Dak lichtlijn goud")
	_ring_wall(49.11, 22.5, 24.0, _material(NAVY_DARK), "Buitenste dakrand")
	# Thin timber rafters at regular intervals, true 3D beams drawn via MultiMesh.
	var beams: Array[Transform3D] = []
	var beams_mesh: Mesh = _box_mesh(Vector3(0.20, 0.30, 1.0))
	for i in range(58):
		var s: float = LAP * float(i) / 58.0
		var inside: Vector3 = _stadium_point(s, 28.8, 19.0)
		var outside: Vector3 = _stadium_point(s, 49.3, 23.25)
		beams.append(_between(inside, outside))
	_solid_instances(beams_mesh, beams, "2b2528", "58 houten dakspanten")
	# Outer steel supports, placed BEHIND the seating, not on the cycling surface.
	var supports: Array[Transform3D] = []
	for i in range(46):
		var s: float = LAP * float(i) / 46.0
		var low: Vector3 = _stadium_point(s, 43.0, 10.3)
		var high: Vector3 = _stadium_point(s, 43.0, 21.7)
		supports.append(_between(low, high))
	_solid_instances(_box_mesh(Vector3(0.27, 0.27, 1.0)), supports, "384b5d", "Stalen dragende kolommen")
	# Architectural flood-light strips: glow material, only FOUR actual OmniLights.
	var light_poses: Array[Transform3D] = []
	for i in range(46):
		var s: float = LAP * float(i) / 46.0
		var p: Vector3 = _stadium_point(s, 29.8, 18.55)
		light_poses.append(Transform3D(_seat_basis(s), p))
	_solid_instances(_box_mesh(Vector3(2.75, 0.08, 0.24)), light_poses, "ffe5ac", "Arena lichtpanelen")
	for i in range(4):
		var s: float = LAP * float(i) / 4.0
		var lamp := OmniLight3D.new()
		lamp.name = "Sfeerverlichting %d" % (i + 1)
		lamp.position = _stadium_point(s, 29.7, 18.1)
		lamp.light_energy = 0.28
		lamp.omni_range = 32.0
		lamp.shadow_enabled = false
		add_child(lamp)
	# A few focused neutral-white overhead lamps give the wood and riders contrast.
	# Decorative strips remain emissive; avoid a costly shadow light per panel.
	for i in range(8):
		var s: float = LAP * (float(i) + 0.5) / 8.0
		var race_light := SpotLight3D.new()
		race_light.name = "Piste schijnwerper %d" % (i + 1)
		race_light.position = _stadium_point(s, 25.9, 19.4)
		add_child(race_light)
		race_light.look_at(_stadium_point(s, 3.6, 0.4), Vector3.UP)
		race_light.light_color = Color("f4f5ff")
		race_light.light_energy = 1.05
		race_light.spot_range = 37.0
		race_light.spot_angle = 56.0
		race_light.shadow_enabled = false

func _build_central_canopy() -> void:
	# A high, lightweight faceted ceiling spanning the former open centre.
	# Its underside is above the entire intro camera path and cycling track.
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var hub := Vector3(0.0, 27.5, 0.0)
	vertices.append(hub)
	for i in range(129):
		var s := LAP * float(i) / 128.0
		vertices.append(_stadium_point(s, 28.8, 19.2))
	for i in range(128):
		indices.append_array(PackedInt32Array([0, i + 1, i + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Gesloten hoog plafond boven piste"
	ceiling.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("18243b")
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ceiling.material_override = material
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ceiling)
	var braces: Array[Transform3D] = []
	for i in range(24):
		var s := LAP * float(i) / 24.0
		braces.append(_between(hub, _stadium_point(s, 28.8, 19.18)))
	_solid_instances(_box_mesh(Vector3(0.16, 0.21, 1.0)), braces, "3b4b62", "Radiale plafondspanten")

func _between(a: Vector3, b: Vector3) -> Transform3D:
	var forward: Vector3 = (b - a).normalized()
	var local_x: Vector3 = Vector3.UP.cross(forward).normalized()
	if local_x.length_squared() < 0.001:
		local_x = Vector3.RIGHT
	var local_y: Vector3 = forward.cross(local_x).normalized()
	var basis := Basis(local_x, local_y, forward)
	basis = basis.scaled(Vector3(1.0, 1.0, a.distance_to(b)))
	return Transform3D(basis, (a + b) * 0.5)

func _track_barrier(offset: float, height: float, material: Material, label: String) -> void:
	# Two-sided continuous mesh replaces 180-220 separate wall objects.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(360):
		var s0: float = LAP * float(i) / 360.0
		var s1: float = LAP * float(i + 1) / 360.0
		var p: Vector3 = _point(s0, offset)
		var q: Vector3 = _point(s1, offset)
		_quad(verts, normals, p, p + Vector3.UP * height, q, q + Vector3.UP * height)
	_mesh_surface(verts, normals, material, label)

func _build_boarding() -> void:
	# Preserve barrier positions and texture asset; simplify the geometry for Intel GPUs.
	_track_barrier(9.10, 1.24, _material("193b72"), "Doorlopende buitenboarding")
	preload("res://boarding_sponsors.gd").build(self)
	_build_glass_boarding()
	_ring_deck(9.07, 9.22, 1.26, 1.26, _emissive(TURQUOISE, 0.28), "Turquoise bovenrand boarding")
	var plate_mesh := QuadMesh.new()
	plate_mesh.size = Vector2(1.07, 0.43)
	var sponsor_mat := StandardMaterial3D.new()
	sponsor_mat.albedo_texture = sponsor_texture
	sponsor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sponsor_mat.cull_mode = BaseMaterial3D.CULL_BACK # Only track-facing side should be visible
	var signs: Array[Transform3D] = []
	for i in range(37):
		var s: float = LAP * (float(i) + 0.5) / 37.0
		if preload("res://boarding_sponsors.gd").covered(main, s): continue
		var origin: Vector3 = _point(s, 9.10) + Vector3.UP * 0.69 - _outward(s) * 0.085
		signs.append(Transform3D(_boarding_sign_basis(s), origin))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = plate_mesh
	multi.instance_count = signs.size()
	for i in range(signs.size()):
		multi.set_instance_transform(i, signs[i])
	var signs_node := MultiMeshInstance3D.new()
	signs_node.name = "%d bestaande sponsorpanelen" % signs.size()
	signs_node.multimesh = multi
	signs_node.material_override = sponsor_mat
	signs_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(signs_node)

func _infield_ring(offset: float, y0: float, y1: float, material: Material, label: String, steps: int = 360) -> void:
	# Vertical ring at a horizontal track offset, with FIXED heights (not following the banking).
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(steps):
		var p: Vector3 = _point(LAP * float(i) / float(steps), offset)
		var q: Vector3 = _point(LAP * float(i + 1) / float(steps), offset)
		p.y = 0.0
		q.y = 0.0
		_quad(verts, normals, p + Vector3.UP * y0, p + Vector3.UP * y1, q + Vector3.UP * y0, q + Vector3.UP * y1)
	_mesh_surface(verts, normals, material, label)

func _infield_ring_flat(offset_a: float, offset_b: float, y: float, material: Material, label: String, steps: int = 360) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(steps):
		var s0: float = LAP * float(i) / float(steps)
		var s1: float = LAP * float(i + 1) / float(steps)
		var a: Vector3 = _point(s0, offset_a)
		var b: Vector3 = _point(s0, offset_b)
		var c: Vector3 = _point(s1, offset_a)
		var d: Vector3 = _point(s1, offset_b)
		a.y = y
		b.y = y
		c.y = y
		d.y = y
		_quad(verts, normals, a, b, c, d)
	_mesh_surface(verts, normals, material, label)

func _build_glass_boarding() -> void:
	# beta.16.13: the inner boarding is now glass between aluminium posts with a handrail,
	# so the riders stay visible from the infield and vice versa.
	const OFF := -0.45
	const BASE_Y := -0.06
	const TOP_Y := 1.08
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.78, 0.90, 0.98, 0.17)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_infield_ring(OFF, BASE_Y + 0.14, TOP_Y - 0.03, glass, "Glazen binnenboarding")
	var alu: StandardMaterial3D = _material("c9d3da", 0.75, 0.28)
	var kick: StandardMaterial3D = _material("26313b")
	_infield_ring(OFF, BASE_Y, BASE_Y + 0.14, kick, "Boarding voetplint")
	_infield_ring(OFF - 0.035, TOP_Y - 0.05, TOP_Y, alu, "Leuning binnenkant")
	_infield_ring(OFF + 0.035, TOP_Y - 0.05, TOP_Y, alu, "Leuning buitenkant")
	_infield_ring_flat(OFF - 0.035, OFF + 0.035, TOP_Y, alu, "Leuning bovenkant")
	var posts: Array[Transform3D] = []
	var count := 114
	for i in range(count):
		var s: float = LAP * float(i) / float(count)
		var p: Vector3 = _point(s, OFF)
		p.y = (BASE_Y + TOP_Y) * 0.5
		posts.append(Transform3D(_seat_basis(s), p))
	_solid_instances(_box_mesh(Vector3(0.06, TOP_Y - BASE_Y, 0.06)), posts, "b7c3cc", "Boarding staanders")

func _build_track_banner() -> void:
	# Preserve EXACT UV coordinates from beta.16.11.8; no more banner regressions.
	var verts := PackedVector3Array()
	var tex := PackedVector2Array()
	var steps := 28
	for k in range(steps):
		var s0: float = 12.0 + float(k) * 18.0 / float(steps)
		var s1: float = 12.0 + float(k + 1) * 18.0 / float(steps)
		var a: Vector3 = _point(s0, 5.1) + Vector3.UP * 0.075
		var b: Vector3 = _point(s0, 8.1) + Vector3.UP * 0.075
		var c: Vector3 = _point(s1, 5.1) + Vector3.UP * 0.075
		var d: Vector3 = _point(s1, 8.1) + Vector3.UP * 0.075
		var u0: float = float(k) / float(steps)
		var u1: float = float(k + 1) / float(steps)
		for v in [a, b, c, c, b, d]:
			verts.append(v)
		for uv in [Vector2(1.0 - u0, 1.0), Vector2(1.0 - u0, 0.0), Vector2(1.0 - u1, 1.0), Vector2(1.0 - u1, 1.0), Vector2(1.0 - u0, 0.0), Vector2(1.0 - u1, 0.0)]:
			tex.append(uv)
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_TEX_UV] = tex
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	var banner := MeshInstance3D.new()
	banner.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = sponsor_texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	banner.material_override = mat
	add_child(banner)

func _build_infield() -> void:
	# All detailed infield scenery now lives in infield_details.gd.
	# Do not place the old capsule staff or raised solid blocks over the tunnel.
	pass

func _build_scoreboard() -> void:
	_box(Vector3(0, 12, -71), Vector3(18, 8, 0.7), _material("0d1c32"))
	board = Label3D.new()
	board.position = Vector3(0, 12, -70.4)
	board.font_size = 44
	board.pixel_size = 0.009
	board.modulate = Color.WHITE
	board.text = "VELODROME 250\nRANGLIJST"
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(board)

var excitement := 0.12

func _process(delta: float) -> void:
	# Crowd energy: calm before the start, louder in the last lap, wild at the finish.
	if crowd == null or main == null:
		return
	var target := 0.12
	var length: float = float(int(main.get("race_laps"))) * LAP
	var lead := 0.0
	for d in main.get("distances"):
		lead = maxf(lead, float(d))
	if bool(main.get("finished")):
		target = 0.8 if float(main.get("finish_elapsed")) < 6.0 else 0.3
	elif String(main.get("start_state")) == "RACING":
		target = 0.25
		if lead >= length - LAP:
			target = 0.55
		if lead >= length - 60.0:
			target = 1.0
	excitement = lerpf(excitement, target, clampf(delta * 1.5, 0.0, 1.0))
	crowd.call("set_excitement", excitement)

func set_ranking(distances: Array) -> void:
	if board == null or distances.size() < 4:
		return
	var ids: Array[int] = [0, 1, 2, 3]
	ids.sort_custom(func(a: int, b: int) -> bool: return float(distances[a]) > float(distances[b]))
	var labels := ["JIJ", "WZ", "SPR", "AAN"]
	var out := "VELODROME 250 - LIVE\n"
	for i in range(4):
		out += "%d. %s  %.0f m\n" % [i + 1, labels[ids[i]], float(distances[ids[i]])]
	board.text = out
