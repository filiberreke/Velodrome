extends "res://venues/gent/gent_build.gd"

const Crowd := preload("res://crowd_kit.gd")
const CommentaryBox := preload("res://commentary_box.gd")
const Infield := preload("res://venues/roubaix/roubaix_infield.gd")
const BLUE_BANNER := preload("res://assets/boarding/velodrome-boarding.png")
const WHITE_BANNER := preload("res://assets/boarding/velodrome-boarding-licht.png")
const BEND_BANNERS := [
	BLUE_BANNER,
	preload("res://assets/boarding/roubaix-ville.png"),
	preload("res://assets/boarding/roubaix-nord-pas-de-calais.png"),
]
const RIM := 9.15
const ROOF_START := -57.0
const ROOF_END := 22.0
const MEDIA_HALF_WIDTH := 7.8
const ROAD_HALF_WIDTH := 3.1

var simple := false
var simple_infield: bool:
	get: return simple
var density := 0.60
var infield: Node3D
var crowd: RefCounted
var rng := RandomNumberGenerator.new()
var road_distance: float

func build(host: Node3D, profile: Resource, route: RefCounted) -> void:
	name = "RoubaixArena"
	set_meta("venue_id", profile.id)
	venue = profile
	track = route
	rng.seed = 19252026
	crowd = Crowd.new()
	road_distance = venue.lap_length_m * 0.5 + track.phase(0.0) - track.geometry.STRAIGHT * 0.5
	_build_track()
	_build_road_access()
	infield = Infield.new()
	infield.name = "RoubaixInfield"
	add_child(infield)
	infield.build(host, venue, track)
	_build_stands()
	_build_surroundings()
	_infield_public()

func set_track_lighting_training(_training: bool) -> void:
	pass

func _surface_material(tint: Color, kind: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://venues/roubaix/roubaix_surface.gdshader")
	result.set_shader_parameter("tint", tint)
	result.set_shader_parameter("surface_kind", kind)
	return result

func _build_track() -> void:
	box("GrassInfieldAndGround", Vector3(0, -0.17, 0), Vector3(900, 0.25, 900), _surface_material(Color("102006"), 2))
	ring("GravelApron", -Infield.GRAVEL_WIDTH, 0, _surface_material(Color("3e2317"), 1), 0, -1, -0.011, true)
	ring("GravelInnerEdge", -Infield.GRAVEL_WIDTH - 0.09, -Infield.GRAVEL_WIDTH, mat("d6ccae"), 0, -1, -0.009, true)
	ring("BlueApron", 0, venue.apron_width_m, mat("29b3d5"))
	ring("WeatheredConcrete", venue.apron_width_m, venue.track_outer_offset_m, _surface_material(Color("c4af83"), 0))
	for marking in [[0.20, "454843"], [0.85, "bd6d59"], [2.45, "548eaa"]]:
		var offset: float = venue.apron_width_m + marking[0]
		ring("TrackLine", offset, offset + 0.045, mat(marking[1]), 0, -1, 0.012)
	ring("FinishWhite", venue.apron_width_m, venue.track_outer_offset_m, mat("f7f3ec"), -0.36, 0.72, 0.023)
	ring("FinishBlack", venue.apron_width_m, venue.track_outer_offset_m, mat("24282a"), -0.02, 0.04, 0.028)
	var bend_center: float = track.phase(0.0) + PI * venue.bend_radius_m * 0.5
	for bend in 2:
		for index in 3:
			var s: float = bend_center + bend * venue.lap_length_m * 0.5 + (index - 1) * 23.0
			_track_banner("Bend%dBanner%d" % [bend + 1, index + 1], s, BEND_BANNERS[index])
	# Sparse event panels follow the occupied banner positions in the reference.
	var boarding_slots := [-54.0, -47.0, -39.0, -31.0, -22.0, -13.0, -4.0, 5.0, 14.0, 20.0,
		39.0, 62.0, 122.0, 140.0, 177.0, 199.0, 228.0, 246.0, 274.0, 304.0, 337.0, 372.0, 399.0, 415.0]
	for i in boarding_slots.size():
		_boarding(float(boarding_slots[i]), WHITE_BANNER if i % 2 == 0 else BLUE_BANNER)
	_railings()

func _print_material(texture: Texture2D) -> StandardMaterial3D:
	if materials.has(texture.resource_path): return materials[texture.resource_path]
	var result := StandardMaterial3D.new()
	result.albedo_texture = texture
	result.roughness = 0.92
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[texture.resource_path] = result
	return result

func _track_banner(node_name: String, s: float, texture: Texture2D) -> void:
	var inner := 5.25
	var outer := 8.18
	var aspect := float(texture.get_width()) / texture.get_height()
	var rate: float = track.at(s + 0.1, 6.7).distance_to(track.at(s - 0.1, 6.7)) / 0.2
	var span := clampf((outer - inner) * aspect, 6.4, 10.0) / rate
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in 48:
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var along := (i + corner.x) / 48.0
			vertices.append(track.at(s + (along - 0.5) * span, lerpf(inner, outer, corner.y)) + Vector3.UP * 0.014)
			uv.append(Vector2(1.0 - along, 1.0 - corner.y))
	var banner := surface(node_name, vertices, _print_material(texture), uv)
	banner.set_meta("banner_artwork", texture.resource_path)

func _boarding(s: float, texture: Texture2D) -> void:
	var p: Vector3 = track.at(s, RIM)
	var outward: Vector3 = track.outward(s)
	var panel := Node3D.new()
	panel.name = "TracksideBanner"
	panel.transform = Transform3D(Basis(Vector3.UP.cross(-outward), Vector3.UP, -outward), p + Vector3.UP * 0.43)
	add_child(panel)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.4, 0.79)
	var artwork := MeshInstance3D.new()
	artwork.mesh = mesh
	artwork.material_override = _print_material(texture)
	artwork.position.z = 0.072
	artwork.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(artwork)
	box("BannerBacking", Vector3.ZERO, Vector3(4.4, 0.79, 0.08), mat("214e70"), panel)

func _railings() -> void:
	var posts: Array[Transform3D] = []
	var post_colors: Array[Color] = []
	var rails: Array[Transform3D] = []
	var rail_colors: Array[Color] = []
	var steps := 270
	var gate_start := road_distance - ROAD_HALF_WIDTH
	var gate_end := road_distance + ROAD_HALF_WIDTH
	for i in steps:
		var s: float = venue.lap_length_m * i / steps
		var next: float = s + venue.lap_length_m / steps
		if s < gate_start and next > gate_start:
			next = gate_start
		elif s >= gate_start and s < gate_end:
			if next <= gate_end: continue
			s = gate_end
		var a: Vector3 = track.at(s, RIM)
		var b: Vector3 = track.at(next, RIM)
		posts.append(Transform3D(Basis.IDENTITY, a + Vector3.UP * 0.56))
		post_colors.append(Color("255781"))
		for h in [0.42, 1.10]:
			var basis := Basis.looking_at(b - a).scaled_local(Vector3(1, 1, a.distance_to(b) + 0.025))
			rails.append(Transform3D(basis, (a + b) * 0.5 + Vector3.UP * h))
			rail_colors.append(Color("3976a0"))
	instances("BlueRailingPosts", Vector3(0.055, 1.14, 0.065), posts, post_colors)
	instances("BlueRailingRails", Vector3(0.045, 0.055, 1), rails, rail_colors)

func _build_road_access() -> void:
	var outward: Vector3 = track.outward(road_distance)
	var entry: Vector3 = track.at(road_distance, venue.track_outer_offset_m)
	var access := Node3D.new()
	access.name = "RoadAccess"
	access.transform = Transform3D(Basis(Vector3.UP.cross(outward), Vector3.UP, outward), entry)
	access.set_meta("track_distance_m", road_distance)
	add_child(access)
	var street_height := -entry.y - 0.033
	var ramp_end := 19.0
	var vertices := PackedVector3Array()
	for segment in 20:
		var z0 := ramp_end * segment / 20.0
		var z1 := ramp_end * (segment + 1) / 20.0
		var y0 := street_height * smoothstep(0.0, ramp_end, z0)
		var y1 := street_height * smoothstep(0.0, ramp_end, z1)
		var a := access.transform * Vector3(-ROAD_HALF_WIDTH, y0, z0)
		var b := access.transform * Vector3(ROAD_HALF_WIDTH, y0, z0)
		var c := access.transform * Vector3(-ROAD_HALF_WIDTH, y1, z1)
		var d := access.transform * Vector3(ROAD_HALF_WIDTH, y1, z1)
		vertices.append_array(PackedVector3Array([a, b, c, b, d, c]))
		for side in [-1.0, 1.0]:
			var x: float = side * ROAD_HALF_WIDTH
			var top0 := access.transform * Vector3(x, y0, z0)
			var top1 := access.transform * Vector3(x, y1, z1)
			var foot0 := access.transform * Vector3(x, street_height - 0.02, z0)
			var foot1 := access.transform * Vector3(x, street_height - 0.02, z1)
			vertices.append_array(PackedVector3Array([top0, top1, foot0, top1, foot1, foot0]))
	surface("RoadAccessRamp", vertices, mat("60615e")).reparent(access)
	box("RoadApproachAsphalt", Vector3(0, street_height - 0.022, 23.5), Vector3(6.2, 0.04, 9.0), mat("60615e"), access)
	box("OutsideServiceRoad", Vector3(0, street_height - 0.021, 29.6), Vector3(48.0, 0.04, 5.6), mat("535854"), access)
	for side in [-1.0, 1.0]:
		var x: float = side * ROAD_HALF_WIDTH
		for segment in 10:
			var z0 := ramp_end * segment / 10.0
			var z1 := ramp_end * (segment + 1) / 10.0
			var a := Vector3(x, street_height * smoothstep(0.0, ramp_end, z0) + 0.13, z0)
			var b := Vector3(x, street_height * smoothstep(0.0, ramp_end, z1) + 0.13, z1)
			var curb := box("RampEdge", (a + b) * 0.5, Vector3(0.16, 0.25, a.distance_to(b)), mat("a0a29a"), access)
			curb.basis = Basis.looking_at(b - a)
	var gate := Node3D.new()
	gate.name = "ClosedRoadGate"
	gate.position.z = 0.16
	access.add_child(gate)
	for h in [0.17, 1.08]:
		box("GateRail", Vector3(0, h, 0), Vector3(6.2, 0.05, 0.055), mat("345b76"), gate)
	for x in [-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH]:
		box("GatePost", Vector3(x, 0.59, 0), Vector3(0.13, 1.18, 0.13), mat("345b76"), access)
	for i in 23:
		box("GatePicket", Vector3(lerpf(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH, i / 22.0), 0.61, 0), Vector3(0.043, 0.96, 0.05), mat("345b76"), gate)
	for slot in [["TrackConnection", Vector3.ZERO], ["RoadApproach", Vector3(0, street_height, 26.0)]]:
		var marker := Marker3D.new()
		marker.name = slot[0]
		marker.position = slot[1]
		access.add_child(marker)

func _terrace_point(s: float, row: int) -> Vector3:
	var p: Vector3 = track.at(s, RIM + 1.05 + row * 0.91)
	p.y = track.at(s, RIM).y + 0.15 + row * 0.43
	return p

func _build_stands() -> void:
	_terrace(ROOF_START, ROOF_END, 9, true)
	var road_clearance := ROAD_HALF_WIDTH + 0.8
	for bounds in [[25.0, 73.0], [77.0, 136.0], [142.0, 217.0], [221.0, road_distance - road_clearance],
			[road_distance + road_clearance, 302.0], [306.0, 369.0], [374.0, 439.0]]:
		_terrace(bounds[0], bounds[1], 3, false)
	var outer: Vector3 = track.outward(0.0)
	var center: Vector3 = _terrace_point((ROOF_START + ROOF_END) * 0.5, 0)
	var roof_length := ROOF_END - ROOF_START + 1.0
	for section in [[ROOF_START - 0.5, -MEDIA_HALF_WIDTH, 5.7], [-MEDIA_HALF_WIDTH, MEDIA_HALF_WIDTH, 6.95],
			[MEDIA_HALF_WIDTH, ROOF_END + 0.5, 5.7]]:
		var base := _terrace_point((section[0] + section[1]) * 0.5, 0)
		var span: float = section[1] - section[0]
		var height: float = section[2]
		var roof := box("MainStandRoofSection", base + outer * 4.7 + Vector3.UP * height, Vector3(10.6, 0.27, span), mat("b7c8bd", 0.73))
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		box("MainStandFascia", base - outer * 0.62 + Vector3.UP * (height - 0.13), Vector3(0.23, 0.48, span), mat("f2eee1"))
	box("MainStandBrickBack", center + outer * 8.5 + Vector3.UP * 2.85, Vector3(0.28, 5.75, roof_length), mat("bd8b73"))
	for s in range(-55, 23, 8):
		if absf(s) < MEDIA_HALF_WIDTH: continue
		var base := _terrace_point(float(s), 0)
		box("RoofColumn", base - outer * 0.32 + Vector3.UP * 2.75, Vector3(0.12, 5.50, 0.12), mat("e8e5d9"))
		box("RoofSeam", base + outer * 4.7 + Vector3.UP * 5.85, Vector3(10.5, 0.025, 0.05), mat("899b97"))
	for s in [-MEDIA_HALF_WIDTH, MEDIA_HALF_WIDTH]:
		var base := _terrace_point(s, 0)
		box("MediaRoofColumn", base - outer * 0.32 + Vector3.UP * 3.43, Vector3(0.14, 6.86, 0.14), mat("e8e5d9"))
		box("MediaRoofEndPanel", base + outer * 4.7 + Vector3.UP * 6.32, Vector3(10.5, 1.24, 0.12), mat("aebeb3"))
	for s in [-45.0, -21.0, 12.0, 21.0]:
		_flag(_terrace_point(s, 0) + outer * 0.3 + Vector3.UP * 5.83, int(absf(s)) % 3, 1.8)
	var sign := label3("VÉLODROME DE ROUBAIX", center - outer * 0.77 + Vector3.UP * 5.59, 0.27, Color("294c62"))
	sign.rotation.y = atan2(-outer.x, -outer.z)
	_build_media_deck()

func _build_media_deck() -> void:
	var inward: Vector3 = -track.outward(0.0)
	var frame := Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	var deck: Vector3 = _terrace_point(0.0, 0) - inward * 6.60 + Vector3.UP * (8.0 * 0.43 + 0.11)
	var stand := Node3D.new()
	stand.name = "BroadcastDeck"
	stand.transform = Transform3D(frame, deck)
	add_child(stand)
	box("BroadcastPlinth", Vector3(0, -0.83, 0), Vector3(14.1, 1.43, 3.84), mat("687579"), stand)
	box("BroadcastFloor", Vector3(0, -0.18, 0), Vector3(14.1, 0.16, 3.84), mat("b4b9ae"), stand)
	var suite := CommentaryBox.build_at(self, Transform3D(frame, stand.to_global(Vector3(-3.45, 0, 0))), venue.shared_actors.broadcast_suite)
	suite.set_meta("tier", "upper_grandstand")
	var gallery := Node3D.new()
	gallery.name = "TVCameraGallery"
	gallery.position.x = 3.45
	stand.add_child(gallery)
	var navy := mat("213c50")
	var trim := mat("85989f", 0.56)
	box("GalleryRear", Vector3(0, 1.4, -1.67), Vector3(6.4, 2.8, 0.12), navy, gallery)
	box("GalleryRoof", Vector3(0, 2.89, 0), Vector3(6.4, 0.14, 3.52), navy, gallery)
	box("GalleryFront", Vector3(0, 0.43, 1.72), Vector3(6.4, 0.86, 0.11), navy, gallery)
	box("GalleryFrontRail", Vector3(0, 0.89, 1.72), Vector3(6.4, 0.065, 0.10), trim, gallery)
	for x in [-3.15, 3.15]:
		box("GalleryFrame", Vector3(x, 1.45, 1.72), Vector3(0.085, 2.90, 0.085), trim, gallery)
		box("GallerySide", Vector3(x, 0.44, 0), Vector3(0.10, 0.88, 3.38), navy, gallery)
	label3("TV  ·  ROUBAIX", Vector3(0, 0.49, 1.79), 0.32, Color("f4f3e9"), gallery)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.45, 1.15)
	fill.light_color = Color("e7eff8")
	fill.light_energy = 0.65
	fill.omni_range = 4.1
	gallery.add_child(fill)
	for x in [-1.72, 1.25]:
		var camera := MeshInstance3D.new()
		camera.name = "BroadcastCamera"
		camera.mesh = crowd.prop("tv_camera")
		camera.position = Vector3(x, 0, 0.87)
		camera.rotation.y = -0.28 if x < 0.0 else 0.51
		gallery.add_child(camera)
	var crew := {}
	for x in [-1.72, 1.25]:
		var p := gallery.to_global(Vector3(x, 0, 0.06))
		Crowd.add_to_group(crew, "stand_m_relaxed", Transform3D(frame, p), crowd.staff_look(rng, Color("2f516d"), 0.24))
	crowd.emit_group(self, crew, "BroadcastCameraCrew", [[0, 0.0, 0.0]])

func _terrace(start: float, end: float, rows: int, covered: bool) -> void:
	var vertices := PackedVector3Array()
	var steps := ceili((end - start) * 1.25)
	var people := {}
	for row in rows:
		for i in steps:
			var s0 := lerpf(start, end, float(i) / steps)
			var s1 := lerpf(start, end, float(i + 1) / steps)
			var a := _terrace_point(s0, row)
			var b := _terrace_point(s1, row)
			var c: Vector3 = a + track.outward(s0) * 0.91
			var d: Vector3 = b + track.outward(s1) * 0.91
			var drop := Vector3.UP * (a.y + 0.045 if row == 0 else 0.43)
			var drop_b := Vector3.UP * (b.y + 0.045 if row == 0 else 0.43)
			vertices.append_array(PackedVector3Array([a, b, c, b, d, c, a - drop, a, b, a - drop, b, b - drop_b]))
		var s := start + 0.35
		var row_density := 1.0 - pow(1.0 - density, 1.75 if covered else 1.24)
		while s < end - 0.35:
			var on_media_deck := covered and row >= 5 and absf(s) < MEDIA_HALF_WIDTH
			if not on_media_deck and fposmod(s - start + 4.8, 13.0) > 1.65 and rng.randf() < row_density:
				var inward: Vector3 = -track.outward(s)
				var p := _terrace_point(s, row) - inward * 0.43
				var variants: Array = Crowd.SEATED if covered else Crowd.STANDING
				var variant: String = variants[rng.randi_range(0, variants.size() - 1)]
				if covered: p.y += 0.17
				Crowd.add_to_group(people, variant, Transform3D(Basis(Vector3.UP.cross(inward), Vector3.UP, inward), p), crowd.random_look(rng))
			var rate: float = track.at(s + 0.10, RIM + 1.5 + row * 0.91).distance_to(track.at(s - 0.10, RIM + 1.5 + row * 0.91)) / 0.20
			s += 0.65 / maxf(rate, 1.0)
	surface("CoveredGrandstand" if covered else "OpenTerrace", vertices, mat("d2ccc0"))
	crowd.emit_group(self, people, "RoubaixSpectators", [[1, 0.0, 0.0]] if simple else [[0, 0.0, 35.0], [1, 35.0, 0.0]])

func _infield_public() -> void:
	var people := {}
	for row in 3:
		for i in 114:
			var x := -38.0 + i * 0.64
			if absf(x) < 2.05 or rng.randf() >= density: continue
			var p: Vector3 = infield.to_global(Vector3(x, 0, 4.15 + row * 0.48))
			if absf(x) < 16.8 and row > 0: continue
			var variant: String = Crowd.STANDING[rng.randi_range(0, Crowd.STANDING.size() - 1)]
			Crowd.add_to_group(people, variant, Transform3D(infield.global_basis.rotated(Vector3.UP, PI), p), crowd.random_look(rng))
	crowd.emit_group(self, people, "FinishPublic", [[1, 0.0, 0.0]] if simple else [[0, 0.0, 34.0], [1, 34.0, 0.0]])
	for x in [-36.0, -27.5, 29.0, 34.5]:
		_flag(infield.to_global(Vector3(x, 0, 5.0)), int(absf(x)) % 3, 3.75)
	var staff := {}
	for p in [Vector3(20.8, 0, 11.0), Vector3(24.2, 0, 11.4)]:
		Crowd.add_to_group(staff, "stand_m_relaxed", Transform3D(infield.global_basis, infield.to_global(p)), crowd.staff_look(rng, Color("344d65"), 0.22))
	crowd.emit_group(self, staff, "TechnicalStaff", [[0, 0.0, 0.0]])

func _flag(p: Vector3, country: int, height: float) -> void:
	box("FlagPole", p + Vector3.UP * height * 0.5, Vector3(0.045, height, 0.045), mat("d4d8cf"))
	var palette: Array = [["24477f", "f6f5eb", "d5343c"], ["29292b", "f4d04b", "c93137"], ["bb302f", "f1f0e9", "274572"]][country]
	var stride := 0.24 * height / 3.0
	for stripe in 3:
		var field := Vector3((stripe + 0.5) * stride, height - stride, 0)
		var size := Vector3(stride + 0.002, stride * 2.0, 0.022)
		if country == 2:
			field = Vector3(stride * 1.5, height - (stripe + 0.5) * stride * 0.67, 0)
			size = Vector3(stride * 3.0, stride * 0.67 + 0.002, 0.022)
		box("FlagCloth", p + field, size, mat(palette[stripe]))

func _build_surroundings() -> void:
	var foliage := SphereMesh.new()
	foliage.radial_segments = 8
	foliage.rings = 4
	var trees := MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	trees.use_colors = true
	trees.mesh = foliage
	trees.instance_count = 180
	for i in 90:
		var s: float = i * venue.lap_length_m / 90
		var offset := rng.randf_range(18.0, 26.0)
		var stand_distance: float = wrapf(s, -venue.lap_length_m * 0.5, venue.lap_length_m * 0.5)
		if stand_distance > ROOF_START - 8.0 and stand_distance < ROOF_END + 8.0: offset += 13.0
		var p: Vector3 = track.at(s, offset)
		p.y = -0.04
		var h := rng.randf_range(4.8, 10.2)
		if absf(s - road_distance) < ROAD_HALF_WIDTH + 5.2: p += track.outward(s) * 30.0
		box("TreeTrunk", p + Vector3.UP * h * 0.28, Vector3(0.33, h * 0.56, 0.35), mat("605345"))
		for j in 2:
			var scale3 := Vector3(h * rng.randf_range(0.64, 1.04), h * 0.76, h * 0.80)
			var center := p + Vector3((j - 0.5) * h * 0.42, h * (0.68 + j * 0.14), 0)
			trees.set_instance_transform(i * 2 + j, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(scale3), center))
			trees.set_instance_color(i * 2 + j, Color("213225").lerp(Color("4b633b"), rng.randf()))
	var canopy := MultiMeshInstance3D.new()
	canopy.name = "TreeCanopies"
	canopy.multimesh = trees
	var leaves := mat("ffffff").duplicate() as StandardMaterial3D
	leaves.vertex_color_use_as_albedo = true
	canopy.material_override = leaves
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canopy)
	for s in [-56.0, 24.0, 99.0, 189.0, 256.0, 349.0, 417.0]:
		var p: Vector3 = track.at(s, 17.7)
		p.y = 0
		box("FloodlightMast", p + Vector3.UP * 8.3, Vector3(0.21, 16.6, 0.23), mat("84928b"))
		box("FloodlightBar", p + Vector3.UP * 16.58, Vector3(0.31, 0.12, 3.05), mat("56696d"))
		for z in [-1.22, -0.61, 0, 0.61, 1.22]:
			box("FloodlightHead", p + Vector3(0, 16.53, z), Vector3(0.49, 0.205, 0.39), mat("dedacc"))
	for s in [-70.0, 33.0, 180.0, 217.0, 310.0, 423.0]:
		var p: Vector3 = track.at(s, 16.8)
		p.y = 2.1
		box("VenueBuilding", p, Vector3(4.6, 4.2, 8.0), mat("c9bda9"))
		box("BuildingRoof", p + Vector3.UP * 2.12, Vector3(4.9, 0.24, 8.3), mat("76868a"))
		for z in [-2.55, 0.0, 2.55]:
			for side in [-1, 1]:
				box("FacadeWindow", p + Vector3(2.31 * side, 0.45, z), Vector3(0.045, 1.0, 1.48), mat("577582", 0.43))
	for i in 12:
		var s: float = 28.0 + i * 36
		_flag(_terrace_point(s, 2), i % 3, 3.4)
