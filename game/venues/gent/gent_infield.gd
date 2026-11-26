extends "res://venues/gent/gent_build.gd"
const Crowd := preload("res://crowd_kit.gd")
var official: Node3D
var spectator_count := 0
var cabins: Array[Node3D] = []
var crowd: RefCounted
var rng:=RandomNumberGenerator.new()
var public_positions:Array[Vector3]=[]
var public_boundary:=PackedVector2Array()
var bar_footprints:Array[Rect2]=[]
var table_positions:Array[Vector2]=[]
const CABIN_FOOTPRINT:=Rect2(5.15,-24.6,3.3,33.1)
const TECHNICAL_FOOTPRINT:=Rect2(0.0,8.6,5.25,12.8)
const CREW_PASSAGE:=Rect2(3.9,-25.0,1.25,33.8)
const CROSS_PASSAGE_Z:=5.0
const CROSS_PASSAGE_HALF_WIDTH:=0.55
func build(host: Node3D, profile: Resource, route: RefCounted, kit: RefCounted, simple: bool, density: float) -> void:
	venue=profile;track=route;crowd=kit;rng.seed=20261121
	_floor()
	_cabins()
	_technical_zone()
	_bar()
	_hospitality_tables()
	_technical_staff()
	_public(simple,density)
	official=preload("res://venues/race_official.gd").new();official.name="GentRaceOfficial"
	official.game=host;official.official_lap_m=venue.lap_length_m;add_child(official);official._build_flag_official()
	box("JuryDesk",Vector3(9.0,.5,-10),Vector3(1.2,1,3),mat("343b43"))
	box("JuryDeskTop",Vector3(9.0,1.03,-10),Vector3(1.5,.08,3.2),mat("d8d1c4"))
func _floor() -> void:
	var v:=PackedVector3Array()
	for i in 600:
		var a: Vector3=track.at(venue.lap_length_m*float(i)/600,0)
		var b: Vector3=track.at(venue.lap_length_m*float(i+1)/600,0)
		a.y=-.01;b.y=-.01;v.append_array(PackedVector3Array([Vector3(0,-.01,0),a,b]))
	surface("GentOwnInfieldFloor",v,mat("393a38"))
	ring("GentRedInnerWalkway",-2.25,-.05,mat("d82632"),0,-1,.015,true)
	# Infield rail in its own layout, with a controlled opening at the straight.
	for i in 220:
		var s: float=venue.lap_length_m*float(i)/220
		if absf(s-37.0)<3:continue
		var p: Vector3=track.at(s,-2.4);p.y=0
		var q: Vector3=track.at(s+venue.lap_length_m/220,-2.4);q.y=0
		beam("GentInfieldHandrail",p+Vector3.UP*1.08,q+Vector3.UP*1.08,.055,mat("b7b0a1"))
		if i%3==0:beam("GentRailPost",p,p+Vector3.UP*1.08,.055,mat("6c7477"))
func _cabins() -> void:
	var people: Dictionary={}
	for i in 12:
		var cabin:=Node3D.new();cabin.name="GentRiderCabin%02d"%(i+1)
		# Own finish-side row. Vélodrome's nine national houses sit on -X.
		cabin.position=Vector3(7.05,0,-23.1+float(i)*2.75);cabin.rotation.y=-PI/2;add_child(cabin);cabins.append(cabin)
		cabin.set_meta("pair_number",i+1)
		var grey:=mat("a4aaa8");var dark:=mat("323738");var curtain:=mat("757c73")
		box("LowCabinBack",Vector3(0,.93,-.92),Vector3(2.64,1.86,.08),grey,cabin)
		for side in [-1.0,1.0]:
			box("PlainDivider",Vector3(side*1.30,.97,0),Vector3(.06,1.94,1.90),grey,cabin)
			beam("CurtainSupport",Vector3(side*1.30,0,.92),Vector3(side*1.30,2.22,.92),.035,dark,cabin)
		beam("CurtainRod",Vector3(-1.32,2.22,.92),Vector3(1.32,2.22,.92),.035,dark,cabin)
		# Pleated curtains are gathered to the side, leaving the bench visible.
		for k in 8:
			box("CurtainPleat",Vector3(-1.17+k*.05,1.15,.92+sin(k*1.7)*.035),Vector3(.065,2.03,.035),curtain,cabin)
		box("RestBench",Vector3(0,.50,-.32),Vector3(2.42,.13,.78),mat("827965"),cabin)
		box("BenchBase",Vector3(0,.24,-.46),Vector3(2.32,.46,.51),grey,cabin)
		box("BottleShelf",Vector3(0,1.27,-.76),Vector3(2.33,.055,.26),dark,cabin)
		box("NumberPlate",Vector3(.85,1.97,1.0),Vector3(.48,.42,.035),mat("e0e1d8"),cabin)
		label3("%02d"%(i+1),Vector3(.85,1.98,1.026),.23,Color("243b55"),cabin)
		for k in 3:
			box("Bottle",Vector3(-.7+k*.42,1.4,-.74),Vector3(.09,.24,.09),mat("d2c7a4" if k==0 else "647c84"),cabin)
		if i%2==0:
			preload("res://venues/gent/parked_bike.gd").build(cabin,Vector3(-.45,0,1.8),0.0)
		var towel:=box("Towel",Vector3(.40,.60,-.23),Vector3(.54,.035,.60),mat("c7b9a2"),cabin);towel.rotation.y=.18
		# Folding chair in front of each cabin, no national flags or team house.
		box("LooseChairSeat",Vector3(.63,.45,1.38),Vector3(.43,.065,.43),mat("68736f"),cabin)
		box("LooseChairBack",Vector3(.63,.77,1.58),Vector3(.43,.43,.055),mat("68736f"),cabin)
		for x in [.46,.80]:beam("ChairLeg",Vector3(x,.05,1.18),Vector3(x,.74,1.62),.026,dark,cabin)
		if i%3!=2:
			for k in 2:
				var pos: Vector3=cabin.to_global(Vector3(-.55+k*.85,0,-.36))
				var basis:=Basis(Vector3.UP,-PI/2)
				Crowd.add_to_group(people,Crowd.SEATED[(i+k)%Crowd.SEATED.size()],Transform3D(basis,pos),crowd.staff_look(rng,Color("335986" if i%2==0 else "c8ac41"),.12))
	crowd.emit_group(self,people,"GentCabinRiders",[[0,0.0,0.0]])
	# Controlled crew passage between the public half and the cabins.
	for z in range(-25,12,2):
		if abs(z-5)<3:continue
		beam("CrewRail",Vector3(3.9,1.0,z),Vector3(3.9,1.0,z+1.8),.04,mat("8d9693"))
		beam("CrewRailPost",Vector3(3.9,0,z),Vector3(3.9,1.0,z),.04,mat("8d9693"))
func _technical_zone() -> void:
	var group:=Node3D.new();group.name="GentTechnicalZone";group.position=Vector3(2.6,0,15.0);add_child(group)
	box("TechnicalFloor",Vector3(0,.01,0),Vector3(4.6,.035,12.0),mat("282d2c"),group)
	for side in [-1.0,1.0]:
		for z in [-5.7,0.0,5.7]:
			beam("TechnicalPost",Vector3(side*2.2,0,z),Vector3(side*2.2,2.9,z),.07,mat("9ba4a3"),group)
		beam("TechnicalTop",Vector3(side*2.2,2.9,-5.7),Vector3(side*2.2,2.9,5.7),.09,mat("9ba4a3"),group)
	for z in [-5.7,0.0,5.7]:beam("TechnicalCrossMember",Vector3(-2.2,2.9,z),Vector3(2.2,2.9,z),.09,mat("9ba4a3"),group)
	for i in 4:
		box("WorkBench",Vector3(-1.7,.85,-4.6+i*2.7),Vector3(.75,.1,1.8),mat("b9b8af"),group)
		for z in [-4.7+i*2.7]:
			box("RollerBase",Vector3(.55,.08,z),Vector3(.8,.08,1.45),mat("43809b"),group)
			for dz in [-.5,.4]:box("Roller",Vector3(.55,.15,z+dz),Vector3(.74,.14,.14),mat("b8bdb9"),group)
	for i in 3:
		preload("res://venues/gent/parked_bike.gd").build(group,Vector3(.55,.18,-4.7+i*2.7),0.0)
	var t:=label3("RENNERS",Vector3(0,2.65,-5.78),.4,Color("f2ede2"),group);t.rotation.y=PI
func _bar() -> void:
	# Long, staffed counter islands occupy the middle rather than a tiny bar
	# surrounded by unused floor. The transverse crossing remains open.
	_bar_island("GentInfieldBar",Vector3(-3.7,0,-7.4),19.0)
	_bar_island("GentNorthBar",Vector3(-3.7,0,11.5),10.6)

func _bar_island(label:String,position:Vector3,length:float)->void:
	var bar:=Node3D.new();bar.name=label;bar.position=position;add_child(bar)
	bar_footprints.append(Rect2(position.x-1.95,position.z-length*.5-.25,3.9,length+.5))
	box("BarWorkFloor",Vector3(0,.015,0),Vector3(3.5,.03,length),mat("282d2c"),bar)
	for side in [-1.0,1.0]:
		box("BarCounter",Vector3(side*1.4,.51,0),Vector3(.60,1.02,length),mat("4e514b"),bar)
		box("BarRedFascia",Vector3(side*1.715,.52,0),Vector3(.035,.82,length-.08),mat("a72d35"),bar)
		box("BarTop",Vector3(side*1.4,1.08,0),Vector3(.78,.12,length+.16),mat("b8ad91"),bar)
	for end in [-1.0,1.0]:
		box("BarEndCounter",Vector3(0,.51,end*(length*.5-.27)),Vector3(2.5,1.02,.54),mat("4e514b"),bar)
		box("BarEndTop",Vector3(0,1.08,end*(length*.5-.27)),Vector3(2.82,.12,.72),mat("b8ad91"),bar)
	var people:Dictionary={}
	for i in floori(length/2.6):
		var z:float=-length*.5+1.3+float(i)*2.6
		for side in [-1.0,1.0]:
			box("TapBase",Vector3(side*1.4,1.19,z),Vector3(.35,.13,.48),mat("9aa6a5"),bar)
			beam("TapStem",Vector3(side*1.4,1.22,z),Vector3(side*1.4,1.60,z),.045,mat("b8bdb9"),bar)
			beam("TapSpout",Vector3(side*1.4,1.58,z),Vector3(side*1.23,1.58,z),.04,mat("b8bdb9"),bar)
			for k in 3:box("Cup",Vector3(side*1.45,1.25,z+.5+k*.16),Vector3(.095,.22,.095),mat("d9c9a4"),bar)
		box("BarStation",Vector3(0,.72,z),Vector3(1.65,.85,.85),mat("929d9e"),bar)
		var p:=position+Vector3(0,0,z+.85)
		var basis:=Basis(Vector3.UP,PI*.5 if i%2==0 else -PI*.5)
		Crowd.add_to_group(people,"stand_f_relaxed" if i%2==0 else "stand_m_relaxed",Transform3D(basis,p),crowd.staff_look(rng,Color("845798"),.1))
	crowd.emit_group(self,people,label+"Staff",[[0,0.0,0.0]])

func _hospitality_tables()->void:
	# Both curved ends and the former empty finish-side corner are used.
	for p in [Vector2(-4,-26.3),Vector2(1,-29.2),Vector2(5.0,-27),Vector2(-7.9,20),Vector2(-5.0,26.1),Vector2(.0,27.8),Vector2(5.2,25.5),Vector2(8.2,17),Vector2(8.1,11.5),Vector2(-8.5,-18)]:
		table_positions.append(p)
		var table:=Node3D.new();table.name="GentStandingTable";table.position=Vector3(p.x,0,p.y);add_child(table)
		var top:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.44;mesh.bottom_radius=.44;mesh.height=.07;mesh.radial_segments=16
		top.mesh=mesh;top.position.y=1.12;top.material_override=mat("b8ad91");top.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;table.add_child(top)
		beam("TableStem",Vector3(0,.04,0),Vector3(0,1.1,0),.075,mat("68736f"),table)
		box("TableFoot",Vector3(0,.04,0),Vector3(.58,.07,.58),mat("68736f"),table)
		for k in 3:box("TableCup",Vector3(-.18+k*.17,1.26,.08),Vector3(.09,.20,.09),mat("d9c9a4"),table)

func _technical_staff()->void:
	var people:Dictionary={}
	for i in 8:
		var p:=Vector3(.75+float(i%2)*2.7,0,10.5+float(i/2)*2.65)
		Crowd.add_to_group(people,"stand_m_relaxed" if i%2==0 else "stand_f_relaxed",Transform3D(Basis(Vector3.UP,PI*.5),p),crowd.staff_look(rng,Color("436173"),.12))
	crowd.emit_group(self,people,"GentTechnicalStaff",[[0,0.0,0.0]])

func _public_floor_free(p:Vector2)->bool:
	if not Geometry2D.is_point_in_polygon(p,public_boundary):return false
	if CABIN_FOOTPRINT.has_point(p) or TECHNICAL_FOOTPRINT.has_point(p) or CREW_PASSAGE.has_point(p):return false
	if absf(p.y-CROSS_PASSAGE_Z)<CROSS_PASSAGE_HALF_WIDTH:return false
	# Keep the official's jury desk and the equipment passage accessible.
	if Rect2(8.05,-12.1,2.0,4.2).has_point(p):return false
	for bounds in bar_footprints:
		if bounds.has_point(p):return false
	for centre in table_positions:
		if centre.distance_to(p)<.68:return false
	return true

func _public(simple: bool, density: float) -> void:
	for i in 240:
		var p:Vector3=track.at(venue.lap_length_m*float(i)/240.0,-2.95)
		public_boundary.append(Vector2(p.x,p.z))
	# Stratified placement fills the actual oval, including both ends and +X.
	# Spacing prevents overlapping bodies; a grid of sectors keeps LOD local.
	var groups:Dictionary={}
	var spacing:=1.04 if simple else .69
	var row:=0
	var z:float=-34.0
	while z<=34.0:
		var x:float=-13.0+float(row%2)*spacing*.5
		while x<=13.0:
			var p:=Vector2(x+rng.randf_range(-.065,.065),z+rng.randf_range(-.065,.065))
			if _public_floor_free(p) and rng.randf()<clampf(density,0.0,1.0):
				var pos:=Vector3(p.x,0,p.y)
				var key:=Vector2i(floori(p.x/8.0),floori(p.y/8.0))
				if not groups.has(key):groups[key]={}
				var yaw:=rng.randf_range(-PI,PI)
				# People near a table/counter tend to face their group.
				for centre in table_positions:
					if centre.distance_to(p)<1.65:yaw=atan2(centre.x-p.x,centre.y-p.y)
				Crowd.add_to_group(groups[key],Crowd.STANDING[rng.randi()%Crowd.STANDING.size()],Transform3D(Basis(Vector3.UP,yaw),pos),crowd.random_look(rng))
				public_positions.append(pos);spectator_count+=1
			x+=spacing
		z+=spacing*.88;row+=1
	for key in groups:
		crowd.emit_group(self,groups[key],"GentOwnInfieldPublic%d_%d"%[key.x,key.y],[[1,0.0,0.0]] if simple else [[0,0.0,22.0],[1,22.0,0.0]])
