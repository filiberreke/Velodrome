extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
const HUD := preload("res://race_hud.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func half_times(game: Node, own: Array, opponent: Array) -> void:
	game.pursuit_half_crossings = [own.duplicate(), opponent.duplicate()]
	game.pursuit_half_stats = [[], []]
	for team in range(2):
		for unused in game.pursuit_half_crossings[team]:
			game.pursuit_half_stats[team].append({"kmh": 45.0, "watts": 300.0})

func run_test() -> void:
	var rows := HUD.team_half_summary([10.0, 20.5, 30.0], [11.0, 21.0])
	check(rows[0]["delta"] == 1.0 and rows[1]["delta"] == 0.5, "Difference is cumulative at matching 125 m checkpoints")
	check(rows[1]["seconds"] == 10.5 and rows[2]["seconds"] == 9.5, "Each row shows its own 125 m segment duration")
	check(rows[2]["delta"] == null, "Own half lap is immediate while opponent crossing is pending")
	check(HUD.team_half_summary([10.0], [9.0])[0]["delta"] == -1.0, "Behind opponent has minus sign")
	for count in [3, 4]:
		var game = Game.new()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game.setup_panel.select_mode(2)
		game.setup_panel.team_options.teammates.select(count - 3)
		game.setup_panel.page = 4
		game._confirm_start(); game.broadcast_intro.finish()
		game.start_state = "RACING"; game.running = true
		game.watts = 300.0
		half_times(game, [10.0, 20.5, 30.0], [11.0, 21.0])
		game._update_hud()
		var ui = game.race_overlay
		check(ui.team_laps_panel.visible and not ui.nearby_panel.visible, "Team lap table replaces rider classification")
		check(ui.team_lap_rows[0]["distance"].text == "125 m" and ui.team_lap_rows[1]["distance"].text == "250 m", "Rows identify actual half-lap distance")
		check(ui.team_lap_rows[0]["value"].text == "10.00 s (+1.00 s)", "First half lap and signed advantage formatted together")
		check(ui.team_lap_rows[1]["value"].text == "10.50 s (+0.50 s)", "Later segment time and cumulative advantage shown")
		check(ui.team_lap_rows[2]["value"].text == "9.50 s (…)", "Pending opponent does not fabricate a difference")
		half_times(game, [10.0,20.5,30.0], [11.0,21.0,31.2])
		game._update_hud()
		check(ui.team_lap_rows[2]["value"].text == "9.50 s (+1.20 s)", "Opponent arrival fills pending difference without waiting for another own crossing")
		var own: Array = []
		var opponent: Array = []
		for i in range(32): own.append((i+1)*10.0); opponent.append((i+1)*10.5)
		half_times(game, own, opponent)
		game._update_hud()
		await process_frame
		await process_frame
		check(ui.team_laps_panel.get_global_rect().end.y < ui.bottom_bar.get_global_rect().position.y, "16-lap scrolling table fits above bottom HUD")
		check(ui.team_lap_rows[31]["row"].visible and ui.team_lap_rows[31]["distance"].text == "4000 m", "All 32 half laps retained for a 4 km race")
		check(game.lap_times[0].is_empty() and game.lap_times[1].is_empty(), "HUD preserves official full-lap data used by results")
		half_times(game, [], [])
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
		game.setup_panel.select_mode(0); game._confirm_start(); game.broadcast_intro.finish(); game._update_hud()
		check(ui.nearby_panel.visible and not ui.team_laps_panel.visible, "Other modes keep rider classification")
		check(game.finish_photo_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Other modes restore original photo projection")
		game.free()
	print("TEAM_PRESENTATION_OK" if failures == 0 else "TEAM_PRESENTATION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
