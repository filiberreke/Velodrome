extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var duo := preload("res://assets/people/pizza_vrienden_statafel.glb").instantiate()
	root.add_child(duo)
	for name in ["ManGestreept","ManRodePolo","BaardPizzaEnWijn","BrilEnWijn","StatafelPizza"]:
		check(duo.find_child(name,true,false)!=null,"Reference detail exported: "+name)
	var names := {}; var pending: Array[Node] = [duo]; var tallest := 0.0
	while not pending.is_empty():
		var node: Node = pending.pop_back(); pending.append_array(node.get_children())
		if not node is MeshInstance3D: continue
		for index in range(node.mesh.get_surface_count()):
			var mat: StandardMaterial3D = node.mesh.surface_get_material(index)
			check(mat!=null and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Opaque low-poly materials")
			names[mat.resource_name] = true
			for p in node.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = node.global_transform*p
				check(world.is_finite(),"Finite vertices")
				tallest = maxf(tallest,world.y)
	check(tallest>1.65 and tallest<1.95,"Standing human scale")
	for key in ["stripe","navy","polo","beard","glasses","wine","cheese","basil"]:
		check(names.has(key),"Visible reference material: "+key)
	duo.free()
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	var oven: Node3D = game.arena.get_node("LevendigMiddenterrein/PizzaOven")
	check(oven.get_meta("seated_tables")==2 and oven.get_meta("standing_tables")==1,"Only track-side table replaced")
	check(oven.has_node("Pizzatafel1") and oven.has_node("Pizzatafel2") and not oven.has_node("Pizzatafel3"),"Other seated tables retained")
	var friends: Node3D = oven.get_node("PizzaVriendenStatafel")
	check(friends.position.is_equal_approx(Vector3(2.6,0,0.5)) and friends.get_meta("standing_guests")==2,"Duo at requested track-side spot")
	var tunnel: Node3D = oven.get_node("Oventunnel")
	var back: float = tunnel.get_meta("back_z")
	var front: float = tunnel.get_meta("front_z")
	check(back-front>0.9,"Arch is a deep vault, not a floating plane")
	# The rear upper arch lies strictly within the hemisphere, guaranteeing overlap.
	var top: float = tunnel.get_meta("spring_y")+tunnel.get_meta("outer_radius")
	var ellipse := pow((back-0.12)/1.0,2)+pow((top-1.20)/0.825,2)
	check(ellipse<1.0,"Vault physically penetrates dome at upper joint")
	check(game.arena.get_node("LevendigMiddenterrein/WielerpraatMixedZone").get_meta("interview_pairs")==2,"Mixed-zone interviews retained")
	game.free()
	print("PIZZA_GUESTS_OK" if failures==0 else "PIZZA_GUESTS_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
