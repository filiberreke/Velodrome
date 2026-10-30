extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := preload("res://main.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var show = game.arena.get_node("VelodromeStadiumShow")
	show.set_process(false)
	var svg := FileAccess.get_file_as_string("res://assets/branding/velodrome_tifo.svg")
	check(not "<text" in svg and not "font-family" in svg and not "<image" in svg, "Wordmark must be standalone paths")
	check(show.ART.get_width() == 4096 and show.ART.get_height() == 1024, "Final PNG resolution")
	check(show.ART.get_image().has_mipmaps(), "Distance filtering needs mipmaps")
	var arrays: Array = show.tifo.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_TEX_UV][0] == Vector2(1,1), "Infield wordmark must not be mirrored")
	check(game.arena.board.position.z > 0, "Scoreboard backing must not obscure first-bend cloth")
	game.setup_panel.select_mode(0)
	game._confirm_start()
	show._process(0.0)
	check(show.tifo.visible, "Tifo visible for reveal")
	check(is_equal_approx(show.tifo_material.get_shader_parameter("fold"), 0.025), "Reveal must stay taut")
	var before: Array = game.distances.duplicate()
	game.broadcast_intro.elapsed = 13.0
	game._physics_process(0.0)
	check(game.start_state == "INTRO" and before == game.distances and game.clock == 0, "Presentation must not advance race")
	game.start_state = "RACING"
	for i in game.distances.size(): game.distances[i] = 238.0
	show._process(0.0)
	check(show.tifo.visible and is_equal_approx(show.tifo_material.get_shader_parameter("withdrawal"), 0.5), "Cloth withdraws gradually")
	check(show.tifo_material.get_shader_parameter("fold") > 0.025, "Only withdrawing cloth loosens")
	for i in game.distances.size(): game.distances[i] = 250.0
	show._process(0.0)
	check(not show.tifo.visible, "Cloth clears at lap one")
	game.start_state = "INTRO"
	show._process(0.0)
	check(show.tifo.visible and is_zero_approx(show.tifo_material.get_shader_parameter("withdrawal")), "Restart resets cloth")
	print("TIFO_V2_TESTS_OK" if failures == 0 else "TIFO_V2_TESTS_FAILED %d" % failures)
	game.free()
	quit(failures)
