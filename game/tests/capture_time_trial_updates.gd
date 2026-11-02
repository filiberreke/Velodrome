extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class History extends "res://time_trial_records.gd":
	func all_rides() -> Array:
		return [{"id":"preview_flying_1k", "distance_m":1000, "start_type":"flying", "seconds":92.0, "finished_at":Time.get_unix_time_from_system() - 60.0, "splits":[12.0,23.0,34.0,45.0,56.0,67.0,79.0,92.0]}]
var viewport: SubViewport
var game: Screen
const FOLDER := "res://verification/time_trial_updates"
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FOLDER + "/" + name + ".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = Screen.new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.player_appearance.suit_id = "netherlands"
	game.setup_panel.select_mode(7)
	game.setup_panel.time_trial_start.select(1)
	game.setup_panel.time_trial_distance.select(1)
	game._confirm_start()
	game.broadcast_intro.finish()
	game.broadcast_intro.cancel()
	game._begin_riding()
	var overview := Camera3D.new()
	game.add_child(overview)
	overview.fov = 80.0
	overview.global_position = Vector3(-28,9,0)
	overview.look_at(Vector3(-12.6,0,0))
	overview.make_current()
	game._set_race_hud_visible(false)
	await shot("solo_boxes")
	overview.queue_free()
	game.camera.make_current()
	game.start_state = "RACING"
	game.finished = true
	game.running = false
	game.clock = 92.0
	game.finish_times[0] = 92.0
	game.distances[0] = 1000.0
	game.lap_times[0].assign([24.0,22.0,22.0,24.0])
	game.pursuit_half_crossings[0].assign([12.0,24.0,35.0,46.0,57.0,68.0,79.0,92.0])
	game._refresh_fullscreen_results()
	game.finish_overlay.show()
	await shot("results")
	game._reset()
	game.setup_panel.records_page.time_trials = History.new()
	game.setup_panel.select_mode(9)
	await shot("latest_flying_1km")
	print("TIME_TRIAL_UPDATES_CAPTURES_OK")
	quit()
