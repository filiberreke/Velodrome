extends Node3D
## Flags hang below the outer canopy, behind the last spectator row.
const Flags := preload("res://national_flags.gd")
const Countries := preload("res://rennersboxen/rider_box.gd").COUNTRIES
const OFFSET := 31.6
const TOP := 11.55
const HEIGHT := 1.65
const MAX_WIDTH := 3.3

func build(arena: Node3D) -> void:
	name = "NationalFlags"
	arena.add_child(self)
	for i in Countries.size():
		var country: String = Countries[i]
		var texture: Texture2D = Flags.texture(country)
		var ratio := float(texture.get_width()) / float(texture.get_height())
		var height := minf(HEIGHT, MAX_WIDTH / ratio)
		var width := height * ratio
		# Half-step avoids concentrating flags at the principal stadium axes.
		var s: float = (float(i) + 0.5) * arena.LAP / float(Countries.size())
		var flag := MeshInstance3D.new()
		flag.name = country
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		flag.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_BACK
		# Gentle fill keeps colours legible in the shadow of the canopy.
		material.emission_enabled = true
		material.emission_texture = texture
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 0.22
		flag.material_override = material
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flag.position = arena._stadium_point(s, OFFSET, TOP - height * 0.5)
		# Construct a right-handed basis explicitly: a reflected seat/sign basis
		# would mirror asymmetric flags (and reverse their culled front faces).
		var inward: Vector3 = -arena._outward(s)
		flag.basis = Basis(Vector3.UP.cross(inward).normalized(), Vector3.UP, inward)
		flag.set_meta("track_s", s)
		add_child(flag)
		# Dark top rail anchors each flag to the existing eave structure.
		var rail: MeshInstance3D = arena._box(arena._stadium_point(s, OFFSET, TOP + 0.04),
			Vector3(width + 0.12, 0.07, 0.07), arena._material("384b5d"), self)
		rail.name = country + "_rail"
		rail.basis = flag.basis
		# Two short hangers reach the underside of the existing sloping eave.
		var roof_height := lerpf(12.0, 12.8, (OFFSET - 28.8) / (32.6 - 28.8))
		var length := roof_height - TOP - 0.08
		for side in [-1.0, 1.0]:
			var centre: Vector3 = arena._stadium_point(s, OFFSET, TOP + 0.08 + length * 0.5)
			centre += flag.basis.x * width * 0.4 * float(side)
			var hanger: MeshInstance3D = arena._box(centre, Vector3(0.035, length, 0.035),
				arena._material("384b5d"), self)
			hanger.name = country + ("_hanger_left" if side < 0.0 else "_hanger_right")
