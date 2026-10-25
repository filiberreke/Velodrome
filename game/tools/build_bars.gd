extends SceneTree
## Offline scene builder. Saved scenes are ordinary reusable Node3D scenes.
const ROOT := "res://scenes/bars/"
var mats := {}
var cylinder_meshes := {}

func _initialize() -> void: call_deferred("build_all")

func material(hex: String, gold: bool = false) -> StandardMaterial3D:
	var key := hex + str(gold)
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new(); m.resource_name = key
	var image := Image.create(2,2,false,Image.FORMAT_RGB8); image.fill(Color(hex))
	m.albedo_color = Color.WHITE; m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 0.75
	if gold: m.metallic = 0.45; m.roughness = 0.4
	mats[key] = m; return m

func group(parent: Node3D, title: String) -> Node3D:
	var g := Node3D.new(); g.name = title; parent.add_child(g); return g

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material, title: String) -> MeshInstance3D:
	var item := MeshInstance3D.new(); item.name = title
	item.mesh = shape; item.material_override = mat; item.position = pos
	parent.add_child(item); return item

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String, title: String, gold: bool = false) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return mesh(parent,b,pos,material(color,gold),title)

func cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: String, title: String, gold: bool = false) -> MeshInstance3D:
	var key := "%f_%f_%f" % [bottom,top,height]
	if not cylinder_meshes.has(key):
		var c := CylinderMesh.new(); c.bottom_radius = bottom; c.top_radius = top
		c.height = height; c.radial_segments = 12; c.rings = 1
		cylinder_meshes[key] = c
	return mesh(parent,cylinder_meshes[key],pos,material(color,gold),title)

func surface(parent: Node3D, v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, mat: Material, title: String) -> MeshInstance3D:
	# Godot front faces wind clockwise.
	for i in range(0,v.size(),3):
		if (v[i+1]-v[i]).cross(v[i+2]-v[i]).dot(n[i]) > 0:
			var p := v[i+1]; v[i+1] = v[i+2]; v[i+2] = p
			var normal := n[i+1]; n[i+1] = n[i+2]; n[i+2] = normal
			if not uv.is_empty():
				var t := uv[i+1]; uv[i+1] = uv[i+2]; uv[i+2] = t
	var a: Array = []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v; a[Mesh.ARRAY_NORMAL] = n
	if not uv.is_empty(): a[Mesh.ARRAY_TEX_UV] = uv
	var shape := ArrayMesh.new(); shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	return mesh(parent,shape,Vector3.ZERO,mat,title)

func print_material(path: String) -> StandardMaterial3D:
	if mats.has(path): return mats[path]
	var m := StandardMaterial3D.new(); m.resource_name = path.get_file().get_basename()
	var texture: Texture2D = load(path)
	if texture is AtlasTexture:
		m.albedo_texture = texture.atlas
		var scale: Vector2 = texture.region.size / texture.atlas.get_size()
		var offset: Vector2 = texture.region.position / texture.atlas.get_size()
		m.uv1_scale = Vector3(scale.x,scale.y,1); m.uv1_offset = Vector3(offset.x,offset.y,0)
	else: m.albedo_texture = texture
	m.roughness = 0.75; m.texture_repeat = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mats[path] = m; return m

func atlas(title: String, source: String, uv: Rect2) -> String:
	var original: Texture2D = load(source)
	var texture := AtlasTexture.new(); texture.atlas = original
	texture.region = Rect2(uv.position*original.get_size(),uv.size*original.get_size())
	texture.filter_clip = true
	var path := "res://assets/bars/"+title+".tres"
	assert(ResourceSaver.save(texture,path) == OK)
	return path

func panel(parent: Node3D, pos: Vector3, size: Vector2, path: String, yaw: float, title: String) -> MeshInstance3D:
	var quad := QuadMesh.new(); quad.size = size
	var item := mesh(parent,quad,pos,print_material(path),title); item.rotation.y = yaw
	return item

func collision(parent: StaticBody3D, pos: Vector3, size: Vector3, yaw: float, title: String) -> void:
	var shape := BoxShape3D.new(); shape.size = size
	var item := CollisionShape3D.new(); item.name = title; item.shape = shape
	item.position = pos; item.rotation.y = yaw; parent.add_child(item)

func bottle(parent: Node3D, pos: Vector3, color: String, title: String) -> void:
	var b := group(parent,title); b.position = pos
	cylinder(b,Vector3(0,0.12,0),0.045,0.045,0.24,color,"Body")
	cylinder(b,Vector3(0,0.265,0),0.045,0.018,0.05,color,"Shoulder")
	cylinder(b,Vector3(0,0.325,0),0.018,0.018,0.07,"c7a24b","Foil",true)
	cylinder(b,Vector3(0,0.17,0),0.046,0.046,0.065,"fff3d1","Label")
	for child in b.get_children():
		if child is GeometryInstance3D: child.visibility_range_end = 30.0

func build_sjampanje(header: String, rear: String, crest: String) -> Node3D:
	var root_bar := Node3D.new(); root_bar.name = "SjampanjeBar"
	var structure := group(root_bar,"Structure"); var counter := group(root_bar,"Counter")
	var branding := group(root_bar,"Branding"); var interior := group(root_bar,"Interior")
	var solid := StaticBody3D.new(); solid.name = "Collision"; root_bar.add_child(solid)
	var step := TAU/12.0; var radius := 2.0; var apothem: float = radius*cos(step*0.5)
	var width: float = 2.0*radius*sin(step*0.5)
	for i in range(12):
		var angle: float = PI+float(i)*step
		var normal := Vector3(sin(angle),0,cos(angle))
		var open := i in [0,1,11]
		if not open:
			var wall := box(structure,normal*apothem+Vector3.UP*1.2,Vector3(width,2.4,0.07),"064a32","WallFacet%02d" % i)
			wall.rotation.y = angle
			collision(solid,wall.position,Vector3(width,2.4,0.07),angle,"Wall%02d" % i)
			var lining := panel(interior,normal*(apothem-0.041)+Vector3.UP*1.30,Vector2(width-0.06,2.10),"res://assets/bars/ivory.tres",angle+PI,"IvoryLining%02d" % i)
			lining.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			for band in [Vector2(0.525,1.05),Vector2(2.225,0.35)]:
				var wall := box(structure,normal*apothem+Vector3.UP*band.x,Vector3(width,band.y,0.07),"064a32","HatchWall%02d" % i)
				wall.rotation.y = angle
				collision(solid,wall.position,Vector3(width,band.y,0.07),angle,"HatchCollision%02d" % i)
		# Vertical gold strips follow each wall joint, with no posts in the opening.
		var edge: float = angle-step*0.5
		if i not in [0,1]: box(structure,Vector3(sin(edge)*2.01,1.2,cos(edge)*2.01),Vector3(0.045,2.4,0.045),"c7a24b","GoldPost%02d" % i,true)
	# Faceted bottom and eave trims.
	for y in [0.055,2.395]:
		for i in range(12):
			var angle: float = PI+float(i)*step
			var trim_radius := 2.055 if y>2.0 else 1.98
			var trim := box(structure,Vector3(sin(angle)*trim_radius,y,cos(angle)*trim_radius),Vector3(2.0*trim_radius*tan(step*0.5),0.08,0.04),"c7a24b","GoldTrim",true)
			trim.rotation.y = angle
	var roof_v := PackedVector3Array(); var roof_n := PackedVector3Array()
	for i in range(12):
		var a: float = PI+(float(i)-0.5)*step; var b := a+step; var mid := (a+b)*0.5
		var normal := Vector3(sin(mid)*0.85,1.575*cos(step*0.5),cos(mid)*0.85).normalized()
		for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
			var angle: float = lerpf(a,b,corner.x); var radius_roof: float = lerpf(2.1,0.525,corner.y)
			roof_v.append(Vector3(sin(angle)*radius_roof,2.4+corner.y*0.85,cos(angle)*radius_roof)); roof_n.append(normal)
	surface(structure,roof_v,roof_n,PackedVector2Array(),material("064a32"),"ShoulderRoof")
	cylinder(structure,Vector3(0,3.79,0),0.525,0.525,1.08,"c7a24b","BottleNeck",true)
	cylinder(structure,Vector3(0,4.36,0),0.58,0.58,0.08,"c7a24b","Cap",true)
	# Worktop across the three front facets, one section per facet.
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for j in range(3):
		var a: float = PI-step*1.5+float(j)*step; var b := a+step
		var centre: float = (a+b)*0.5
		var top := box(counter,Vector3(sin(centre)*1.9,1.055,cos(centre)*1.9),Vector3(width+0.08,0.09,0.45),"25312d","Worktop%d" % j)
		top.rotation.y = centre
		var gold := box(counter,Vector3(sin(centre)*2.13,1.06,cos(centre)*2.13),Vector3(width+0.08,0.055,0.03),"c7a24b","CounterGoldEdge",true)
		gold.rotation.y = centre
		for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
			var pa := Vector3(sin(a)*2.055,0,cos(a)*2.055)
			var pb := Vector3(sin(b)*2.055,0,cos(b)*2.055)
			vertices.append(pa.lerp(pb,corner.x)+Vector3.UP*(0.025+corner.y*1.01))
			normals.append(Vector3(sin(centre),0,cos(centre)))
			uvs.append(Vector2((float(j)+corner.x)/3.0,1.0-corner.y))
	surface(branding,vertices,normals,uvs,print_material("res://assets/bars/sjampanje_counter_label.png"),"CounterLabel")
	panel(branding,Vector3(0,2.225,-1.976),Vector2(1.52,0.335),header,PI,"Header")
	panel(branding,Vector3(0,3.82,-0.541),Vector2(0.46,0.41),crest,PI,"NeckCrest")
	panel(branding,Vector3(0,3.82,0.541),Vector2(0.46,0.41),crest,0,"NeckCrestRear")
	# Closed decorative service door on the rear facet, with an actual solid collider.
	box(structure,Vector3(0,1.01,apothem+0.043),Vector3(0.88,2.0,0.025),"123d2d","RearDoor")
	for x in [-0.46,0.46]: box(structure,Vector3(x,1.03,apothem+0.06),Vector3(0.025,2.06,0.025),"c7a24b","DoorFrame",true)
	box(structure,Vector3(0,2.055,apothem+0.06),Vector3(0.94,0.025,0.025),"c7a24b","DoorLintel",true)
	box(structure,Vector3(0.30,1.0,apothem+0.087),Vector3(0.15,0.03,0.04),"c7a24b","DoorHandle",true)
	var rear_angle := -PI/6.0
	panel(branding,Vector3(sin(rear_angle)*(apothem+0.05),1.40,cos(rear_angle)*(apothem+0.05)),Vector2(0.95,0.50),rear,rear_angle,"RearLabel")
	for y in [0.93,1.57]:
		box(interior,Vector3(0,y,1.30),Vector3(2.1,0.065,0.30),"25312d","Shelf")
		for x in [-0.75,-0.35,0.35,0.75]: bottle(interior,Vector3(x,y+0.04,1.30),"064a32","ChampagneBottle")
	for x in [-0.9,-0.6,0.65,0.9]:
		var glass := group(interior,"Flute"); glass.position = Vector3(x,1.11,-1.75)
		cylinder(glass,Vector3(0,0.008,0),0.035,0.035,0.015,"fff3d1","Foot")
		cylinder(glass,Vector3(0,0.065,0),0.006,0.006,0.12,"fff3d1","Stem")
		cylinder(glass,Vector3(0,0.18,0),0.025,0.034,0.13,"e5d5a8","OpaqueCup")
		for child in glass.get_children():
			if child is GeometryInstance3D: child.visibility_range_end = 25.0
	var actors := group(root_bar,"Actors")
	var bartender := load("res://assets/bars/hosts/sjampanje_tooguitbater.glb").instantiate() as Node3D
	actors.add_child(bartender); bartender.name = "ToogUitbater"
	bartender.position = Vector3(0.30,0,-1.15); bartender.rotation.y = PI
	var server := load("res://assets/bars/hosts/sjampanje_plateauuitbater.glb").instantiate() as Node3D
	actors.add_child(server); server.name = "PlateauUitbater"
	server.position = Vector3(-2.75,0,-1.2); server.rotation.y = PI
	root_bar.set_meta("footprint",Vector2(4,4)); root_bar.set_meta("height_m",4.4)
	root_bar.set_meta("front_direction",Vector3.FORWARD)
	return root_bar

func build_pursoet(word: String, badge: String) -> Node3D:
	var root_bar := Node3D.new(); root_bar.name = "PursoetBar"
	var frame := group(root_bar,"Frame"); var fabric := group(root_bar,"Fabric")
	var counter := group(root_bar,"Counter"); var branding := group(root_bar,"Branding")
	var props := group(root_bar,"Props")
	var solid := StaticBody3D.new(); solid.name = "Collision"; root_bar.add_child(solid)
	for x in [-1.5,1.5]:
		for z in [-1.5,1.5]:
			box(frame,Vector3(x,1.1,z),Vector3(0.07,2.2,0.07),"004d50","Post")
			box(frame,Vector3(x,0.025,z),Vector3(0.20,0.05,0.20),"004d50","Foot")
			collision(solid,Vector3(x,1.1,z),Vector3(0.07,2.2,0.07),0,"PostCollision")
	var corners := [Vector3(-1.6,2.2,-1.6),Vector3(1.6,2.2,-1.6),Vector3(1.6,2.2,1.6),Vector3(-1.6,2.2,1.6)]
	for i in range(4):
		var a: Vector3 = corners[i]; var b: Vector3 = corners[(i+1)%4]; var peak := Vector3(0,3.1,0)
		var normal := (a-peak).cross(b-peak).normalized()
		if normal.y < 0: normal = -normal
		surface(fabric,PackedVector3Array([a,b,peak]),PackedVector3Array([normal,normal,normal]),PackedVector2Array(),material("ff7900"),"Roof%d" % i)
		# Separate inside face for an opaque fabric canopy seen from below.
		surface(fabric,PackedVector3Array([a-Vector3.UP*0.012,b-Vector3.UP*0.012,peak-Vector3.UP*0.012]),PackedVector3Array([-normal,-normal,-normal]),PackedVector2Array(),material("ff7900"),"RoofInside%d" % i)
		var trim := box(fabric,(a+b)*0.5-Vector3.UP*0.125,Vector3(a.distance_to(b),0.25,0.035),"ff7900","Valance%d" % i)
		trim.rotation.y = -atan2((b-a).z,(b-a).x)
		var beam := box(frame,(a+b)*0.5-Vector3.UP*0.28,Vector3(a.distance_to(b),0.045,0.045),"004d50","Beam")
		beam.rotation.y = trim.rotation.y
	box(fabric,Vector3(0,1.0,1.475),Vector3(3,2.0,0.025),"ff7900","RearWall")
	box(fabric,Vector3(-1.475,1.0,0),Vector3(0.025,2.0,3),"ff7900","LeftSideWall")
	collision(solid,Vector3(0,1.0,1.475),Vector3(3,2.0,0.025),0,"RearWallCollision")
	collision(solid,Vector3(-1.475,1.0,0),Vector3(0.025,2.0,3),0,"LeftWallCollision")
	box(counter,Vector3(0,0.49,-1.15),Vector3(2.65,0.98,0.50),"ff7900","OrangeFront")
	box(counter,Vector3(0,1.0,-1.15),Vector3(2.75,0.06,0.59),"004d50","Worktop")
	collision(solid,Vector3(0,0.5,-1.15),Vector3(2.65,1.0,0.5),0,"CounterCollision")
	box(props,Vector3(0,0.92,0.95),Vector3(2.4,0.06,0.45),"004d50","RearWorktop")
	# Explicit independent print faces; never show mirrored reverse artwork.
	panel(branding,Vector3(0,2.075,-1.626),Vector2(0.68,0.24),word,PI,"FrontValance")
	panel(branding,Vector3(0,2.075,1.626),Vector2(0.68,0.24),word,0,"RearValance")
	panel(branding,Vector3(0,0.49,-1.407),Vector2(2.54,0.847),"res://assets/bars/pursoet_identity.png",PI,"CounterPrint")
	panel(branding,Vector3(0,1.05,1.494),Vector2(2.7,0.9),"res://assets/bars/pursoet_identity.png",0,"RearPrint")
	panel(branding,Vector3(-1.493,1.12,0),Vector2(1.18,1.18),badge,-PI*0.5,"SideBadge")
	for x in [-0.95,-0.65,0.65,0.95]: bottle(props,Vector3(x,1.035,-1.12),"ff7900","SodaBottle")
	root_bar.set_meta("footprint",Vector2(3,3)); root_bar.set_meta("height_m",3.1)
	root_bar.set_meta("front_direction",Vector3.FORWARD)
	return root_bar

func own(node: Node, root_bar: Node) -> void:
	for child in node.get_children():
		child.owner = root_bar
		if child.scene_file_path.is_empty(): own(child,root_bar)

func save_scene(root_bar: Node3D, name_text: String) -> void:
	own(root_bar,root_bar)
	var packed := PackedScene.new(); assert(packed.pack(root_bar) == OK)
	assert(ResourceSaver.save(packed,ROOT+name_text+".tscn") == OK)
	root_bar.free()

func build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	# Tiny opaque solid texture for the ivory lining, shared with ordinary prints.
	var image := Image.create(2,2,false,Image.FORMAT_RGB8); image.fill(Color("fff3d1"))
	var ivory := ImageTexture.create_from_image(image); assert(ResourceSaver.save(ivory,"res://assets/bars/ivory.tres") == OK)
	var header := atlas("sjampanje_header","res://assets/bars/sjampanje_identity.png",Rect2(0.02,0.43,0.63,0.43))
	var crest := atlas("sjampanje_crest","res://assets/bars/sjampanje_identity.png",Rect2(0.285,0.045,0.16,0.38))
	var rear := atlas("sjampanje_rear","res://assets/bars/sjampanje_counter_label.png",Rect2(0.015,0.025,0.625,0.93))
	var word := atlas("pursoet_wordmark","res://assets/bars/pursoet_identity.png",Rect2(0.30,0.055,0.69,0.72))
	var badge := atlas("pursoet_badge","res://assets/bars/pursoet_identity.png",Rect2(0.015,0.05,0.29,0.87))
	save_scene(build_sjampanje(header,rear,crest),"SjampanjeBar")
	save_scene(build_pursoet(word,badge),"PursoetBar")
	print("BARS_BUILD_OK"); quit()
