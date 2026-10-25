extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var dog := preload("res://assets/people/chihuahua_lasagne.glb").instantiate()
	check(dog.find_child("LangharigeChihuahua",true,false)!=null and dog.find_child("Lasagneschotel",true,false)!=null,"Dog and lasagne exported together")
	dog.free()
	var fan := preload("res://assets/people/supporter_wout.glb").instantiate()
	check(fan.find_child("OudereWoutSupporter",true,false)!=null and fan.find_child("SpandoekDoek",true,false)!=null,"Supporter and held banner exported together")
	root.add_child(fan)
	var banner: MeshInstance3D = fan.find_child("SpandoekDoek",true,false)
	var min_banner_height := 10.0
	for surface in range(banner.mesh.get_surface_count()):
		for point in banner.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			min_banner_height = minf(min_banner_height,(banner.global_transform*point).y)
	check(min_banner_height>1.89,"Banner raised above head, face and torso remain visible")
	fan.free()
	var game = preload("res://main.gd").new();root.add_child(game);game.set_physics_process(false);await process_frame
	var arena: Node3D = game.arena
	var detail: Node3D = arena.get_node("TourBochtDetails")
	var stair_dog: Node3D = detail.get_node("ChihuahuaLasagne")
	check(arena._aisle(stair_dog.get_meta("stair_s")),"Dog is on a real radial stair")
	check(stair_dog.position.is_equal_approx(arena._stadium_point(147.15,15.60,2.502)),"Dog sits above lower rows on fifth stair tread")
	var spectator: Node3D = detail.get_node("WoutSupporter")
	check(spectator.get_meta("tier")==0 and spectator.get_meta("row")==0,"Supporter is in front row")
	check(not arena._aisle(152.4),"Supporter does not block stair")
	check(spectator.get_node("WoutSpandoekTekst").text=="WOUT WOUT WOUT!","Exact banner wording")
	check(spectator.get_node("WoutSpandoekTekst").position.y>2.0,"Text follows raised banner")
	var inward: Vector3 = -arena._outward(152.4)
	check(spectator.basis.z.dot(inward)>0.99,"Banner faces piste")
	game.free()
	print("TOUR_DETAILS_OK" if failures==0 else "TOUR_DETAILS_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
