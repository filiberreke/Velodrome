extends Node3D
## Shared construction helpers for Gent; dimensions are world metres.
var track: RefCounted
var venue: Resource
var materials := {}
func red_logo_material(aspect:float,two_sided:bool=false)->ShaderMaterial:
	var key:="white_velodrome_red_"+str(aspect)+str(two_sided)
	if materials.has(key):return materials[key]
	var material:=ShaderMaterial.new();material.shader=preload("res://venues/gent/white_logo_red.gdshader")
	material.set_shader_parameter("wordmark",preload("res://assets/branding/velodrome_wordmark.png"))
	material.set_shader_parameter("panel_aspect",aspect)
	material.set_shader_parameter("two_sided_banner",two_sided);materials[key]=material
	return material

func branding_ring(label:String,offset:float,lift:float,height:float,count:int,flat:bool=false)->void:
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array()
	for i in count:
		var centre:float=venue.lap_length_m*(float(i)+.5)/float(count)
		var speed:float=track.at(centre+.1,offset).distance_to(track.at(centre-.1,offset))/.2
		var span:=4.2/maxf(.2,speed)
		for segment in 16:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var along:float=(float(segment)+corner.x)/16.0
				var p:Vector3=track.at(centre+(along-.5)*span,offset)
				if flat:p.y=0.0
				vertices.append(p+Vector3.UP*(lift+corner.y*height))
				# The shared shader prints a readable logo on both banner faces.
				uv.append(Vector2(1.0-along,1.0-corner.y))
	var panel:=surface(label,vertices,red_logo_material(4.2/height,true),uv)
	panel.set_meta("brand_panels",count)

func branding_track(start:float,length:float)->void:
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array()
	for segment in 40:
		for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			var along:float=(float(segment)+corner.x)/40.0
			vertices.append(track.at(start+along*length,lerpf(4.7,7.4,corner.y))+Vector3.UP*.025)
			uv.append(Vector2(1.0-along,1.0-corner.y))
	var middle:=start+length*.5
	var width:float=track.at(middle+.1,6.05).distance_to(track.at(middle-.1,6.05))/.2*length
	surface("GentWhiteLogoRedTrackPanel%d"%roundi(start),vertices,red_logo_material(width/2.7),uv)

func mat(hex: String, rough := 0.85, glow := 0.0) -> StandardMaterial3D:
	var key := hex + str(rough) + str(glow)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex); m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = glow
	materials[key] = m
	return m
func box(label: String, p: Vector3, size3: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var n := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size3
	n.name = label; n.mesh = b; n.material_override = material; n.position = p
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n); return n
func beam(label: String, a: Vector3, b: Vector3, width: float, material: Material, parent: Node3D = self) -> void:
	var n := box(label, (a+b)*0.5, Vector3(width,width,a.distance_to(b)), material, parent)
	n.look_at_from_position((a+b)*0.5,b,Vector3.UP if absf((b-a).normalized().y)<0.99 else Vector3.RIGHT)
func label3(text: String, p: Vector3, size: float, colour: Color, parent: Node3D = self) -> Label3D:
	var n := Label3D.new(); n.text = text; n.font_size = 64; n.pixel_size = size/64.0
	n.modulate = colour; n.outline_size = 0; n.position = p; parent.add_child(n); return n
func surface(label: String, vertices: PackedVector3Array, material: Material, uv := PackedVector2Array()) -> MeshInstance3D:
	var normals := PackedVector3Array()
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
		if normal.y < 0.0: normal = -normal
		for j in 3: normals.append(normal)
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX]=vertices; a[Mesh.ARRAY_NORMAL]=normals
	if not uv.is_empty(): a[Mesh.ARRAY_TEX_UV]=uv
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var n := MeshInstance3D.new(); n.name=label; n.mesh=mesh; n.material_override=material
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(n); return n
func ring(label: String, inner: float, outer: float, material: Material, start := 0.0, length := -1.0, lift := 0.0, flat := false) -> void:
	if length < 0.0: length = venue.lap_length_m
	var verts := PackedVector3Array(); var uv := PackedVector2Array()
	var count := maxi(2,ceili(length*5.0))
	for i in count:
		var s0: float = start + length*float(i)/count
		var s1: float = start + length*float(i+1)/count
		var a: Vector3=track.at(s0,inner); var b: Vector3=track.at(s0,outer)
		var c: Vector3=track.at(s1,inner); var d: Vector3=track.at(s1,outer)
		if flat: a.y=0.0; b.y=0.0; c.y=0.0; d.y=0.0
		for p in [a,c,b,c,d,b]: verts.append(p+Vector3.UP*lift)
		for p in [Vector2(s0/12.5,0),Vector2(s1/12.5,0),Vector2(s0/12.5,(outer-inner)/2.24),Vector2(s1/12.5,0),Vector2(s1/12.5,(outer-inner)/2.24),Vector2(s0/12.5,(outer-inner)/2.24)]: uv.append(p)
	surface(label,verts,material,uv)
func instances(label: String, size3: Vector3, poses: Array[Transform3D], colors: Array[Color]) -> void:
	var mesh := BoxMesh.new(); mesh.size=size3
	var mm := MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_colors=true; mm.mesh=mesh; mm.instance_count=poses.size()
	for i in poses.size(): mm.set_instance_transform(i,poses[i]); mm.set_instance_color(i,colors[i])
	var n := MultiMeshInstance3D.new(); n.name=label; n.multimesh=mm
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo=true; m.roughness=0.85
	n.material_override=m; n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(n)
