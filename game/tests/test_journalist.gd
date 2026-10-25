extends SceneTree
const REPORTER := preload("res://assets/people/journaliste_regenboog.glb")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var reporter := REPORTER.instantiate() as Node3D; root.add_child(reporter)
	var stripe_heights := {}
	var materials := {}; var count := 0; var maximum_height := 0.0
	var pending: Array[Node] = [reporter]
	while not pending.is_empty():
		var item: Node = pending.pop_back(); pending.append_array(item.get_children())
		if not item is MeshInstance3D: continue
		for surface in range(item.mesh.get_surface_count()):
			var material: StandardMaterial3D = item.mesh.surface_get_material(surface)
			var title: String = material.resource_name
			materials[title] = true
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			for point in arrays[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = item.global_transform * point
				count += 1; maximum_height = maxf(maximum_height,world.y)
				if title.begins_with("rainbow_") and absf(world.x)<0.14 and world.y>1.09 and world.y<1.23:
					if not stripe_heights.has(title): stripe_heights[title] = [0.0,0]
					stripe_heights[title][0] += world.y; stripe_heights[title][1] += 1
				check(world.is_finite(),"Model vertices finite")
				if title == "denim": check(world.y >= 0.739,"Jeans are short, with bare legs below")
				if title.begins_with("glasses_"): check(world.y > 1.60,"Sunglasses rest in hair above forehead")
	for name in ["jersey_white","denim","denim_cuff","hair_honey_blonde","hair_highlight","glasses_frame","glasses_lens","rainbow_blue","rainbow_black","rainbow_red","rainbow_yellow","rainbow_green"]:
		check(materials.has(name),"Model has material: "+name)
	var stripe_order := ["rainbow_blue","rainbow_red","rainbow_black","rainbow_yellow","rainbow_green"]
	var previous_height := 2.0
	for color in stripe_order:
		check(stripe_heights.has(color),"Chest band exists: "+color)
		if not stripe_heights.has(color): continue
		var average: float = stripe_heights[color][0] / float(stripe_heights[color][1])
		check(average < previous_height-0.015,"Top-to-bottom rainbow order: blue, red, black, yellow, green")
		previous_height = average
	check(count > 3000 and count < 25000,"Model has bounded detailed geometry")
	check(maximum_height > 1.65 and maximum_height < 1.85,"Reporter uses existing human scale")
	reporter.free()
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	var infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	var mixed: Node3D = infield.get_node("WielerpraatMixedZone")
	check(mixed.has_node("JournalisteRegenboog"),"New reporter actually used in mixed zone")
	check(mixed.get_node("JournalisteRegenboog").position.is_equal_approx(Vector3(-0.8,0,0.1)),"Interview position retained")
	game.free()
	print("JOURNALIST_OK" if failures == 0 else "JOURNALIST_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
