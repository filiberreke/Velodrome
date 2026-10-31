extends SceneTree
const OUTPUT := "res://verification/dynamic_screen/"
var game: Node3D
var viewport: SubViewport
var board: Node
var review := false
func _initialize() -> void: call_deferred("run")
func configure(selection: int) -> void:
	game._reset()
	game.setup_panel.select_mode(selection)
	game._confirm_start()
	game.set_physics_process(false)
	board.data.clear(); board.poll_elapsed = .1
	board.model.reset()
func snapshot(label: String, delta := .1) -> void:
	board.poll_elapsed = .1
	for i in 16:
		board._process(delta)
		await RenderingServer.frame_post_draw
	if review: viewport.get_texture().get_image().save_jpg(OUTPUT + label + ".jpg", .86)
	else: viewport.get_texture().get_image().save_png(OUTPUT + label + ".png")
	board.viewport.get_texture().get_image().save_png(OUTPUT + label + "_content.png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	review = "--review-previews" in OS.get_cmdline_user_args()
	viewport.size = Vector2i(1000, 625) if review else Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	game = preload("res://tests/arena_roof_test_game.gd").new()
	viewport.add_child(game)
	game.set_physics_process(false)
	await process_frame
	board = game.arena.get_node("InfinityScreen/Scoreboard")
	board.set_process(false)
	configure(3)
	game.broadcast_intro.elapsed = 16.
	game._update_visuals(0.)
	await snapshot("01_intro")
	game.broadcast_intro.cancel()
	game._set_race_hud_visible(false)
	game.start_state = "RACING"; game.clock = 120.
	game.camera.position = Vector3(17, 10, -12)
	game.camera.look_at(Vector3(0, 14, 0)); game.camera.fov = 76
	var count: int = game.rider_count
	for i in count: game.distances[i] = 1200. - i * 2.
	game.points_rules.points[2] = 8; game.points_rules.points[1] = 5
	await snapshot("02_points")
	# Actual jury lapping record supplies the +20 spectacle.
	var positions: Array[float] = []
	for i in count: positions.append(1002. + i * 2.)
	positions[-1] = 1252.
	game.points_rules._judge_laps(positions, 120.)
	await snapshot("03_lap_gain", .075)
	# New race, with a genuine jury sprint and actual 5/3/2/1 awards.
	configure(3); game.broadcast_intro.cancel(); game._set_race_hud_visible(false)
	game.start_state = "RACING"; game.clock = 180.
	var previous: Array[float] = []
	var current: Array[float] = []
	for i in game.rider_count:
		previous.append(2498. - i * .1)
		current.append(2502. - i * .1)
	game.distances.assign(current)
	game.points_rules.advance(previous, current, 180., 2., game.finish_times)
	await snapshot("04_sprint_result")
	configure(0); game.broadcast_intro.cancel(); game._set_race_hud_visible(false)
	game.start_state = "RACING"; game.clock = 100.
	for i in game.rider_count: game.distances[i] = game._race_length() - 140. - i * 3.
	await snapshot("05_final_lap")
	game.finish_times[1] = 110.4
	game.distances[1] = game._race_length()
	await snapshot("06_finish")
	for i in game.rider_count: game.finish_times[i] = 110.8 + i
	game.finish_times[1] = 110.4
	await snapshot("07_winner")
	for selection in [1, 2]:
		configure(selection); game.broadcast_intro.cancel(); game._set_race_hud_visible(false)
		game.start_state = "RACING"; game.clock = 40.
		game.pursuit_half_crossings = [[10., 20., 30.], [10.3, 20.6]]
		game.lap_times[0] = [20.]; game.lap_times[1] = [20.6]
		await snapshot("08_pursuit" if selection == 1 else "09_team")
	# Same display viewed from underneath: inner face has identical readable data.
	game.camera.position = Vector3(0, 5, -8)
	game.camera.look_at(Vector3(0, 18, 0)); game.camera.fov = 98.
	await snapshot("10_inner")
	print("DYNAMIC_SCREEN_CAPTURES_OK")
	game.queue_free()
	await process_frame
	quit()
