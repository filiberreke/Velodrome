extends "res://venues/gent/gent_build.gd"
const Crowd := preload("res://crowd_kit.gd")
var official: Node3D
var spectator_count := 0
var cabins: Array[Node3D] = []
var crowd: RefCounted
var rng:=RandomNumberGenerator.new()
var public_positions:Array[Vector3]=[]
var public_boundary:=PackedVector2Array()
var table_positions:Array[Vector2]=[]
# The photo is viewed from -Z: finish (+X) is LEFT, team services (-X)
# are RIGHT. The near bend is -Z. All other usable floor is public.
const TECHNICAL_FOOTPRINT:=Rect2(-10.0,-21.0,5.5,40.5)
const JURY_FOOTPRINT:=Rect2(6.65,-13.2,3.5,8.3)
const MEDICAL_FOOTPRINT:=Rect2(-2.4,-32.4,4.8,5.5)
const PRESS_LEFT_FOOTPRINT:=Rect2(2.45,-27.2,5.4,5.6)
const PRESS_RIGHT_FOOTPRINT:=Rect2(-7.85,-27.2,5.4,5.6)
const MIXED_FOOTPRINT:=Rect2(-2.45,-26.9,4.9,5.3)
var restricted_footprints:Array[Rect2]=[TECHNICAL_FOOTPRINT,JURY_FOOTPRINT,MEDICAL_FOOTPRINT,PRESS_LEFT_FOOTPRINT,PRESS_RIGHT_FOOTPRINT,MIXED_FOOTPRINT]
var jury_zone:Node3D
var medical_zone:Node3D
var mixed_zone:Node3D
var press_zones:Array[Node3D]=[]
var lap_display:Node3D
var interview_backdrop:Node3D
func build(host: Node3D, profile: Resource, route: RefCounted, kit: RefCounted, simple: bool, density: float) -> void:
	venue=profile;track=route;crowd=kit;rng.seed=20261121
	_floor()
	_cabins()
	_technical_zone()
	_press_and_medical()
	_jury()
	_hospitality_tables()
	_technical_staff()
	_public(simple,density)
	official=preload("res://venues/race_official.gd").new();official.name="GentRaceOfficial"
	official.game=host;official.official_lap_m=venue.lap_length_m;add_child(official);official._build_flag_official()
func _floor() -> void:
	var v:=PackedVector3Array()
	for i in 600:
		var a: Vector3=track.at(venue.lap_length_m*float(i)/600,0)
		var b: Vector3=track.at(venue.lap_length_m*float(i+1)/600,0)
		a.y=-.01;b.y=-.01;v.append_array(PackedVector3Array([Vector3(0,-.01,0),a,b]))
	surface("GentOwnInfieldFloor",v,mat("393a38"))
	ring("GentOrangeInnerWalkway",-2.25,-.05,mat(venue.palette.orange),0,-1,.015,true)
	# Infield rail in its own layout, with a controlled opening at the straight.
	for i in 220:
		var s: float=venue.lap_length_m*float(i)/220
		if absf(s-37.0)<3:continue
		var p: Vector3=track.at(s,-2.4);p.y=0
		var q: Vector3=track.at(s+venue.lap_length_m/220,-2.4);q.y=0
		beam("GentInfieldHandrail",p+Vector3.UP*1.08,q+Vector3.UP*1.08,.055,mat("b7b0a1"))
		if i%3==0:beam("GentRailPost",p,p+Vector3.UP*1.08,.055,mat("6c7477"))
	branding_floor("GentWhiteLogoInnerWalkway",24)
func _cabins() -> void:
	for i in 12:
		var cabin:=Node3D.new();cabin.name="GentRiderCabin%02d"%(i+1)
		# Open service bays on the straight OPPOSITE the finish, as in the photo.
		cabin.position=Vector3(-8.35,0,-18.0+float(i)*3.15);cabin.rotation.y=PI/2;add_child(cabin);cabins.append(cabin)
		cabin.set_meta("pair_number",i+1)
		var grey:=mat("a4aaa8");var dark:=mat("323738");var curtain:=mat("757c73")
		box("LowCabinBack",Vector3(0,.40,-.92),Vector3(3.04,.80,.08),grey,cabin)
		for side in [-1.0,1.0]:
			box("PlainDivider",Vector3(side*1.49,.48,0),Vector3(.06,.96,1.90),grey,cabin)
		# No seated crowd poses in cells: equipment, a folding cot and a towel
		# make the purpose legible. Spare bikes hang above the trackside rack.
		box("RestBench",Vector3(0,.46,-.28),Vector3(2.65,.13,.78),mat("827965"),cabin)
		for x in [-1.05,1.05]:beam("CotLeg",Vector3(x,.05,-.62),Vector3(x,.43,.08),.04,dark,cabin)
		box("FoldedBlanket",Vector3(.64,.56,-.27),Vector3(.65,.12,.70),curtain,cabin)
		box("BottleShelf",Vector3(0,.85,-.76),Vector3(2.70,.055,.26),dark,cabin)
		box("NumberPlate",Vector3(.93,1.08,.98),Vector3(.46,.32,.035),mat("e0e1d8"),cabin)
		label3("%02d"%(i+1),Vector3(.93,1.09,1.008),.20,Color("243b55"),cabin)
		for k in 3:
			box("Bottle",Vector3(-.7+k*.42,.99,-.74),Vector3(.09,.24,.09),mat("d2c7a4" if k==0 else "647c84"),cabin)
		beam("BikeRackPost",Vector3(1.45,0,-.92),Vector3(1.45,2.45,-.92),.055,dark,cabin)
		beam("BikeRackBeam",Vector3(-1.55,2.40,-.92),Vector3(1.55,2.40,-.92),.065,dark,cabin)
		preload("res://venues/gent/parked_bike.gd").build(cabin,Vector3(0,1.15,-.82),PI/2)
		_chair(cabin,Vector3(.55,0,1.25))
	_fence(Vector3(-4.6,0,-20.8),Vector3(-4.6,0,3.5),self)
	_fence(Vector3(-4.6,0,5.0),Vector3(-4.6,0,19.2),self)
func _technical_zone() -> void:
	var group:=Node3D.new();group.name="GentTechnicalZone";group.position=Vector3(-5.8,0,-1.0);add_child(group)
	box("TechnicalFloor",Vector3(0,.01,0),Vector3(2.2,.035,38.5),mat("282d2c"),group)
	for i in 6:
		var z:float=-16.0+float(i)*6.1
		box("WorkBench",Vector3(.40,.82,z),Vector3(.70,.10,1.6),mat("b9b8af"),group)
		box("ToolCase",Vector3(.40,1.0,z-.35),Vector3(.5,.25,.38),mat("28343b"),group)
		box("RollerBase",Vector3(-.35,.08,z+1.8),Vector3(.8,.08,1.45),mat("43809b"),group)
		for dz in [-.5,.4]:box("Roller",Vector3(-.35,.15,z+1.8+dz),Vector3(.74,.14,.14),mat("b8bdb9"),group)
		preload("res://venues/gent/parked_bike.gd").build(group,Vector3(-.35,.18,z+1.8),0.0)

func _fence(a:Vector3,b:Vector3,parent:Node3D)->void:
	var metal:=mat("8e9695")
	beam("BarrierTop",a+Vector3.UP*1.02,b+Vector3.UP*1.02,.04,metal,parent)
	beam("BarrierBottom",a+Vector3.UP*.20,b+Vector3.UP*.20,.035,metal,parent)
	var n:=maxi(1,ceili(a.distance_to(b)/.28))
	for i in n+1:
		var p:=a.lerp(b,float(i)/float(n))
		beam("BarrierUpright",p+Vector3.UP*.20,p+Vector3.UP*1.02,.024,metal,parent)
		if i%7==0:box("BarrierFoot",p+Vector3.UP*.055,Vector3(.48,.08,.48),metal,parent)

func _chair(parent:Node3D,p:Vector3)->void:
	var dark:=mat("505c61")
	box("ChairSeat",p+Vector3(0,.45,0),Vector3(.43,.065,.43),dark,parent)
	box("ChairBack",p+Vector3(0,.76,-.19),Vector3(.43,.43,.055),dark,parent)
	for x in [-.17,.17]:
		for z in [-.17,.17]:beam("ChairLeg",p+Vector3(x,.04,z),p+Vector3(x,.44,z),.025,dark,parent)

func _work_table(parent:Node3D,p:Vector3,width:float)->void:
	box("WorkTableTop",p+Vector3(0,.80,0),Vector3(width,.09,.72),mat("d6d5cd"),parent)
	box("BlackTableSkirt",p+Vector3(0,.43,0),Vector3(width,.70,.68),mat("24292e"),parent)

func _laptop(parent:Node3D,p:Vector3)->void:
	box("LaptopKeyboard",p,Vector3(.38,.025,.27),mat("313a42"),parent)
	box("LaptopLid",p+Vector3(0,.14,.12),Vector3(.38,.28,.025),mat("1a222a"),parent)
	box("LaptopScreen",p+Vector3(0,.14,.103),Vector3(.33,.23,.008),mat("809eae",.8,.20),parent)

func _press_and_medical()->void:
	# Two open press work areas flank a mixed-zone passage in the near bend.
	for side in [-1.0,1.0]:
		var press:=Node3D.new();press.name="GentPressLeft" if side>0 else "GentPressRight"
		press.position=Vector3(side*5.1,0,-24.4);add_child(press);press_zones.append(press)
		box("PressFloor",Vector3(0,.012,0),Vector3(5.2,.025,5.1),mat("292c2d"),press)
		box("PressLowScreen",Vector3(0,.47,-2.45),Vector3(5.2,.94,.06),mat("222b30"),press)
		_fence(Vector3(-2.5,0,2.7),Vector3(2.5,0,2.7),press)
		var people:Dictionary={}
		for z in [-1.3,1.1]:
			_work_table(press,Vector3(0,0,z),4.7)
			for k in 4:
				var x:float=-1.75+float(k)*1.16
				_laptop(press,Vector3(x,.86,z))
				box("PressNotes",Vector3(x+.33,.86,z-.14),Vector3(.21,.018,.25),mat("eee9dc"),press)
				_chair(press,Vector3(x,0,z-.72))
				var global_p:=press.position+Vector3(x,0,z-.72)
				Crowd.add_to_group(people,"seat_m_relaxed" if k%2==0 else "seat_f_phone",Transform3D(Basis.IDENTITY,global_p),crowd.staff_look(rng,Color("4c6575"),.15))
		var sign:=label3(tr("GENT_ZONE_PRESS"),Vector3(0,.62,-2.49),.27,Color("e8e8df"),press);sign.rotation.y=PI
		crowd.emit_group(self,people,press.name+"Reporters",[[0,0.0,0.0]])

	medical_zone=Node3D.new();medical_zone.name="GentMedicalZone";medical_zone.position=Vector3(0,0,-29.55);add_child(medical_zone)
	box("MedicalFloor",Vector3(0,.015,0),Vector3(4.6,.03,5.0),mat("343d3b"),medical_zone)
	box("MedicalFrontPanel",Vector3(0,.58,-2.38),Vector3(4.5,1.16,.08),mat("e0e3da"),medical_zone)
	box("MedicalCrossVertical",Vector3(0,.65,-2.43),Vector3(.18,.65,.02),mat("32855c"),medical_zone)
	box("MedicalCrossHorizontal",Vector3(0,.65,-2.44),Vector3(.65,.18,.02),mat("32855c"),medical_zone)
	var medsign:=label3(tr("GENT_ZONE_MEDICAL"),Vector3(1.25,.62,-2.43),.19,Color("244e40"),medical_zone);medsign.rotation.y=PI
	box("FirstAidCot",Vector3(-1.03,.63,0),Vector3(.95,.17,2.05),mat("408c8d"),medical_zone)
	box("CotPillow",Vector3(-1.03,.75,.63),Vector3(.67,.15,.45),mat("e5e5d9"),medical_zone)
	for z in [-.7,.7]:beam("MedicalCotLeg",Vector3(-1.03,.05,z),Vector3(-1.03,.58,z),.08,mat("a2acab"),medical_zone)
	_work_table(medical_zone,Vector3(.9,0,-1.15),1.6)
	for x in [.5,1.2]:box("MedicalBag",Vector3(x,1.02,-1.15),Vector3(.48,.38,.38),mat("dbb93b"),medical_zone)
	var medpeople:Dictionary={}
	for p in [Vector3(.7,0,.4),Vector3(1.45,0,1.35),Vector3(-.9,0,1.65)]:
		Crowd.add_to_group(medpeople,"stand_m_relaxed",Transform3D(Basis(Vector3.UP,PI),medical_zone.position+p),crowd.staff_look(rng,Color("dbed36"),.8,.18))
	crowd.emit_group(self,medpeople,"GentMedicalStaff",[[0,0.0,0.0]])
	_fence(Vector3(-2.35,0,-31.4),Vector3(-2.35,0,-27.3),self)
	_fence(Vector3(2.35,0,-31.4),Vector3(2.35,0,-27.3),self)

	mixed_zone=Node3D.new();mixed_zone.name="GentMixedZone";mixed_zone.position=Vector3(0,0,-24.1);add_child(mixed_zone)
	_fence(Vector3(-2.30,0,-2.5),Vector3(-2.30,0,2.4),mixed_zone)
	_fence(Vector3(2.30,0,-2.5),Vector3(2.30,0,2.4),mixed_zone)
	# Explicitly reuse Vélodrome's two-sided white/blue interview backdrop.
	# Its shared builder and original logo textures stay the single source.
	interview_backdrop=Node3D.new();interview_backdrop.name="VelodromeInterviewBackdrop"
	interview_backdrop.position.z=.80;interview_backdrop.rotation.y=PI;mixed_zone.add_child(interview_backdrop)
	preload("res://podium_sponsor_wall.gd").build(interview_backdrop)
	box("BackdropBacking",Vector3(0,1.4,1.69),Vector3(3.6,2.4,.10),mat("243b55"),mixed_zone)
	for x in [-1.3,1.35]:
		var p:=Vector3(x,1.50,-1.25)
		box("PressCamera",p,Vector3(.25,.23,.45),mat("182029"),mixed_zone)
		beam("CameraLens",p+Vector3(0,0,.20),p+Vector3(0,0,.42),.17,mat("364953"),mixed_zone)
		for foot in [Vector3(-.3,0,-.2),Vector3(.3,0,-.2),Vector3(0,0,.3)]:beam("CameraTripod",p-Vector3.UP*.17,Vector3(x,0,-1.25)+foot,.035,mat("59666c"),mixed_zone)
	var interview:Dictionary={}
	for p in [Vector3(-.4,0,.25),Vector3(.55,0,.2),Vector3(1.35,0,-1.9)]:
		Crowd.add_to_group(interview,"stand_f_talk" if p.x<0 else "stand_m_relaxed",Transform3D(Basis(Vector3.UP,PI),mixed_zone.position+p),crowd.staff_look(rng,Color("437496" if p.z>0 else "42494c"),.12))
	crowd.emit_group(self,interview,"GentMixedZoneInterviews",[[0,0.0,0.0]])

func _jury()->void:
	var finish:Vector3=track.at(0.0,0.0)
	jury_zone=Node3D.new();jury_zone.name="GentJuryZone";jury_zone.position=Vector3(finish.x-4.15,0,finish.z);add_child(jury_zone)
	_fence(Vector3(-1.85,0,-4.35),Vector3(-1.85,0,3.9),jury_zone)
	_fence(Vector3(-1.85,0,-4.35),Vector3(1.05,0,-4.35),jury_zone)
	_fence(Vector3(-1.85,0,3.9),Vector3(.25,0,3.9),jury_zone)
	_work_table(jury_zone,Vector3(-.1,0,-1.65),2.3)
	_laptop(jury_zone,Vector3(-.5,.86,-1.65))
	var jurysign:=label3(tr("GENT_ZONE_JURY"),Vector3(-.1,.47,-2.03),.23,Color("e9e9df"),jury_zone);jurysign.rotation.y=PI
	var people:Dictionary={}
	for p in [Vector3(-.75,0,-2.45),Vector3(.7,0,1.7)]:
		_chair(jury_zone,p)
		Crowd.add_to_group(people,"seat_m_relaxed",Transform3D(Basis.IDENTITY,jury_zone.position+p),crowd.staff_look(rng,Color("3c5267"),.12))
	crowd.emit_group(self,people,"GentJuryOfficials",[[0,0.0,0.0]])
	# Cantilever follows the actual finish reference, extending to the inner
	# edge of the track. Two faces are legible to riders and from the photo view.
	beam("LapDisplayMast",Vector3(.75,0,.4),Vector3(.75,3.72,.4),.075,mat("38474e"),jury_zone)
	beam("LapDisplayCantilever",Vector3(.75,3.72,.4),Vector3(3.95,3.72,.4),.085,mat("38474e"),jury_zone)
	beam("LapDisplayHanger",Vector3(3.8,3.72,.4),Vector3(3.8,3.37,.4),.045,mat("38474e"),jury_zone)
	lap_display=Node3D.new();lap_display.name="GentLapsToGo";lap_display.position=Vector3(3.8,3.10,.4);jury_zone.add_child(lap_display)
	box("SmallLapDisplay",Vector3.ZERO,Vector3(1.02,.60,.26),mat("111923"),lap_display)
	for side in [-1.0,1.0]:
		var digit:=label3("6",Vector3(0,0,side*.142),.48,Color("f7e9ce"),lap_display);digit.rotation.y=PI if side<0 else 0.0
	beam("BellPost",Vector3(.70,0,-.6),Vector3(.70,1.65,-.6),.055,mat("67777c"),jury_zone)
	beam("BellBracket",Vector3(.70,1.65,-.6),Vector3(1.08,1.65,-.6),.055,mat("67777c"),jury_zone)
	var bell:=MeshInstance3D.new();bell.name="FinishBell";var mesh:=CylinderMesh.new();mesh.top_radius=.09;mesh.bottom_radius=.20;mesh.height=.25;mesh.radial_segments=20
	bell.mesh=mesh;bell.material_override=mat("bd9b4e",.55);bell.position=Vector3(1.08,1.48,-.6);jury_zone.add_child(bell)
	beam("BellClapper",Vector3(1.08,1.45,-.6),Vector3(1.08,1.29,-.6),.035,mat("514e40"),jury_zone)

func _hospitality_tables()->void:
	for p in [Vector2(-5,24),Vector2(0,28),Vector2(5.2,25.5),Vector2(8.2,17),Vector2(8.1,9)]:
		table_positions.append(p)
		var table:=Node3D.new();table.name="GentStandingTable";table.position=Vector3(p.x,0,p.y);add_child(table)
		var top:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.44;mesh.bottom_radius=.44;mesh.height=.07;mesh.radial_segments=16
		top.mesh=mesh;top.position.y=1.12;top.material_override=mat("b8ad91");top.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;table.add_child(top)
		beam("TableStem",Vector3(0,.04,0),Vector3(0,1.1,0),.075,mat("68736f"),table)
		box("TableFoot",Vector3(0,.04,0),Vector3(.58,.07,.58),mat("68736f"),table)
		for k in 3:box("TableCup",Vector3(-.18+k*.17,1.26,.08),Vector3(.09,.20,.09),mat("d9c9a4"),table)

func _technical_staff()->void:
	var people:Dictionary={}
	for i in 12:
		var p:=Vector3(-6.55+float(i%2)*1.45,0,-18.0+float(i)*3.0)
		Crowd.add_to_group(people,"stand_m_relaxed" if i%2==0 else "stand_f_relaxed",Transform3D(Basis(Vector3.UP,PI*.5),p),crowd.staff_look(rng,Color("436173"),.12))
	crowd.emit_group(self,people,"GentTechnicalStaff",[[0,0.0,0.0]])

func _public_floor_free(p:Vector2)->bool:
	if not Geometry2D.is_point_in_polygon(p,public_boundary):return false
	for bounds in restricted_footprints:
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
