extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	var mixed: Node3D = infield.get_node("WielerpraatMixedZone")
	var podium: Node3D = infield.get_node("Podium")
	var beer: Node3D = infield.get_node("BierTrustNoOne")
	var pizza: Node3D = infield.get_node("PizzaOven")
	check(podium.position.is_equal_approx(Vector3(9.4,0,16)), "Podium occupies old beer stall position")
	check(beer.position.is_equal_approx(Vector3(0,0,41.5)), "Beer tent occupies old podium position")
	check(float(beer.get_meta("floor_area_m2")) == 2.0 * float(beer.get_meta("previous_floor_area_m2")), "Beer tent has double the floor area")
	check(mixed.get_meta("branding_faces") == 2, "Mixed-zone wall branded on both sides")
	check(mixed.has_node("RennerEuropeesKampioen") and mixed.has_node("RensterEuropeesKampioen") and mixed.has_node("BlauweLoper"), "Both interview cyclists and through-route present")
	check(infield.has_node("MixedZoneCamera"), "Interview camera present")
	var route_start: Vector3 = mixed.get_meta("route_start")
	var route_end: Vector3 = mixed.get_meta("route_end")
	check(route_start.z > mixed.position.z and route_end.z < mixed.position.z, "Carpet passes through both open ends of the mixed zone")
	check(route_end.distance_to(podium.position) < 2.1, "Carpet reaches podium approach")
	# Check actual baked mesh data, not only metadata: the two logo faces retain
	# independent UV orientation and the carpet stays free of solid geometry.
	var wp_faces := 0; var roof_prints := 0; var wordmarks := 0; var beer_banner := false; var carpet_vertices := 0
	for zone in [mixed,beer,pizza]:
		for item in zone.get_children():
			if not item is MeshInstance3D: continue
			var material: Material = item.material_override
			var data: Array = item.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			check(not vertices.is_empty(), "Generated geometry is nonempty")
			for vertex in vertices:
				check(vertex.is_finite(), "Geometry is finite")
				var world: Vector3 = zone.position + vertex
				check(absf(world.x) < 16.0 and world.z < 49.0, "New scenery remains in infield")
				if zone == mixed and vertex.y > 0.08 and vertex.y < 1.8 and vertex.z > 1.65 and vertex.z < 5.95:
					check(vertex.x <= -1.20 or vertex.x >= 0.70, "Northern approach has no obstacle on carpet")
			if material is ShaderMaterial and material.shader.resource_path.ends_with("wielerpraat_print.gdshader"):
				var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
				for start in range(0,vertices.size(),6):
					var is_roof := normals[start].y > 0.8
					var expected: Rect2 = preload("res://north_infield.gd").MICROPHONE_UV if is_roof else preload("res://north_infield.gd").WORDMARK_UV
					var minimum := Vector2(1,1); var maximum := Vector2.ZERO
					for k in range(start,start+6):
						minimum = minimum.min(uv[k]); maximum = maximum.max(uv[k])
						if is_roof:
							var vertex: Vector3 = vertices[k]
							var roof_y: float = 3.18 - maxf(absf(vertex.x),absf(vertex.z)) * ((3.18-2.45)/1.55)
							check(vertex.y > roof_y and vertex.y < roof_y+0.02,"Microphone lies just above sloping roof")
					check(minimum.is_equal_approx(expected.position) and maximum.is_equal_approx(expected.end),"Print samples only the requested artwork crop")
					if is_roof: roof_prints += 1
					else:
						wordmarks += 1
						check(normals[start].dot(Vector3.RIGHT)>0.99,"Back wordmark faces piste")
						check(minimum.x>0.24 and maximum.y<0.61,"Outside wordmark excludes microphone and slogan")
			if material is StandardMaterial3D and material.albedo_texture != null:
				if material.albedo_texture.resource_path.ends_with("wielerpraat-boarding.png"):
					wp_faces += vertices.size()/6
				if material.albedo_texture.resource_path.ends_with("trust-no-one-banner.png"):
					beer_banner = true
					check(material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "Beer banner and tent share normal lighting")
					check(is_equal_approx(material.roughness,0.85), "Beer banner and tent share fabric roughness")
			elif zone == beer and not material.vertex_color_use_as_albedo:
				check(material.albedo_color != Color.WHITE, "Beer tent contains no white fabric/counter surfaces")
			if zone == mixed and material is StandardMaterial3D and material.albedo_color == Color("1c4b91"):
				for v in vertices:
					if v.y < 0.06: carpet_vertices += 1
	check(wp_faces == 1, "Inside retains one original full logo")
	check(roof_prints == 4 and wordmarks == 1,"Four roof microphones and one outside wordmark")
	for child in mixed.get_children():
		check(not child is Label3D or "MIXED ZONE" not in child.text,"Roof text removed")
	check(beer_banner, "Original TRUST NO ONE artwork is in generated geometry")
	check(carpet_vertices >= 24, "Blue carpet has real floor geometry")
	var tables := 0; var chairs := 0
	for node in pizza.get_children():
		if not node.get_meta("terrace_table",false): continue
		tables += 1
		for child in node.get_children(): chairs += int(child.get_meta("terrace_chair",false))
	check(tables == 2 and chairs == 6 and pizza.has_node("PizzaVriendenStatafel"), "Pizza terrace has two seated tables and the standing duo")
	check(infield.has_node("ChassePatate") and infield.has_node("Kopwerk"), "Existing south kiosks retained")
	# Export the actual north plaza for a geometry render, including people, carpet,
	# original bar, lights and podium so spatial conflicts are visible.
	if "--north-preview" in OS.get_cmdline_user_args():
		var preview := Node3D.new(); root.add_child(preview)
		for item in infield.get_children():
			if item is Node3D:
				if item is MultiMeshInstance3D: continue
				if item is MeshInstance3D and item.mesh.get_aabb().size.z > 60: continue
				if item.position.z > 8 or item in [mixed,podium,beer,pizza] or item.name == "NoordelijkHorecaterras":
					var copy := item.duplicate(0); preview.add_child(copy)
					for mesh in copy.get_children():
						if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial:
							var source: ShaderMaterial = mesh.material_override
							if source.shader.resource_path.ends_with("wielerpraat_print.gdshader"):
								var carrier := StandardMaterial3D.new(); carrier.resource_name = "WielerpraatPrintPreview"
								carrier.albedo_texture = source.get_shader_parameter("logo"); carrier.roughness = 0.85
								mesh.material_override = carrier
		var doc := GLTFDocument.new(); var state := GLTFState.new()
		check(doc.append_from_scene(preview,state) == OK, "Actual geometry exported")
		check(doc.write_to_filesystem(state,"res://tests/north_preview.glb") == OK, "Preview saved")
		preview.free()
	game.free()
	print("NORTH_INFIELD_OK" if failures == 0 else "NORTH_INFIELD_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
