extends SceneTree
## Run with an isolated user directory: godot --headless --path game --script res://tests/test_graphics_settings.gd
const Paths := preload("res://config_paths.gd")
const Layout := preload("res://infield_layout.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func make_game():
	var game = preload("res://tests/arena_roof_test_game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	return game
func check_scene(game, simple: bool) -> void:
	var arena: Node3D = game.arena
	var field: Node3D = arena.get_node("LevendigMiddenterrein")
	check(arena.simple_infield == simple and field.simple_infield == simple, "Saved preference reaches stadium and infield")
	check(arena.TIERS.size() == 2, "Compact two-tier stadium in both modes")
	check(arena.has_node("InfinityScreen"), "Live curved screen retained")
	check(arena.has_node("EuroMaxCyclingCommentaryBox") != simple, "Commentary cabin follows preference")
	var tour_details := arena.get_node_or_null("TourBochtDetails")
	check((tour_details == null) == simple, "Special Tour spectators only exist in standard mode")
	if not simple and tour_details != null:
		check(tour_details.has_node("ChihuahuaLasagne"), "Standard mode retains lasagne-eating dog")
		check(tour_details.has_node("WoutSupporter/WoutSpandoekTekst") and tour_details.get_node("WoutSupporter").get_meta("supporter_count") == 2, "Standard mode retains both WOUT supporters and banner")
	check(field.get_node("Rennersboxen").boxes.size() == 6 and field.get_node("Rennersboxen").crews.size() == 6, "Rider boxes and crews retained")
	check(field.has_node("Keldertrap"), "Central stairs retained")
	var stair := field.get_node("Keldertrap")
	var steps := 0
	for node in stair.get_children():
		if String(node.name).begins_with("Trede_"): steps += 1
	check(steps == 15 and stair.has_node("Kelderbordes") and stair.has_node("Kelderbord"), "All 15 steps, landing and sign retained")
	check(field.flag_node != null and field.official_clips.size() == 4, "Animated official retained")
	check(field.find_child("officials_table", true, false) != null and field.find_child("tv_camera", true, false) != null, "Jury and finish camera retained")
	check(field.has_node("Podium"), "Results podium retained")
	check(field.has_node("WielerpraatMixedZone") != simple and field.has_node("Lichtslingers") != simple, "Full media zone and decoration remain optional")
	check(field.supporter_count == (400 if simple else 2000), "Expected supporter count")
	var near := 0
	var far := 0
	for node in arena.get_children():
		if node is MultiMeshInstance3D and String(node.name).begins_with("Publiek blok "):
			if String(node.name).ends_with("L1"): near += 1
			else:
				far += 1
				check(is_zero_approx(node.visibility_range_begin) if simple else is_equal_approx(node.visibility_range_begin,32.0), "Crowd range follows graphics setting")
	check(near == 0 and far > 0 if simple else near > 0 and near == far, "Original near/far crowd only in full mode")
	if simple:
		var tents := field.get_node("EenvoudigeTenten")
		check(tents.get_meta("tent_count") == 6 and tents.get_child_count() == 3, "Six plain tents share three render objects")
		var clear := true
		for p in field.supporter_positions:
			clear = clear and not Layout.coach_gate(p,0.3)
			clear = clear and not (absf(p.x) < 2.275 and absf(p.z) < 4.70)
		check(clear, "Supporters leave stairwell and coach passages clear")
		for node in field.get_children():
			if String(node.name).begins_with("Eenvoudig publiek"):
				check(String(node.name).ends_with("L1"), "Infield supporters use low-detail mesh")
	# An overhead fixture must sit above spectators, rather than behind their heads.
	for i in range(24):
		var s := 250.0 * (float(i) + 0.5) / 24.0
		var mount: Vector3 = arena._roof_light_mount(s)
		var last_row: Vector3 = arena._stadium_point(s,29.0,8.44)
		check(mount.y > last_row.y + 1.8, "Roof spotlights clear the upper seating row")
func check_intro(game, simple: bool) -> void:
	game.get_node("GameSettings").always_show_intro = true
	for mode in [0,4,5]:
		game.race_mode = mode
		game._configure_peloton()
		game._set_menu_visible(false)
		game._update_visuals(1.0/60.0)
		var intro = game.broadcast_intro
		intro.start()
		var expected := 2.5 if simple else (28.0 if mode in [4,5] else 26.0)
		check(is_equal_approx(intro.duration,expected), "Intro duration follows preset and discipline")
		check(intro.light_show.running != simple, "No light show in short intro")
		if simple:
			for t in [0.0,1.0,2.49]:
				var shot: Dictionary = intro.sample(t)
				check(shot.position.is_equal_approx(intro.chase_pose().position), "Short intro stays with riders")
			check(not intro.opponent_card.visible, "No portrait pause in short intro")
		intro.advance(expected - 0.01)
		check(intro.active, "Intro remains active until the final instant")
		intro.advance(0.02)
		check(not intro.active and game.start_state == "WAIT_STOP", "Intro hands off to normal start gate")
		intro.cancel()
func run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display","fullscreen",false)
	cfg.set_value("display","width",1280)
	cfg.set_value("display","height",720)
	cfg.save(Paths.user_path("display_settings.cfg"))
	var game = make_game()
	await process_frame
	var settings = game.get_node("GameSettings")
	check(not settings.simple_infield and not settings.simple_infield_check.button_pressed, "Missing preference defaults to standard graphics")
	check_scene(game,false)
	check_intro(game,false)
	settings.simple_infield_check.button_pressed = true
	settings._on_apply()
	var stored := ConfigFile.new()
	check(stored.load(Paths.user_path("display_settings.cfg")) == OK and stored.get_value("arena","simple_infield",false), "Apply saves selected graphics setting")
	check(not game.arena.simple_infield, "Scene stays unchanged until restart")
	game.free()
	await process_frame
	game = make_game()
	await process_frame
	settings = game.get_node("GameSettings")
	check(settings.simple_infield_check.button_pressed, "Checkbox reloads saved choice")
	check_scene(game,true)
	check_intro(game,true)
	settings.simple_infield_check.button_pressed = false
	settings._on_apply()
	game.free()
	await process_frame
	game = make_game()
	await process_frame
	check_scene(game,false)
	game.free()
	print("GRAPHICS_SETTINGS_OK" if failures == 0 else "GRAPHICS_SETTINGS_FAILED failures=" + str(failures))
	quit(0 if failures == 0 else 1)
