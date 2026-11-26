extends "res://venues/gent/gent_build.gd"
const Crowd := preload("res://crowd_kit.gd")
var crowd: RefCounted
var seat_count := 0
var spectator_count := 0
var infield: Node3D
var suite: Node3D
var official: Node3D
var simple := false
var density := 0.72
var lights: Array[OmniLight3D] = []
func build(host: Node3D, profile: Resource, route: RefCounted) -> void:
	venue=profile; track=route; name="GentArena"
	crowd=Crowd.new()
	_track()
	_hall()
	_stands()
	infield=preload("res://venues/gent/gent_infield.gd").new()
	infield.name="GentInfield"; add_child(infield); infield.build(host,venue,track,crowd,simple,density)
	official=infield.official
	_broadcast()
	_scoreboard()
	set_meta("venue_id","gent")
	set_meta("seat_count",seat_count)
	set_meta("spectator_count",spectator_count+infield.spectator_count)
func _track() -> void:
	var wood: StandardMaterial3D=mat("e2ded2",0.85).duplicate()
	var image:Image=preload("res://assets/textures/velodrome_wood_pine.png").get_image()
	if image.is_compressed():image.decompress()
	image.generate_mipmaps()
	wood.albedo_texture=ImageTexture.create_from_image(image)
	wood.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ring("GentWood",venue.apron_width_m,venue.track_outer_offset_m,wood)
	ring("GentBlueApron",0,venue.apron_width_m,mat("3f88bc"))
	for mark in [[venue.apron_width_m+0.20,"22252a"],[venue.apron_width_m+0.85,"c52f35"],[venue.apron_width_m+2.45,"38759f"]]:
		ring("TrackLine",mark[0],mark[0]+0.05,mat(mark[1]),0,-1,0.014)
	ring("GentFinishWhite",0,venue.track_outer_offset_m,mat("f2ede2"),-0.36,0.72,0.02)
	ring("GentFinishBlack",0,venue.track_outer_offset_m,mat("14191d"),-0.02,0.04,0.028)
	# Own panel rhythm, without any photographed sponsor textures or logos.
	for i in 20:
		var s: float=(float(i)+0.25)*venue.lap_length_m/20.0
		var colors: Array[String]=["e7ce6f","dbe5dd","dee8ef","254568","e4d3b8"]
		if i%4==1:branding_track(s,5.1)
		else:ring("OriginalTrackPanel",4.7,7.4,mat(colors[i%colors.size()]),s,5.1,0.016)
	var verts:=PackedVector3Array()
	for i in 700:
		var a: Vector3=track.at(venue.lap_length_m*float(i)/700.0,7.8)
		var b: Vector3=track.at(venue.lap_length_m*float(i+1)/700.0,7.8)
		verts.append_array(PackedVector3Array([a,b,a+Vector3.UP*0.90,b,b+Vector3.UP*0.90,a+Vector3.UP*0.90]))
	surface("GentRedOuterBoarding",verts,mat("d82632"))
	branding_ring("GentWhiteLogoRedOuterBoarding",7.76,.10,.68,28)
func _hall() -> void:
	box("GentFloor",Vector3(0,-0.24,0),Vector3(68,0.28,86),mat("343638"))
	# A rectangular low ceiling, not the radial crown of Vélodrome.
	box("GentFlatCeiling",Vector3(0,16.2,0),Vector3(68,0.25,86),mat("b7b1a6"))
	for x in [-33.7,33.7]: box("GentSideWall",Vector3(x,8,0),Vector3(.28,16,86),mat("a69d8d"))
	for z in [-42.7,42.7]: box("GentEndWall",Vector3(0,8,z),Vector3(68,16,.28),mat("aaa18f"))
	var metal:=mat("48525b")
	for z in range(-40,41,8):
		box("CeilingBeam",Vector3(0,15.85,z),Vector3(67,.27,.19),metal)
		for x in [-31.8,31.8]: box("BlueHallColumn",Vector3(x,8,z),Vector3(.48,16,.50),mat("243b55"))
	for x in range(-30,31,6): box("CeilingPanelJoint",Vector3(x,16.04,0),Vector3(.05,.025,85),mat("86857f"))
	for z in range(-36,37,12):
		for x in [-18.0,0.0,18.0]: box("CeilingFixture",Vector3(x,15.65,z),Vector3(2.8,.06,.65),mat("fff0d5",0.9,1.2))
	for i in 8:
		var s: float=venue.lap_length_m*(float(i)+.5)/8
		var l:=OmniLight3D.new(); l.name="GentTrackLight"; l.position=track.at(s,3.0)+Vector3.UP*8.0
		l.light_color=Color("fff3dd");l.light_energy=venue.track_light_energy;l.omni_range=venue.track_light_range_m
		l.omni_attenuation=0.8;l.light_specular=0.12;l.shadow_enabled=false;add_child(l);lights.append(l)
	# Fresh graphics, no copies of the existing wall paintings.
	for side in [-1.0,1.0]:
		for i in 10:
			var panel:=Node3D.new();panel.name="OriginalGentWallArt";panel.position=Vector3(side*33.4,10.8,-36.0+i*8.0);add_child(panel)
			panel.rotation.y=-side*PI/2
			box("GraphicPanel",Vector3.ZERO,Vector3(7.2,6.2,.06),mat("243b55" if i%2==0 else "d8d1c4"),panel)
			for k in 3:
				var stripe:=box("SpeedStripe",Vector3(-1.0+k*1.2,-1.8+k*.5,.06),Vector3(5.2,.18,.02),mat("d82632" if i%2==0 else "3f88bc"),panel)
				stripe.rotation.z=.43
			label3("GENT" if i in [4,5] else ("166⅔" if i%2==0 else "ZES DAGEN"),Vector3(0,.9,.10),1.35 if i in [4,5] else .7,Color("f2ede2") if i%2==0 else Color("243b55"),panel)
func _stand_point(s: float, row: int) -> Vector3:
	var p: Vector3=track.at(s,8.5+row*0.86)
	p.y=track.at(s,7.8).y+0.30+row*0.45
	return p
func _stands() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=1662026
	var seats:Array[Transform3D]=[];var backs:Array[Transform3D]=[];var colors:Array[Color]=[];var people:Dictionary={}
	var steps:=360
	for row in 15:
		var verts:=PackedVector3Array()
		for i in steps:
			var s0: float=venue.lap_length_m*float(i)/steps
			var s1: float=venue.lap_length_m*float(i+1)/steps
			var a:=_stand_point(s0,row);var b:=_stand_point(s1,row)
			var c:Vector3=a+track.outward(s0)*.86;var d:Vector3=b+track.outward(s1)*.86
			if maxf(absf(c.z),absf(d.z))>41.5 or maxf(absf(c.x),absf(d.x))>32.8:continue
			verts.append_array(PackedVector3Array([a,b,c,b,d,c]))
			verts.append_array(PackedVector3Array([a-Vector3.UP*.45,b-Vector3.UP*.45,a,b-Vector3.UP*.45,b,a]))
		if not verts.is_empty():surface("GentTerraceRow",verts,mat("8d8880"))
		var s:=0.0
		while s<venue.lap_length_m:
			var p:Vector3=_stand_point(s,row)+track.outward(s)*.42
			# Long straight aisles and radial openings remain clear.
			var aisle: bool=fposmod(s+2.0,venue.lap_length_m/12.0)<1.35
			var cabin: bool=minf(s,venue.lap_length_m-s)<4.5 and row>=8
			if absf(p.x)<32.4 and absf(p.z)<41.1 and not aisle and not cabin:
				var outward: Vector3=track.outward(s);var tangent:=Vector3.UP.cross(outward)
				var basis:=Basis(tangent,Vector3.UP,outward)
				seats.append(Transform3D(basis,p+Vector3.UP*.38));backs.append(Transform3D(basis,p+outward*.26+Vector3.UP*.64))
				colors.append(Color("d4a63d").lerp(Color("b57d21"),rng.randf()*.18));seat_count+=1
				if rng.randf()<density:
					var variant: String=Crowd.SEATED[crowd.pick_weighted(rng,Crowd.SEATED_WEIGHTS)]
					var facing:=Basis(-basis.x,Vector3.UP,-basis.z)
					var block:=int(s/(venue.lap_length_m/12))
					if not people.has(block):people[block]={}
					Crowd.add_to_group(people[block],variant,Transform3D(facing,p),crowd.random_look(rng));spectator_count+=1
			var speed: float=(track.at(s+.1,8.5+row*.86)-track.at(s-.1,8.5+row*.86)).length()/.2
			s+=.78/maxf(1.0,speed)
	instances("GentYellowSeats",Vector3(.58,.10,.50),seats,colors)
	instances("GentYellowBacks",Vector3(.58,.50,.09),backs,colors)
	for block in people:
		crowd.emit_group(self,people[block],"GentSeatedPublic%d"%block,[[1,0.0,0.0]] if simple else [[0,0.0,24.0],[1,24.0,0.0]])
func _broadcast() -> void:
	var s:=0.0;var out: Vector3=track.outward(s)
	var p: Vector3=track.at(s,18.3);p.y=8.8
	# Full-size reused suite on its own raised platform near the finish.
	box("BroadcastPlatform",p-Vector3.UP*.18,Vector3(4.8,.32,7.6),mat("4d555e"))
	suite=preload("res://commentary_box_controller.gd").new();suite.name="EuroMaxCyclingCommentaryBox"
	suite.transform=Transform3D(Basis(Vector3.UP.cross(-out),Vector3.UP,-out),p);add_child(suite)
	var model: Node3D=(load(venue.shared_actors.broadcast_suite) as PackedScene).instantiate();suite.add_child(model);suite.setup(model)
	for x in [-1.2,1.2]:
		var l:=OmniLight3D.new();l.position=Vector3(x,2.45,.25);l.light_color=Color("ffe5c5");l.light_energy=1.2;l.omni_range=3.15;l.shadow_enabled=false;suite.add_child(l)
	for dz in [-3.0,3.0]:
		for dx in [-1.5,1.5]:
			beam("BroadcastSupport",p+Vector3(dx,-3.4,dz),p+Vector3(dx,-.22,dz),.12,mat("48525b"))
	suite.set_speaking(0,true);suite.set_speaking(1,true)
func _scoreboard() -> void:
	var board:=Node3D.new();board.name="GentScoreboard";board.position=Vector3(0,11.8,37.7);board.rotation.y=PI;add_child(board)
	box("ScoreboardFrame",Vector3.ZERO,Vector3(8.0,3.2,.3),mat("121b29"),board)
	label3("GENT",Vector3(0,.7,.18),.65,Color("f2ede2"),board)
	label3("166,67 m    •    6 = 1 km",Vector3(0,-.05,.18),.33,Color("d4a63d"),board)
	label3("01     24       02     18       03     12",Vector3(0,-.8,.18),.3,Color("f2ede2"),board)
	for x in [-3.4,3.4]:beam("ScoreboardSuspension",board.position+Vector3(x,1.6,0),Vector3(x,16,37.7),.055,mat("555d65"))
