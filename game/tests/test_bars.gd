extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(): result.append_array(all_nodes(child))
	return result
func run_test() -> void:
	for title in ["SjampanjeBar","PursoetBar"]:
		var packed: PackedScene = load("res://scenes/bars/"+title+".tscn")
		check(packed != null,"Reusable scene loads: "+title)
		if packed == null: continue
		var bar := packed.instantiate() as Node3D; root.add_child(bar)
		var max_y := 0.0; var shapes := 0
		for item in all_nodes(bar):
			if item is CollisionShape3D:
				shapes += 1; check(item.shape is BoxShape3D,"Simple convex collisions")
			if not item is MeshInstance3D: continue
			for surface_index in range(item.mesh.get_surface_count()):
				var mat: Material = item.get_active_material(surface_index)
				check(mat is StandardMaterial3D,"Opaque standard PBR materials")
				if mat is StandardMaterial3D:
					check(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"No transparent outer walls or glass")
			var bounds: AABB = item.mesh.get_aabb()
			for corner in range(8):
				var position: Vector3 = item.global_transform*bounds.get_endpoint(corner)
				max_y = maxf(max_y,position.y)
		check(absf(max_y-float(bar.get_meta("height_m"))) < 0.02,"Height follows brief")
		check(shapes>=6,"Relevant structural elements have collisions")
		await physics_frame; await physics_frame
		var space := root.world_3d.direct_space_state
		var front := PhysicsRayQueryParameters3D.create(Vector3(0,1.5,-4),Vector3(0,1.5,0))
		check(space.intersect_ray(front).is_empty(),"Serving opening remains free")
		if title == "SjampanjeBar":
			check(bar.has_node("Actors/ToogUitbater") and bar.has_node("Actors/PlateauUitbater"),"Both reference-inspired hosts are part of reusable scene")
			check(bar.get_node("Actors/ToogUitbater").position.z > -1.5,"Bartender stands behind counter")
			check(bar.get_node("Actors/PlateauUitbater").position.x < -2.5,"Tray server stands beside bar")
			check(bar.get_node("Actors/PlateauUitbater").find_child("PlateauMetZevenGlazen",true,false) != null,"Serving tray with seven champagne glasses exported")
		if title == "PursoetBar":
			var side := PhysicsRayQueryParameters3D.create(Vector3(4,1.4,0),Vector3(0,1.4,0))
			check(space.intersect_ray(side).is_empty(),"Right staff entrance is free")
			for label in ["FrontValance","RearValance","CounterPrint","RearPrint","SideBadge"]:
				check(bar.has_node("Branding/"+label),"Pursoet branded on required side: "+label)
		var front_panel: MeshInstance3D = bar.get_node("Branding/Header" if title=="SjampanjeBar" else "Branding/CounterPrint")
		var back_panel: MeshInstance3D = bar.get_node("Branding/RearLabel" if title=="SjampanjeBar" else "Branding/RearPrint")
		check(front_panel.basis.z.z < -0.99,"Front print faces -Z, with native readable UVs")
		check(back_panel.basis.z.z > 0.8,"Back print faces outward +Z")
		bar.free()
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	var host: Node3D = game.arena.get_node("LevendigMiddenterrein")
	var zone: Node3D = host.get_node("NoordelijkeSponsorbars")
	check(zone.has_node("SjampanjeBar") and host.has_node("PursoetBar"),"Both reusable scenes in actual game, each at requested location")
	check(zone.get_meta("supporter_count")==20 and zone.get_meta("table_count")==5,"Twenty supporters around five tables")
	check(zone.get_node("SjampanjeBar").position.x < -3.0,"Champagne west of yellow tent, opposite pizza")
	check(not zone.has_node("PursoetBar"),"No soda tent on north plaza")
	check(host.get_node("PursoetBar").position.is_equal_approx(Vector3(-8.5,0,-16)),"Pursoet replaces southern waffle stall")
	check(not "WAFELS" in FileAccess.get_file_as_string("res://infield_details.gd"),"Old waffle stall removed")
	check(host.has_node("BierTrustNoOne") and host.has_node("PizzaOven"),"Existing northern landmarks retained")
	game.free()
	print("BARS_OK" if failures==0 else "BARS_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
