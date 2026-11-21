extends SceneTree
## Performance options: small-prop culling, physics interpolation, HUD rate,
## older-computer preset and FPS display.
const PropCulling := preload("res://prop_culling.gd")
const Guard := preload("res://interpolation_guard.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func mesh_node(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	root.add_child(node)
	return node

func run() -> void:
	var cable := CylinderMesh.new()
	cable.top_radius = 0.006; cable.bottom_radius = 0.006; cable.height = 0.65
	check(PropCulling.range_for(mesh_node(cable)) == PropCulling.THIN_END_M, "Festoon cable gets the short range")
	var cup := BoxMesh.new(); cup.size = Vector3(0.08, 0.2, 0.08)
	check(PropCulling.range_for(mesh_node(cup)) == PropCulling.SMALL_END_M, "Small prop gets the small-prop range")
	var sign := QuadMesh.new(); sign.size = Vector2(3.0, 1.0)
	check(PropCulling.range_for(mesh_node(sign)) == 0.0, "Flat sign is not mistaken for a cable")
	var crate := BoxMesh.new(); crate.size = Vector3(1.0, 1.0, 1.0)
	check(PropCulling.range_for(mesh_node(crate)) == 0.0, "Normal props keep drawing at any distance")
	var tuned := mesh_node(cup); tuned.visibility_range_end = 80.0
	check(PropCulling.range_for(tuned) == 0.0, "Existing visibility ranges are respected")
	var scaled := mesh_node(cup); scaled.scale = Vector3.ONE * 10.0
	check(PropCulling.range_for(scaled) == 0.0, "Scale counts towards prop size")

	var pose := Transform3D(Basis(), Vector3(1, 0, 0))
	check(not Guard.jumped(pose, pose.translated(Vector3(0.4, 0, 0))), "Normal riding is interpolated")
	check(Guard.jumped(pose, pose.translated(Vector3(5, 0, 0))), "Camera cut resets interpolation")
	check(Guard.jumped(pose, Transform3D(Basis(Vector3.UP, PI * 0.5), pose.origin)), "Quarter turn resets interpolation")
	check(not Guard.jumped(pose, Transform3D(Basis(Vector3.UP, 0.1), pose.origin)), "Small turn keeps interpolation")

	var game = preload("res://tests/arena_roof_test_game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(game.get_tree().physics_interpolation, "Physics interpolation enabled")
	check(game.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "Arena and UI stay outside interpolation")
	check(game.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "Race camera interpolated")
	check(not game.bikes.is_empty() and game.bikes.all(func(b): return b.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON), "Riders interpolated")
	check(game.arena.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT and not game.arena.is_physics_interpolated(), "Arena inherits the opt-out")
	var ranged := 0
	for node in game.arena.find_children("*", "MeshInstance3D", true, false):
		if node.visibility_range_end == PropCulling.THIN_END_M or node.visibility_range_end == PropCulling.SMALL_END_M: ranged += 1
	check(ranged > 100, "Small arena props received a visibility range (%d)" % ranged)

	game._hud_state = ""
	check(game._hud_due(1.0 / 60.0), "First HUD update runs")
	var ticks := 1
	while not game._hud_due(1.0 / 60.0) and ticks < 20: ticks += 1
	check(ticks >= 5 and ticks <= 7, "HUD refreshes about ten times per second (every %d ticks)" % ticks)
	game.start_state = "COUNTDOWN" if game.start_state != "COUNTDOWN" else "RACING"
	check(game._hud_due(1.0 / 60.0), "State change refreshes the HUD at once")

	var settings = game.get_node("GameSettings")
	var stored_limit: int = settings.max_fps
	settings.apply_older_computer_preset()
	check(is_equal_approx(settings.scale_slider.value, 0.6) and settings.crowd_slider.value == 0.0, "Preset lowers resolution and crowd")
	check(settings.simple_infield_check.button_pressed and not settings.race_lighting_check.button_pressed, "Preset uses simple graphics and training lighting")
	check(settings.FPS_LIMITS[settings.fps_choice.selected] == 60 and settings.preset_hint.visible, "Preset caps at 60 FPS and explains the restart")
	check(settings.max_fps == stored_limit, "Preset only fills in the form until applied")
	check(settings.fps_label != null and not settings.fps_label.visible, "FPS hidden by default")
	settings.show_fps = true
	settings.max_fps = 60
	settings._apply_display()
	check(settings.fps_label.visible and Engine.max_fps == 60, "FPS display and frame cap applied")
	settings._update_fps_label(1.0)
	check(settings.fps_label.text.ends_with(" FPS"), "FPS label shows frames per second")
	print("PERFORMANCE_OPTIONS_OK" if failures == 0 else "PERFORMANCE_OPTIONS_FAILED %d" % failures)
	quit(failures)
