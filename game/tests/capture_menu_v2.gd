extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
const DEST := "res://verification/menu_v2/"
var game
var menu
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+name+".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	game=Game.new();root.add_child(game);game.set_physics_process(false)
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
	menu=game.setup_panel
	for i in range(12):await process_frame
	menu.select_mode(1)
	await shot("01_pursuit_settings")
	menu.select_mode(2);menu.pursuit_flow.select_size(4)
	menu.pursuit_flow.advanced_toggle.button_pressed=true;menu.pursuit_flow.advanced.show()
	await shot("02_team_settings")
	menu.select_mode(0);menu.show_startlist()
	await shot("03_scratch_startlist")
	menu.startlist_page.open_picker(0)
	await shot("04_available_replacements")
	menu.startlist_page.active_picker.layer.queue_free()
	for i in range(3):await process_frame
	menu.select_mode(3);menu.count_input.value=16;menu.show_startlist()
	await shot("05_points_startlist_16")
	menu.select_mode(5);menu.elimination_count_picker.select(2);menu.show_startlist()
	await shot("06_elimination_startlist_16")
	menu.show_records();menu.records_page.mode_buttons[2].pressed.emit()
	await shot("07_time_trial_records")
	menu.select_mode(0);menu.show_startlist();game._confirm_start();game.broadcast_intro.finish()
	game._set_race_hud_visible(false)
	for i in game.rider_count:
		game.finish_times[i]=120.0+i;game.lap_times[i]=[30.0,30.0,30.0,30.0+i]
	game.finish_overlay.show();game._refresh_fullscreen_results();game._update_visuals(0.0)
	await shot("08_results_podium")
	game.finish_overlay.hide();game._place_results_camera()
	await shot("09_podium_camera")
	game.finish_overlay.show();game._refresh_fullscreen_results();game._update_visuals(0.0)
	root.size=Vector2i(1280,720)
	await shot("10_results_720p")
	print("MENU_V2_CAPTURES_OK")
	game.free();quit()
