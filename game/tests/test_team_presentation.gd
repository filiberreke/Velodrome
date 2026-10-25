extends SceneTree
const Game := preload("res://main.gd")
const HUD := preload("res://race_hud.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	var rows := HUD.team_lap_summary([20.0, 21.0, 22.0], [21.0, 20.5])
	check(rows[0]["delta"] == 1.0 and rows[1]["delta"] == 0.5, "Difference is cumulative at matching full laps")
	check(rows[2]["delta"] == null and rows[2]["seconds"] == 22.0, "Own lap is immediate while opponent crossing is pending")
	check(HUD.team_lap_summary([20.0], [19.0])[0]["delta"] == -1.0, "Behind opponent has minus sign")
	for count in [3, 4]:
		var game = Game.new()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game.setup_panel.select_mode(2)
		game.setup_panel.team_options.teammates.select(count - 3)
		game._confirm_start()
		game.start_state = "RACING"; game.running = true
		game.watts = 300.0
		game.lap_times[0].assign([20.0, 21.0])
		game.lap_times[1].assign([21.0, 20.5])
		game._update_hud()
		var ui = game.race_overlay
		check(ui.team_laps_panel.visible and not ui.nearby_panel.visible, "Team lap table replaces rider classification")
		check(ui.team_lap_rows[0]["value"].text == "20.00 s (+1.00 s)", "Lap and signed advantage formatted together")
		check(ui.team_lap_rows[1]["value"].text == "21.00 s (+0.50 s)", "Later cumulative advantage shown")
		game.lap_times[0].clear(); game.lap_times[1].clear()
		for i in range(16): game.lap_times[0].append(20.0); game.lap_times[1].append(21.0)
		game._update_hud()
		await process_frame
		await process_frame
		check(ui.team_laps_panel.get_global_rect().end.y < ui.bottom_bar.get_global_rect().position.y, "16-lap scrolling table fits above bottom HUD")
		check(ui.team_lap_rows[15]["row"].visible, "All 16 laps retained")
		game.lap_times[0].clear(); game.lap_times[1].clear()
		# First wheel crosses before the virtual third-rider timing reference.
		game.team_race.front[0] = 999.7
		game.team_race.progress[0] = 999.7
		game.team_race.velocity[0] = 12.0
		game.team_race._apply_formation(game)
		game._update_visuals(0.0)
		game.clock = 100.1
		game._update_race(0.1)
		var photo = game.team_finish_photo
		check(game.team_race.first_wheel_photo and photo.captured_count == count, "First wheel triggers full own-team photo")
		check(game.finish_times[0] >= 0.0 and is_equal_approx(game.finish_times[0], photo.captured_at), "Photo and official team finish use the same first wheel")
		check(is_equal_approx(photo.captured_front, 1000.0), "Snapshot interpolated to exact leading wheel line")
		check(photo.snapshot.get_child_count() == count, "Photo contains every team rider")
		var camera: Camera3D = game.finish_photo_camera
		check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Side photo uses orthographic projection")
		var direction: Vector3 = game._direction(game._rider_distance(0, 1000.0), game.LANES[0])
		check(absf(camera.global_basis.z.dot(direction)) < 0.01, "Camera looks perpendicular to direction of travel")
		var aspect := float(game.finish_photo_viewport.size.x) / float(game.finish_photo_viewport.size.y)
		for geometry in photo._geometry(photo.snapshot):
			if geometry is MeshInstance3D:
				for i in range(8):
					var point: Vector3 = camera.global_transform.affine_inverse() * (geometry.global_transform * geometry.get_aabb().get_endpoint(i))
					check(absf(point.x) <= camera.size * aspect * 0.5 and absf(point.y) <= camera.size * 0.5, "All rider mesh bounds fit photo")
		var first_pose: Transform3D = photo.snapshot.get_child(0).transform
		game._update_visuals(0.05)
		check(photo.snapshot.get_child(0).transform == first_pose, "Live visuals cannot change frozen photo")
		photo.clear(game)
		check(photo.snapshot == null and photo.hidden_geometry.is_empty(), "Snapshot and temporary render layers cleaned up")
		game._reset()
		game.setup_panel.select_mode(0); game._confirm_start(); game._update_hud()
		check(ui.nearby_panel.visible and not ui.team_laps_panel.visible, "Other modes keep rider classification")
		check(game.finish_photo_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Other modes restore original photo projection")
		game.free()
	print("TEAM_PRESENTATION_OK" if failures == 0 else "TEAM_PRESENTATION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
