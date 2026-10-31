extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := preload("res://tests/arena_roof_test_game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var arena: Node3D = game.arena
	for component in ["ArenaRoofStructure", "ProfessionalFloodlights", "InfinityScreen"]:
		check(arena.has_node(component), "Missing integrated component: " + component)
	var screen = arena.get_node("InfinityScreen")
	screen.scoreboard.suspend_scoreboard()
	screen.set_content(preload("res://assets/boarding/velodrome-boarding.png"))
	check(is_equal_approx(screen.BOTTOM, 13.0) and screen.BOTTOM + screen.HEIGHT < 16.0, "Requested 13 m screen clearance")
	check(screen.perimeter > 80 and screen.perimeter < 100, "Compact screen proportional to central infield")
	for surface in ["OuterLED", "InnerLED"]:
		var node: MeshInstance3D = screen.get_node(surface)
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(uv.size() == 642, "Complete continuous UV strip")
		var span := absf(uv[-1].x - uv[0].x)
		var pitch: float = node.material_override.get_shader_parameter("panel_pitch")
		check(absf(span / pitch - roundf(span / pitch)) < 0.0001, "Logo wraps without partial repeat")
		check(arrays[Mesh.ARRAY_VERTEX][0].distance_to(arrays[Mesh.ARRAY_VERTEX][-2]) < 0.001, "Ring geometry seam")
	var original: Texture2D = preload("res://assets/boarding/velodrome-boarding.png")
	check(screen.display_materials[0].get_shader_parameter("content_texture") == original, "Original boarding brand")
	var replacement: Texture2D = preload("res://assets/boarding/velodrome-boarding-licht.png")
	screen.set_content(replacement)
	for mat in screen.display_materials: check(mat.get_shader_parameter("content_texture") == replacement, "Both sides accept content replacement")
	screen.set_content(original)
	check(screen.find_children("*", "Light3D").is_empty(), "Screen must not add real-time lights")
	check(arena.get_node("ProfessionalFloodlights").find_children("*", "Light3D").is_empty(), "Visible clusters must not add lights")
	check(arena.get_node("ProfessionalFloodlights/LEDSegments").multimesh.instance_count >= 576, "Segmented LED clusters")
	check(arena.has_node("EuroMaxCyclingCommentaryBox"), "Commentary suite retained")
	game.setup_panel.select_mode(0)
	game._confirm_start()
	var intro = game.broadcast_intro
	check(intro.active and intro.DURATION == 44.0, "Existing intro timing retained")
	var reveal: Dictionary = intro.sample(16.0)
	var forward: Vector3 = (reveal.target - reveal.position).normalized()
	check(forward.dot((Vector3(0, 14.3, 0) - reveal.position).normalized()) > cos(deg_to_rad(25)), "Intro frames the screen naturally")
	for i in 441:
		var pos: Vector3 = intro.sample(float(i) / 10.0).position
		# The cabin passage is higher than the screen, but far outside its
		# footprint. Check physical separation from the ring, not global Y.
		if pos.y > screen.BOTTOM - 0.8 and pos.y < screen.BOTTOM + screen.HEIGHT + 0.8:
			var nearest := INF
			for sample in 320:
				var p: Vector3 = screen.point(float(sample) / 320.0)
				nearest = minf(nearest, Vector2(pos.x - p.x, pos.z - p.z).length())
			check(nearest > 1.2, "Intro camera clears screen footprint")
	intro.finish()
	check(game.start_state == "WAIT_STOP", "Skip retains stop gate")
	print("ARENA ROOF: ", "PASS" if failures == 0 else "FAIL", " failures=", failures, " perimeter=", screen.perimeter)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
