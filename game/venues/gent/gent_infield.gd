extends "res://venues/gent/gent_build.gd"
const Crowd := preload("res://crowd_kit.gd")
var official: Node3D
var spectator_count := 0
var cabins: Array[Node3D] = []
var crowd: RefCounted
var rng:=RandomNumberGenerator.new()
func build(host: Node3D, profile: Resource, route: RefCounted, kit: RefCounted, simple: bool, density: float) -> void:
	venue=profile;track=route;crowd=kit;rng.seed=20261121
	_floor()
	_cabins()
	_technical_zone()
	_bar()
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
		beam("CrewRail",Vector3(2.2,1.0,z),Vector3(2.2,1.0,z+1.8),.04,mat("8d9693"))
		beam("CrewRailPost",Vector3(2.2,0,z),Vector3(2.2,1.0,z),.04,mat("8d9693"))
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
	var bar:=Node3D.new();bar.name="GentInfieldBar";bar.position=Vector3(-3.8,0,-2);add_child(bar)
	box("PlainBarCounter",Vector3(0,.53,0),Vector3(3.1,1.06,9),mat("4e514b"),bar)
	box("BarTop",Vector3(0,1.10,0),Vector3(3.4,.12,9.2),mat("b8ad91"),bar)
	for z in [-3.,0.,3.]:
		box("BarStation",Vector3(0,1.34,z),Vector3(.9,.3,.65),mat("929d9e"),bar)
	for i in 15:
		box("Cup",Vector3(1.23,1.28,-3.8+i*.5),Vector3(.10,.22,.10),mat("d9c9a4"),bar)
func _public(simple: bool, density: float) -> void:
	var people:Dictionary={}
	var count:=roundi((260 if simple else 680)*density)
	var tries:=0
	while spectator_count<count and tries<10000:
		tries+=1
		var p:=Vector3(rng.randf_range(-9,1.0),0,rng.randf_range(-25.5,26))
		# Own zones: central public half, technical aisle and access kept free.
		if absf(p.x+3.8)<2.0 and absf(p.z+2)<5.2:continue
		if p.z>11.5 and p.x>0:continue
		if absf(p.z-5.0)<1.25:continue
		if Vector2(p.x,p.z).length()>29:continue
		var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI))
		Crowd.add_to_group(people,Crowd.STANDING[rng.randi()%Crowd.STANDING.size()],Transform3D(basis,p),crowd.random_look(rng));spectator_count+=1
	crowd.emit_group(self,people,"GentOwnInfieldPublic",[[1,0.0,0.0]] if simple else [[0,0.0,0.0]])
