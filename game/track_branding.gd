extends RefCounted
## A subdivided surface follows the existing curved, banked track without collision.
const LOGO: Texture2D = preload("res://assets/branding/tour_d_ambiance.png")
const INNER := 4.0
const OUTER := 8.4
const LIFT := 0.006

static func build(game: Node3D) -> MeshInstance3D:
	# The final bend before the home straight, in the actual riding direction.
	var center: float = game.LAP - game.STRAIGHT - PI * game.RADIUS * 0.5
	var middle := (INNER + OUTER) * 0.5
	# Preserve the source aspect on the physical banked surface, not its top view.
	var height: float = (game._at(center, OUTER) - game._at(center, INNER)).length()
	var length: float = height * float(LOGO.get_width()) / float(LOGO.get_height())
	var extent: float = length / game._path_metric(center, middle)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(48):
		for j in range(12):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var along: float = (float(i) + corner.x) / 48.0
				var across: float = (float(j) + corner.y) / 12.0
				var distance: float = center + (along - 0.5) * extent
				var lane: float = lerpf(INNER, OUTER, across)
				var normal: Vector3 = game._track_normal(distance, lane)
				vertices.append(game._at(distance, lane) + normal * LIFT)
				normals.append(normal)
				# Upright from the infield: image top points up the bank, to the outside.
				uvs.append(Vector2(1.0 - along, 1.0 - across))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mark := MeshInstance3D.new()
	mark.name = "TourDAmbianceLaatsteBocht"
	mark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = LOGO
	material.texture_repeat = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(mark)
	return mark
