extends RefCounted
const VELODROME: Texture2D = preload("res://assets/boarding/velodrome-boarding.png")
const VELODROME_LIGHT: Texture2D = preload("res://assets/boarding/velodrome-boarding-licht.png")
const WIELERPRAAT: Texture2D = preload("res://assets/boarding/wielerpraat-boarding.png")
const PELOTON: Texture2D = preload("res://assets/boarding/pelotonpredictor-boarding.png")
const TOUR: Texture2D = preload("res://assets/boarding/tour-dambiance-vierkant.png")
const SJAMPANJE_WHITE: Texture2D = preload("res://assets/boarding/sjampanje-ivoor.png")
const SJAMPANJE_GREEN: Texture2D = preload("res://assets/boarding/sjampanje-groen.png")
const POSTER_SHADER: Shader = preload("res://boarding_sponsors.gdshader")
const OFFSET := 9.10
const INSET := 0.035
const BASE := 0.02
const HEIGHT := 1.20

static func covered(game: Node3D, distance: float) -> bool:
	var s: float = fposmod(distance, game.LAP)
	return s < PI * game.RADIUS or s >= game.LAP - game.STRAIGHT or (s >= game.LAP*0.5 and s < game.LAP*0.5+PI*game.RADIUS)

static func build(arena: Node3D) -> void:
	var game: Node3D = arena.main
	# An even panel count means blue/light alternation ends in light before the bend.
	_section(arena, game.LAP - game.STRAIGHT, game.LAP, [VELODROME, VELODROME_LIGHT], "VelodromeLaatsteRechteLijn")
	_section(arena, 0.0, PI * game.RADIUS, [WIELERPRAAT, PELOTON], "SponsorsEersteBocht", true)
	_north_section(arena)

static func _section(arena: Node3D, start: float, end: float, posters: Array, title: String, normalize_blue: bool = false) -> void:
	# Use physical wall length, including its larger curve radius and bank transitions.
	var physical_length := 0.0
	var previous: Vector3 = arena._point(start, OFFSET)
	for i in range(1, 257):
		var next: Vector3 = arena._point(lerpf(start, end, float(i) / 256.0), OFFSET)
		physical_length += previous.distance_to(next)
		previous = next
	var aspect: float = float(posters[0].get_width()) / float(posters[0].get_height())
	var cycles: int = maxi(1, roundi(physical_length / (HEIGHT * aspect * posters.size())))
	var count: int = cycles * posters.size()
	for sponsor in range(posters.size()):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for panel in range(sponsor, count, posters.size()):
			var a: float = lerpf(start, end, float(panel) / float(count))
			var b: float = lerpf(start, end, float(panel + 1) / float(count))
			for segment in range(16):
				for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var along: float = (float(segment) + corner.x) / 16.0
					var distance: float = lerpf(a, b, along)
					var outward: Vector3 = arena._outward(distance)
					var point: Vector3 = arena._point(distance, OFFSET) - outward * INSET
					vertices.append(point + Vector3.UP * (BASE + corner.y * HEIGHT))
					normals.append(-outward)
					# From inside the arena, increasing travel distance points left.
					uvs.append(Vector2(1.0 - along, 1.0 - corner.y))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "%s_%d" % [title, sponsor]
		node.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = POSTER_SHADER
		material.set_shader_parameter("poster", posters[sponsor])
		material.set_shader_parameter("match_blue", normalize_blue)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("start_m", start)
		node.set_meta("end_m", end)
		node.set_meta("total_panels", count)
		arena.add_child(node)

static func _north_section(arena: Node3D) -> void:
	var game: Node3D = arena.main
	var start: float = game.LAP*0.5; var end: float = start+PI*game.RADIUS
	var physical := 0.0; var previous: Vector3 = arena._point(start,OFFSET)
	for i in range(1,257):
		var next: Vector3 = arena._point(lerpf(start,end,float(i)/256.0),OFFSET)
		physical += previous.distance_to(next); previous = next
	var tour_aspect := float(TOUR.get_width())/float(TOUR.get_height())
	var white_aspect := float(SJAMPANJE_WHITE.get_width())/float(SJAMPANJE_WHITE.get_height())
	var green_aspect := float(SJAMPANJE_GREEN.get_width())/float(SJAMPANJE_GREEN.get_height())
	var cycles := maxi(1,roundi((physical/HEIGHT-tour_aspect)/(tour_aspect+white_aspect+green_aspect)))
	# Increasing race distance runs LEFT when viewed from the infield.
	# Reverse the pair so the visible left-to-right sequence is Tour / white / green / Tour.
	var sequence: Array[Texture2D] = [TOUR]
	for i in range(cycles): sequence.append_array([SJAMPANJE_GREEN,SJAMPANJE_WHITE,TOUR])
	var total := 0.0
	for texture in sequence: total += float(texture.get_width())/float(texture.get_height())
	var layout: Array = []; var offset := 0.0
	for index in range(sequence.size()):
		var texture: Texture2D = sequence[index]
		var units := float(texture.get_width())/float(texture.get_height())
		var a: float = lerpf(start,end,offset/total)
		var b: float = lerpf(start,end,(offset+units)/total)
		layout.append({"texture":texture.resource_path,"start":a,"end":b,"index":index})
		offset += units
	var group := Node3D.new(); group.name = "NoordbochtSponsors"; arena.add_child(group)
	group.set_meta("panels",layout); group.set_meta("start_m",start); group.set_meta("end_m",end)
	group.set_meta("visual_order","Tour / Sjampanje wit / Sjampanje groen / Tour")
	for texture in [TOUR,SJAMPANJE_WHITE,SJAMPANJE_GREEN]:
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
		for panel in layout:
			if panel["texture"] != texture.resource_path: continue
			for segment in range(16):
				for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
					var along: float = (float(segment)+corner.x)/16.0
					var distance: float = lerpf(panel["start"],panel["end"],along)
					var outward: Vector3 = arena._outward(distance)
					var point: Vector3 = arena._point(distance,OFFSET)-outward*INSET
					vertices.append(point+Vector3.UP*(BASE+corner.y*HEIGHT)); normals.append(-outward)
					uv.append(Vector2(1.0-along,1.0-corner.y))
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node := MeshInstance3D.new(); node.name = texture.resource_path.get_file().get_basename()
		node.mesh = mesh; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new(); material.shader = POSTER_SHADER
		material.set_shader_parameter("poster",texture); node.material_override = material
		group.add_child(node)
