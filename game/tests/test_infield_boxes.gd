extends SceneTree
const Countries = preload("res://rennersboxen/race_countries.gd")

class Screen extends "res://main.gd":
	var fixture := ConfigFile.new()
	func _load_rider_config() -> void:
		rider_config = fixture
		rider_config_ready = true
	func _bind_bridge(_port: int = UDP_PORT) -> Error:return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void:pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:call_deferred("run_test")

func run_test() -> void:
	var game := Screen.new()
	game.fixture.set_value("player","country_kit","belgium")
	for i in range(1,8):
		var country: String = ["france","france","france","netherlands","netherlands","germany","italy"][i-1]
		game.fixture.set_value("rider_%02d" % i,"country_kit",country)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	var row: Node3D = infield.get_node("Rennersboxen")
	check(row.boxes.size()==6,"Six physical cabins replace the old material posts")
	check(row.assigned_countries[0]=="france" and row.assigned_countries[1]=="netherlands","Rank countries by actual start-list frequency")
	check("belgium" in row.assigned_countries,"Player's current country always included")
	for i in range(6):
		var box: Node3D = row.boxes[i]
		check(box.position.is_equal_approx(Vector3(-14.6,0,-25.0+10.0*i)),"Back-straight position "+str(i))
		check((box.basis*Vector3.FORWARD).x>0.99,"Opening +Z points toward the track on world -X")
		check(box.curtain_open==1,"Every mass-race cabin is open")
		check(box.get_meta("bike_source")=="7984692dc0792b839c5b40f2806e849a6ea18107","Reuse the original Velodrome bike meshes")
	check(not infield.has_node("team_tent"),"Old tents removed rather than overlapped")
	# National PNGs override a configured kit, matching PlayerAppearance.
	check(Countries.from_kit({"skinsuit_png":"res://assets/riders/national_kits/italy/skinsuit.png","country_kit":"germany"})=="italy","Read actual selected national texture")
	check(Countries.from_kit({"skinsuit_png":"user://my_france_logo.png"}).is_empty(),"Never infer nationality from arbitrary custom filenames")
	game.player_appearance.suit_id = "new_zealand"
	game.apply_player_appearance()
	await process_frame
	check("new_zealand" in row.assigned_countries,"Live outfit change updates player's cabin without a race reset")
	game.race_mode = 4
	game._configure_peloton()
	await process_frame
	check(row.assigned_countries.has("new_zealand") and row.assigned_countries.has("france"),"Both pursuit countries assigned")
	var opened := 0
	for i in range(6):
		var should_open: bool = row.assigned_countries[i] in ["new_zealand","france"]
		check(is_equal_approx(row.boxes[i].curtain_open,1.0 if should_open else 0.0),"Pursuit closes every non-racing country immediately")
		if should_open:opened+=1
	check(opened==2,"Exactly two countries open in pursuit")
	game.race_mode = 5
	game.team_size = 3
	game.fixture.set_value("rider_03","country_kit","portugal")
	game._configure_peloton()
	await process_frame
	var roster := Countries.roster(game)
	check(roster.start_list==["new_zealand","new_zealand","new_zealand","portugal","portugal","portugal"],"A pursuit team shares one national box")
	for i in range(6):
		var should_open: bool = row.assigned_countries[i] in ["new_zealand","portugal"]
		check(is_equal_approx(row.boxes[i].curtain_open,1.0 if should_open else 0.0),"Only the two competing teams open")
	game.race_mode = 0
	game.rider_count = 8
	game._configure_peloton()
	await process_frame
	for box in row.boxes:check(box.curtain_open==1,"Returning to a mass race reopens all six cabins")
	# Check actual mesh area: original 240-segment capsule minus a rectangular hole.
	var floor_mesh: Mesh = infield.get_node("Middenterrein vloer").mesh
	var vertices: PackedVector3Array = floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var area := 0.0
	for i in range(0,vertices.size(),3):
		var a := Vector2(vertices[i].x,vertices[i].z)
		var b := Vector2(vertices[i+1].x,vertices[i+1].z)
		var c := Vector2(vertices[i+2].x,vertices[i+2].z)
		area += absf((b-a).cross(c-a))*0.5
		if absf((b-a).cross(c-a))>0.000001:
			for point in [Vector2(0,0),Vector2(-2,4),Vector2(2,-4)]:
				check(not Geometry2D.is_point_in_polygon(point,PackedVector2Array([a,b,c])),"Floor mesh does not cover the stairwell")
	var capsule_area := 0.0
	for i in range(240):
		var a: Vector3 = game._at(250.0*float(i)/240.0,0.05)
		var b: Vector3 = game._at(250.0*float(i+1)/240.0,0.05)
		capsule_area+=a.x*b.z-b.x*a.z
	capsule_area = absf(capsule_area)*0.5
	check(absf(area-(capsule_area-4.55*9.4))<0.03,"Keep original capsule boundary and subtract precisely 4.55 x 9.40 m")
	var underlay: Mesh = game.get_node("ArenaOndergrond").mesh
	var lower: PackedVector3Array = underlay.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,lower.size(),3):
		check(not Geometry2D.is_point_in_polygon(Vector2.ZERO,PackedVector2Array([Vector2(lower[i].x,lower[i].z),Vector2(lower[i+1].x,lower[i+1].z),Vector2(lower[i+2].x,lower[i+2].z)])),"No hidden underlay covers the stairwell")
	var stairs: Node3D = infield.get_node("Keldertrap")
	var prior_top := 0.0
	for i in range(15):
		var step: MeshInstance3D = stairs.get_node("Trede_%02d" % i)
		var top: float = step.position.y+step.mesh.get_aabb().end.y
		check(top<prior_top and top<0,"Each real 3D tread descends below the floor")
		prior_top = top
	check(absf(prior_top+2.73)<0.0001,"Stairs reach the 2.70 m deep basement")
	game.free()
	print("INFIELD_BOXES_OK" if failures==0 else "INFIELD_BOXES_FAILED: "+str(failures))
	quit(0 if failures==0 else 1)
