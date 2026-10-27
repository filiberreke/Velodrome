extends Node3D
## Non-physical front/rear strips. Geometry uses the same track transform as riders.
var strips: Array[MeshInstance3D] = []
var captions: Array[Label3D] = []
const COLOURS := [Color("f6aa46"),Color("51e4e9")]

func _ready() -> void:
	for i in range(2):
		var strip := MeshInstance3D.new()
		strip.mesh = ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.albedo_color = Color(COLOURS[i],0.75)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		strip.material_override = material
		strip.layers = 2
		add_child(strip); strips.append(strip)
		var caption := Label3D.new()
		caption.text = "KOP PELOTON" if i == 0 else "STAART PELOTON"
		caption.modulate = COLOURS[i]
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.no_depth_test = true
		caption.pixel_size = 0.006
		caption.font_size = 40
		caption.outline_size = 10
		caption.layers = 2
		add_child(caption); captions.append(caption)
	hide()

func update_bunch(game, bunch: Dictionary, active: bool) -> void:
	visible = active and not bunch.is_empty()
	if not visible: return
	for i in range(2):
		var distance: float = float(bunch.front if i == 0 else bunch.tail)-game.FRONT_WHEEL_TIP_M
		var mesh: ImmediateMesh = strips[i].mesh
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for lane in range(8):
			var inner: float = 0.9+lane*1.0
			var outer: float = inner+1.0
			var a: Vector3 = game._at(distance-0.18,inner)+Vector3.UP*0.12
			var b: Vector3 = game._at(distance+0.18,inner)+Vector3.UP*0.12
			var c: Vector3 = game._at(distance+0.18,outer)+Vector3.UP*0.12
			var d: Vector3 = game._at(distance-0.18,outer)+Vector3.UP*0.12
			for vertex in [a,b,c,a,c,d]: mesh.surface_add_vertex(vertex)
		mesh.surface_end()
		captions[i].position = game._at(distance,8.5)+Vector3.UP*(2.8 if i == 0 else 1.9)
