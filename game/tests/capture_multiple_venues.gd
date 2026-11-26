extends SceneTree
const OUTPUT := "res://verification/multiple_venues"
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _ready() -> void:
		super._ready()
		set_physics_process(false)
		bridge_devices.set_process(false); bridge_devices.socket.close(); bridge_devices.panel_root.hide()
func _initialize() -> void: call_deferred("run")
func wait_frames(count: int = 6) -> void:
	for i in count: await RenderingServer.frame_post_draw
func capture(filename: String, jpeg: bool = false) -> void:
	await wait_frames()
	if jpeg: root.get_texture().get_image().save_jpg(OUTPUT + "/" + filename + ".jpg", .92)
	else: root.get_texture().get_image().save_png(OUTPUT + "/" + filename + ".png")
	print("VENUE_CAPTURE ", filename)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	TranslationServer.set_locale("nl")
	var game := Game.new(); root.add_child(game)
	root.scaling_3d_scale = .55
	DisplayServer.window_set_size(Vector2i(1600, 900))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Engine.max_fps = 30
	await wait_frames(12)
	var menu = game.setup_panel
	menu.select_mode(0); menu.select_venue("gent")
	await capture("01-wedstrijd-gent")
	menu.venue_picker.tiles.velodrome.button.pressed.emit()
	await capture("02-wedstrijd-velodrome")
	menu.select_mode(1); menu.pursuit_flow.next_step(); menu.select_venue("gent")
	await capture("03-achtervolging")
	menu.show_tournaments()
	await process_frame
	menu.tournament_page.manager.state = {"version":1, "active":{}, "archive":[]}
	menu.tournament_page.opened = true; menu.tournament_page.draft.venue_id = "gent"; menu.tournament_page.refresh()
	await capture("04-omnium-gent")
	game._reset(); menu.select_mode(7); menu.select_venue("gent")
	game._confirm_start(); game.broadcast_intro.finish(); game._begin_riding()
	game.clock = 22.0; game.distances[0] = 220.0; game.speeds[0] = 12.0; game.baseline_speed = 12.0
	game.pursuit_half_crossings[0] = [8.8, 16.4]
	game._update_visuals(1.0); game._update_hud()
	await capture("05-wedstrijd-op-gent", true)
	game.free()
	await process_frame
	print("MULTIPLE_VENUE_CAPTURES_OK")
	quit()
