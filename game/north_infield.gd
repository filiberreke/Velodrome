extends "res://branded_kiosks.gd"
## Scenic mixed zone, relocated podium and northern food court.
## Route is deliberately open at both ends; no race or results logic is changed.
const TRUST: Texture2D = preload("res://assets/kiosks/trust-no-one-banner.png")
const WP: Texture2D = preload("res://assets/boarding/wielerpraat-boarding.png")
const JOURNALIST: PackedScene = preload("res://assets/people/journaliste_regenboog.glb")
const PRINT_SHADER: Shader = preload("res://wielerpraat_print.gdshader")
const WORDMARK_UV := Rect2(0.245, 0.245, 0.710, 0.360)
const MICROPHONE_UV := Rect2(0.068, 0.195, 0.170, 0.510)
const TENT_YELLOW := "ffd400"
const WP_BLUE := "1c4b91"

func build(infield: Node3D) -> Array[Node3D]:
	host = infield
	_north_terrace()
	var mixed := _root("WielerpraatMixedZone", Vector3(9.4, 0, 23))
	_mixed(mixed)
	var podium: Node3D = host._prop("podium", Vector3(9.4, 0, 16), -PI * 0.5, {"banner": "0b1a2d"}, 2.6)
	podium.name = "Podium"
	host._label(podium, "VELODROME 250", Vector3(0, 2.15, -0.84), 72, Color("f2c05e"))
	for i in range(5):
		host._person("stand_m_clap" if i % 2 == 0 else "stand_f_phone", Vector3(6.4, 0, 14 + float(i)), PI * 0.5)
	var beer := _root("BierTrustNoOne", Vector3(0, 0, 41.5))
	_beer(beer)
	var pizza := _root("PizzaOven", Vector3(7.2, 0, 36.5))
	_pizza(pizza)
	preload("res://north_bars.gd").new().build(host)
	for item in [mixed, beer, pizza]: _batch_static(item)
	return [mixed, podium, beer, pizza]

func _north_terrace() -> void:
	# Extend the paved plaza around the beer tent and pizza tables; keep clear
	# of the curved standing strip at the glass.
	var ground := _root("NoordelijkHorecaterras",Vector3.ZERO)
	var outline := [Vector3(-4.5,0.008,30.5),Vector3(12,0.008,30.5),Vector3(12,0.008,39),Vector3(7,0.008,44.5),Vector3(-4.5,0.008,44.5)]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for i in range(1,outline.size()-1):
		for vertex in [outline[0],outline[i],outline[i+1]]:
			vertices.append(vertex); normals.append(Vector3.UP)
	_surface(ground,vertices,normals,PackedVector2Array(),_mat("b3a481"),"Terrasvloer")

func _canopy(parent: Node3D, half_width: float, half_depth: float, color: String) -> void:
	var corners := [Vector3(-half_width, 2.45, -half_depth), Vector3(half_width, 2.45, -half_depth), Vector3(half_width, 2.45, half_depth), Vector3(-half_width, 2.45, half_depth)]
	for i in range(4):
		var a: Vector3 = corners[i]; var b: Vector3 = corners[(i + 1) % 4]
		var peak := Vector3(0, 3.18, 0)
		var normal := (b - a).cross(peak - a).normalized()
		if normal.y < 0: normal = -normal
		_surface(parent, PackedVector3Array([a,b,peak]), PackedVector3Array([normal,normal,normal]), PackedVector2Array(), _mat(color), "Tentdak")
		var edge := _box(parent, (a + b) * 0.5 - Vector3.UP * 0.12, Vector3(a.distance_to(b), 0.24, 0.045), color)
		edge.rotation.y = -atan2((b-a).z, (b-a).x)
	for p in corners: _cylinder(parent, Vector3(p.x, 1.22, p.z), 0.035, 2.44, color)

func _print_material() -> ShaderMaterial:
	if not materials.has("wp_print"):
		var material := ShaderMaterial.new()
		material.shader = PRINT_SHADER
		material.set_shader_parameter("logo",WP)
		materials["wp_print"] = material
	return materials["wp_print"]

func _logo_print(parent: Node3D, centre: Vector3, right: Vector3, up: Vector3, width: float, crop: Rect2, title: String) -> MeshInstance3D:
	# UV crops reuse the original logo without generating or changing image files.
	var height: float = width * float(WP.get_height()) * crop.size.y / (float(WP.get_width()) * crop.size.x)
	var normal := right.cross(up).normalized()
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
	for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
		vertices.append(centre + right * ((corner.x-0.5)*width) + up * ((0.5-corner.y)*height))
		normals.append(normal); uv.append(crop.position+corner*crop.size)
	return _surface(parent,vertices,normals,uv,_print_material(),title)

func _roof_microphones(parent: Node3D) -> void:
	var slope := (3.18-2.45)/1.55
	for i in range(4):
		var outward := Vector3(sin(float(i)*PI*0.5),0,cos(float(i)*PI*0.5))
		var normal := (Vector3.UP+outward*slope).normalized()
		var right := Vector3.UP.cross(outward).normalized()
		var up := (-outward+Vector3.UP*slope).normalized()
		var centre := outward*0.98+Vector3.UP*(3.18-0.98*slope)+normal*0.008
		_logo_print(parent,centre,right,up,0.78,MICROPHONE_UV,"Dakmicrofoon%d" % (i+1))
	parent.set_meta("roof_microphones",4)

func _mixed(parent: Node3D) -> void:
	_canopy(parent, 1.55, 1.55, WP_BLUE)
	_roof_microphones(parent)
	# Back wall lies on the track-facing east side; separate correctly oriented
	# artwork on each face avoids mirrored text when seen from the piste.
	_box(parent, Vector3(1.48, 1.18, 0), Vector3(0.06, 2.36, 3.05), WP_BLUE)
	var inside := _panel(parent, Vector3(1.441, 1.50, 0), 2.92, WP, -PI * 0.5)
	inside.name = "WielerpraatBinnenkant"
	var outside := _logo_print(parent, Vector3(1.519, 1.50, 0), Vector3(0,0,-1), Vector3.UP, 2.92, WORDMARK_UV, "WielerpraatPistekant")
	outside.name = "WielerpraatPistekant"
	# Continuous 2 m carpet, from north entrance through the tent to the podium.
	var route := _root("BlauweLoper", Vector3.ZERO, parent)
	_box(route, Vector3(-0.25, 0.025, 0.5), Vector3(2.0, 0.04, 11.0), WP_BLUE)
	parent.set_meta("route_start", Vector3(9.15, 0, 29))
	parent.set_meta("route_end", Vector3(9.15, 0, 18))
	parent.set_meta("open_passage_width", 2.0)
	parent.set_meta("branding_faces", 2)
	for z in [-4.1, -2.5, 2.5, 4.1, 5.7]:
		# Slim stanchions keep the path recognizable without closing its ends.
		for x in [-1.35, 0.85]:
			_cylinder(parent, Vector3(x, 0.47, z), 0.028, 0.94, "b8c8d0")
			_cylinder(parent, Vector3(x, 0.035, z), 0.15, 0.07, "303b49")
	var arrow: Label3D = host._label(parent, "PODIUM ↓", Vector3(-0.25, 0.053, -3.5), 55, Color.WHITE)
	arrow.rotation.x = -PI * 0.5
	# Interview tableau: cyclist in helmet and shorts, reporter, microphone, camera.
	_cyclist(parent, Vector3(0.35, 0, 0.15))
	var reporter := JOURNALIST.instantiate() as Node3D
	parent.add_child(reporter)
	reporter.name = "JournalisteRegenboog"
	reporter.position = Vector3(-0.80,0,0.1); reporter.rotation.y = PI*0.5
	var mic := _box(parent, Vector3(-0.28, 1.37, 0.12), Vector3(0.55, 0.045, 0.045), "252831")
	mic.rotation.z = 0.20
	_cylinder(parent, Vector3(-0.04, 1.44, 0.12), 0.07, 0.13, "151b26")
	_box(parent, Vector3(-0.09, 1.35, 0.12), Vector3(0.12, 0.12, 0.12), WP_BLUE)
	var camera: Node3D = host._prop("tv_camera", parent.position + Vector3(-2.5, 0, 0.1), PI * 0.5, {}, 0.6)
	camera.name = "MixedZoneCamera"
	_figure(parent,"staff_photographer",Vector3(-3.15,0,0.1),PI*0.5,"273038","ffffff")
	for z in [18.5, 21.5, 24.5, 27.5]: host.blockers.append([Vector2(9.15,z), 1.75])

func _figure(parent: Node3D, variant: String, at: Vector3, yaw: float, shirt: String, accent: String) -> void:
	if not materials.has("people"):
		var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true; material.roughness = 0.9
		materials["people"] = material
	var node := _mesh(parent,_staff_mesh(variant,shirt,accent),at,materials["people"],"InterviewPersoneel")
	node.rotation.y = yaw

func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: String) -> void:
	var limb := _cylinder(parent, (a+b)*0.5, radius, a.distance_to(b), color)
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	limb.basis = Basis(side, up, side.cross(up))

func _cyclist(parent: Node3D, at: Vector3) -> void:
	var rider := _root("RennerInterview", at, parent)
	var jersey := CapsuleMesh.new(); jersey.radius = 0.19; jersey.height = 0.53
	_mesh(rider,jersey,Vector3(0,1.18,0),_mat("eac736"))
	_box(rider, Vector3(0, 0.87, 0), Vector3(0.35, 0.22, 0.23), "162e4c")
	for x in [-0.105, 0.105]:
		_limb(rider, Vector3(x,0.86,0), Vector3(x,0.56,0.02), 0.086, "162e4c")
		_limb(rider, Vector3(x,0.56,0.02), Vector3(x,0.13,0), 0.060, "e7b38d")
		_box(rider, Vector3(x,0.075,-0.04), Vector3(0.13,0.13,0.25), "f2f2ee")
		_limb(rider, Vector3(signf(x)*0.22,1.39,0), Vector3(signf(x)*0.25,1.05,-0.04), 0.055, "e7b38d")
	var head := SphereMesh.new(); head.radius = 0.145; head.height = 0.31
	_mesh(rider, head, Vector3(0,1.65,0), _mat("e7b38d"))
	var helmet := SphereMesh.new(); helmet.radius = 0.163; helmet.height = 0.22
	_mesh(rider, helmet, Vector3(0,1.79,0), _mat("eac736"))
	for x in [-0.06,0.0,0.06]: _box(rider, Vector3(x,1.886,0), Vector3(0.018,0.018,0.17), "263143")
	_box(rider, Vector3(-0.143,1.67,0), Vector3(0.025,0.05,0.20), "263143")

func _beer(parent: Node3D) -> void:
	# Match the actual artwork background and light it exactly like tent fabric.
	# Unshaded artwork would remain neon-bright in the shadow of the canopy.
	var image := TRUST.get_image()
	var yellow := Color(0,0,0,0)
	for uv in [Vector2i(10,10),Vector2i(image.get_width()-11,10),Vector2i(10,image.get_height()-11),Vector2i(image.get_width()-11,image.get_height()-11)]:
		yellow += image.get_pixelv(uv) * 0.25
	_mat(TENT_YELLOW).albedo_color = yellow
	var banner_material := _texture(TRUST)
	banner_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	banner_material.roughness = _mat(TENT_YELLOW).roughness
	parent.set_meta("fabric_yellow",yellow)
	_canopy(parent, 3.0, 1.5, TENT_YELLOW)
	_box(parent, Vector3(0,1.16,1.46), Vector3(6.0,2.32,0.06), TENT_YELLOW)
	# Back faces the north bend, front opens south towards the infield.
	var banner := _panel(parent, Vector3(0,1.35,1.501), 5.82, TRUST)
	banner.name = "TrustNoOnePistekant"
	_box(parent, Vector3(0,0.49,-1.08), Vector3(5.7,0.98,0.64), TENT_YELLOW)
	_box(parent, Vector3(0,1.01,-1.16), Vector3(5.84,0.08,0.80), TENT_YELLOW)
	host._label(parent, "BIER", Vector3(0,2.49,-1.56), 100, Color("111111"), PI)
	for x in [-1.6,0.0,1.6]:
		_cylinder(parent, Vector3(x,1.25,-0.96), 0.035, 0.46, "b8c8d0")
		_box(parent, Vector3(x,1.47,-1.08), Vector3(0.06,0.07,0.28), "b8c8d0")
		_cylinder(parent, Vector3(x+0.20,1.15,-1.34), 0.065, 0.22, TENT_YELLOW)
		_figure(parent,"staff_vendor_m",Vector3(x,0,-0.30),PI,TENT_YELLOW,"111111")
	for i in range(5): host._person("stand_f_drink" if i % 2 else "stand_m_drink", Vector3(-2.4 + float(i)*1.1,0,38.8), 0)
	parent.set_meta("floor_area_m2", 18.0)
	parent.set_meta("previous_floor_area_m2", 9.0)
	host.blockers.append([Vector2(0,41.5), 3.6])

func _pizza(parent: Node3D) -> void:
	_box(parent, Vector3(0,0.55,0), Vector3(2.35,1.10,1.9), "b76d47")
	_box(parent, Vector3(0,1.13,0), Vector3(2.65,0.16,2.2), "d6c9aa")
	# Dome and a proper arched tunnel built from wedges, rather than a flat black sticker.
	var dome := SphereMesh.new(); dome.radius = 1.0; dome.height = 1.65; dome.is_hemisphere = true
	_mesh(parent, dome, Vector3(0,1.20,0.12), _mat("c37a4f"), "Ovenkoepel")
	_box(parent, Vector3(0,1.39,-1.02), Vector3(0.90,0.38,0.12), "201a17")
	for i in range(12):
		var a: float = PI * float(i) / 12.0; var b: float = PI * float(i+1) / 12.0
		var vertices := PackedVector3Array()
		for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
			var theta: float = lerpf(a,b,corner.x); var r: float = lerpf(0.44,0.62,corner.y)
			vertices.append(Vector3(cos(theta)*r,1.55+sin(theta)*r,-1.05))
		var normals := PackedVector3Array(); normals.resize(6); normals.fill(Vector3.FORWARD)
		var opening := PackedVector3Array([Vector3(0,1.55,-1.02), Vector3(cos(a)*0.44,1.55+sin(a)*0.44,-1.02), Vector3(cos(b)*0.44,1.55+sin(b)*0.44,-1.02)])
		_surface(parent,opening,PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]),PackedVector2Array(),_mat("201a17"),"Ovenopening")
		_surface(parent, vertices, normals, PackedVector2Array(), _mat("e4ba83" if i%2 else "b6613c"), "Ovenboog")
	_cylinder(parent, Vector3(0.43,2.43,0.35), 0.14, 1.40, "43494b")
	_cylinder(parent, Vector3(0.43,3.15,0.35), 0.23, 0.09, "43494b")
	_box(parent, Vector3(0,1.23,-1.00), Vector3(1.9,0.09,0.56), "d6c9aa")
	for x in [-0.25,0.10,0.35]:
		_cylinder(parent, Vector3(x,1.38,-1.04), 0.055,0.18,"ef872a",0)
	for x in [-0.34,0.31]:
		_cylinder(parent, Vector3(x,1.292,-1.10),0.25,0.035,"e6b361")
		_cylinder(parent, Vector3(x,1.314,-1.10),0.21,0.015,"b94b2d")
	host._label(parent, "PIZZA • HOUTOVEN", Vector3(0,0.72,-0.967), 45, Color("fff0d1"), PI)
	_figure(parent,"staff_vendor_f",Vector3(-1.35,0,-0.5),PI*0.5,"fff0d1","b94b2d")
	# Three genuinely seated tables, clear of the mixed-zone entrance and main bar.
	for i in range(3):
		var spots := [Vector3(-2.4,0,-3.4), Vector3(1.1,0,-3.8), Vector3(2.6,0,0.5)]
		var table := _root("Pizzatafel%d" % (i+1), spots[i], parent)
		table.set_meta("terrace_table",true)
		_cylinder(table,Vector3(0,0.73,0),0.64,0.08,"ae7842")
		_cylinder(table,Vector3(0,0.36,0),0.07,0.72,"394044")
		_cylinder(table,Vector3(0,0.04,0),0.32,0.08,"394044")
		for j in range(3):
			var angle: float = TAU * float(j)/3.0
			var at := Vector3(sin(angle),0,cos(angle))*1.04
			_chair(table,at,angle+PI,"6c5336")
			if j == i: _person(table,at,angle+PI,false,true)
		host.blockers.append([Vector2(parent.position.x+spots[i].x,parent.position.z+spots[i].z),1.7])
	parent.set_meta("seated_tables",3)
	host.blockers.append([Vector2(parent.position.x,parent.position.z),2.0])
