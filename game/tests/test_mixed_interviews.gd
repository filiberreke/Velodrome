extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	for title in ["journalist_grijs","renner_europees_kampioen","renster_europees_kampioen"]:
		var model := load("res://assets/people/"+title+".glb").instantiate() as Node3D
		root.add_child(model)
		var names := {}; var vertices := 0; var tallest := 0.0
		var pending: Array[Node] = [model]
		while not pending.is_empty():
			var node: Node = pending.pop_back(); pending.append_array(node.get_children())
			if not node is MeshInstance3D: continue
			for surface in range(node.mesh.get_surface_count()):
				var mat: StandardMaterial3D = node.mesh.surface_get_material(surface)
				check(mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"Opaque ordinary materials")
				names[mat.resource_name] = true
				for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var world: Vector3 = node.global_transform * point
					check(world.is_finite(),"Finite model geometry")
					vertices += 1; tallest = maxf(tallest,world.y)
		check(tallest > 1.6 and tallest < 1.95,"Human-scale model: "+title)
		check(vertices > 2000 and vertices < 30000,"Bounded low-poly geometry")
		if title == "journalist_grijs":
			check(model.find_child("MicrofoonEnHorloge",true,false) != null,"Reporter holds his microphone")
			check(names.has("sweater") and names.has("hair"),"Reporter outfit and hair present")
		else:
			for mat_name in ["ek_white","ek_blue","ek_cyan","ek_gold","ek_navy"]:
				check(names.has(mat_name),"European champion jersey colour: "+mat_name)
			check(model.find_child("EuropeseSterrenEnMedaille",true,false) != null,"European stars exported")
		model.free()
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	var mixed: Node3D = game.arena.get_node("LevendigMiddenterrein/WielerpraatMixedZone")
	check(mixed.get_meta("interview_pairs") == 2,"Two simultaneous interviews")
	for pair in [["JournalisteRegenboog","RensterEuropeesKampioen"],["JournalistGrijs","RennerEuropeesKampioen"]]:
		var reporter: Node3D = mixed.get_node(pair[0]); var rider: Node3D = mixed.get_node(pair[1])
		check(is_equal_approx(reporter.position.z,rider.position.z),"Interview pair aligned")
		check(reporter.basis.z.x > 0.99 and rider.basis.z.x < -0.99,"Interview pair faces each other")
		check(reporter.position.distance_to(rider.position)>1.0,"No overlapping bodies")
	check(not mixed.has_node("RennerInterview"),"Old generic yellow rider replaced")
	check(mixed.get_meta("branding_faces") == 2 and mixed.get_meta("roof_microphones") == 4,"Tent branding preserved")
	check(mixed.get_meta("open_passage_width") == 2.0,"Blue route and open entrances retained")
	game.free()
	print("MIXED_INTERVIEWS_OK" if failures==0 else "MIXED_INTERVIEWS_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
