extends SceneTree
const Builder := preload("res://branded_kiosks.gd")
const Crowd := preload("res://crowd_kit.gd")
class Host extends "res://infield_details.gd":
	func _ready() -> void: pass
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	var host := Host.new(); root.add_child(host); host.crowd = Crowd.new()
	var builder := Builder.new()
	var kiosks := builder.build(host)
	check(kiosks.size() == 2, "Two branded kiosks built")
	for kiosk in kiosks:
		var tables := 0; var chairs := 0; var parasols := 0
		for child in kiosk.get_children():
			if not child.get_meta("terrace_table", false): continue
			tables += 1
			check(child.get_node_or_null("Parasol") != null, "Every table has its own parasol")
			parasols += int(child.get_node_or_null("Parasol") != null)
			for seat in child.get_children():
				if bool(seat.get_meta("terrace_chair", false)): chairs += 1
		check(tables == 6 and parasols == 6 and chairs == 18, "Six tables, six parasols and eighteen chairs per kiosk")
		check(int(kiosk.get_meta("geometry_batches")) < 40, "Static geometry merged by material")
		var vertices := 0
		for child in kiosk.get_children():
			if not child is MeshInstance3D: continue
			var arrays: Array = child.mesh.surface_get_arrays(0)
			for point in arrays[Mesh.ARRAY_VERTEX]:
				vertices += 1
				var world: Vector3 = kiosk.position + point
				check(absf(world.x) < 13.0 and world.z > -35.5 and world.z < -18.5, "Terraces remain inside allocated infield area")
		check(vertices > 1000, "Batched geometry not empty")
		print("KIOSK %s batches=%d vertices=%d" % [kiosk.name, kiosk.get_meta("geometry_batches"), vertices])
	var coffee: Node3D = kiosks[1]
	check(coffee.has_node("CentraleDaksteun") and int(coffee.get_meta("roof_support_count")) == 1, "Only one central roof support")
	check(coffee.has_node("VrijeRondomToog"), "Continuous annular counter")
	var perimeter_posts := 0
	for child in coffee.get_children():
		if not child is MeshInstance3D: continue
		for point in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var radius: float = Vector2(point.x, point.z).length()
			if point.y > 1.2 and point.y < 2.25 and radius > 1.9 and radius < 2.25: perimeter_posts += 1
	check(perimeter_posts == 0, "Serving perimeter is completely free of roof-support posts")
	check(host.blockers.size() == 14, "Kiosks and tables protected from random crowd placement")
	if "--kiosk-preview" in OS.get_cmdline_user_args():
		var preview := Node3D.new(); root.add_child(preview)
		for i in range(kiosks.size()):
			var copy: Node3D = kiosks[i].duplicate(0); preview.add_child(copy)
			copy.position.z = 0.0
		var document := GLTFDocument.new(); var state := GLTFState.new()
		check(document.append_from_scene(preview, state) == OK, "Preview export contains actual generated Godot meshes")
		check(document.write_to_filesystem(state, "res://tests/kiosk_preview_models.glb") == OK, "Actual geometry preview GLB saved")
		preview.free()
	host.free()
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var actual_infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	check(actual_infield.has_node("ChassePatate") and actual_infield.has_node("Kopwerk"), "Both kiosks appear in the real main-scene infield")
	check(actual_infield.get_node_or_null("food_truck") == null, "Old chip truck replaced rather than overlapped")
	game.free()
	print("BRANDED_KIOSKS_OK" if failures == 0 else "BRANDED_KIOSKS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
