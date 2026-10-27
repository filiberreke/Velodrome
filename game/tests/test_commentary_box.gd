extends SceneTree
const Suite := preload("res://commentary_box.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := preload("res://main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var arena: Node3D = game.arena
	var suite := arena.get_node_or_null("EuroMaxCyclingCommentaryBox") as Node3D
	check(suite != null, "Broadcast suite was not installed")
	if suite == null:
		quit(1)
		return
	check(suite.get_meta("channel") == "EuroMaxCycling", "Wrong channel brand")
	check(suite.transform.basis.determinant() > 0.99, "Mirrored suite frame")
	var outward: Vector3 = arena._outward(0.0)
	check(suite.basis.z.dot(-outward) > 0.999, "Windows must face the track")
	var rim: Vector3 = game._at(0.0, arena.STAND_RIM)
	check(absf(suite.position.y - rim.y - 8.54) < 0.001, "Wrong tier deck height")
	check(Suite.reserves_seat(arena, 1, 0.0, 28.0), "Cabin seat footprint not cleared")
	check(not Suite.reserves_seat(arena, 0, 0.0, 28.0), "Tier 1 was incorrectly cleared")
	check(not Suite.reserves_seat(arena, 2, 0.0, 28.0), "Tier 3 was incorrectly cleared")
	check(not Suite.reserves_seat(arena, 1, 20.0, 28.0), "Distant seating was incorrectly cleared")
	var mesh_count := 0
	var triangle_count := 0
	var surfaces := 0
	var mouths: Array[MeshInstance3D] = []
	for node in suite.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		if node.mesh.get_blend_shape_count() > 0:
			mouths.append(node)
		surfaces += node.mesh.get_surface_count()
		for i in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(i)
			triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(mesh_count <= 16, "Mesh batching regressed")
	check(surfaces <= 44, "Draw surface budget exceeded")
	check(triangle_count > 100000 and triangle_count < 500000, "Detailed model triangle budget exceeded")
	check(mouths.size() == 2, "Both mouths need actual deforming geometry")
	check(suite.voices.size() == 2, "Independent mouth animation players missing")
	for voice in range(suite.voices.size()):
		var player: AnimationPlayer = suite.voices[voice]
		player.seek(0.04, true)
		var before: Array[float] = []
		for mouth in mouths: before.append(mouth.get_blend_shape_value(0))
		player.seek(0.25, true)
		var moving := 0
		for i in range(mouths.size()):
			if absf(before[i] - mouths[i].get_blend_shape_value(0)) > 0.15: moving += 1
		check(moving == 1, "Each voice must independently deform exactly one mouth")
		suite.set_speaking(voice, false)
		check(not player.is_playing(), "Speaking stop cue ignored")
		suite.set_speaking(voice, true)
		check(player.is_playing(), "Speaking start cue ignored")
	check(suite.find_children("*", "Light3D", true, false).size() == 2, "Practical light budget changed")
	check(suite.find_children("*", "CollisionObject3D", true, false).is_empty(), "Cabin adds gameplay collision")
	var state: String = game.start_state
	for i in range(10):
		await process_frame
	check(game.start_state == state, "Decorative suite changed race state")
	print("COMMENTARY_BOX_STATS meshes=%d surfaces=%d triangles=%d origin=%s" % [mesh_count, surfaces, triangle_count, suite.position])
	game.free()
	if failures == 0:
		print("COMMENTARY_BOX_OK")
	quit(0 if failures == 0 else 1)
