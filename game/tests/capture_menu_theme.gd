extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var game
var menu
const DEST := "res://verification/menu_theme/"
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST + name + ".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	menu = game.setup_panel
	for i in range(20): await process_frame
	await shot("01_gallery")
	menu.select_mode(0)
	await shot("02_scratch_settings")
	menu.select_mode(5)
	await shot("03_elimination_settings")
	menu.select_mode(7)
	await shot("04_time_trial_future")
	menu.select_mode(8)
	await shot("05_tempo_future")
	menu.select_mode(1)
	await shot("06_pursuit_distance")
	menu.pursuit_flow.next_step()
	await shot("07_pursuit_opponent")
	menu.show_choices()
	menu.select_mode(2)
	menu.pursuit_flow.select_size(4)
	menu.pursuit_flow.advanced_toggle.button_pressed = true
	menu.pursuit_flow.advanced.show()
	await shot("08_team_distance")
	menu.pursuit_flow.next_step()
	await shot("09_team_opponent")
	menu.show_choices()
	menu.records_store.path = "user://menu_theme_capture_records.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.records_store.path))
	menu.show_records()
	await shot("10_records_empty")
	for i in range(10):
		menu.records_store.add({"id": "capture_%d" % i, "mode": 4, "distance_m": 1000, "team_size": 0, "seconds": 68.42 + i, "player_name": "Voorbeeldspeler %d" % (i + 1), "finished_at": 1793520000.0 + i, "finished_local": "01/11/2026 10:24"})
	menu.records_page.refresh()
	await shot("11_records_top10")
	menu.records_page.mode_buttons[1].pressed.emit()
	await shot("12_team_records_empty")
	menu.show_choices()
	var settings = game.get_node("GameSettings")
	settings.toggle_menu()
	await shot("13_settings_player")
	settings.appearance_tabs.current_tab = 1
	await shot("14_settings_display")
	settings.appearance_tabs.current_tab = 2
	await shot("15_settings_strava")
	settings.toggle_menu()
	menu.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	game._set_race_hud_visible(false)
	for i in game.rider_count:
		game.finish_times[i] = 120.0 + i
		game.lap_times[i] = [30.0, 30.0, 30.0, 30.0 + i]
	game.finish_overlay.show()
	game._refresh_fullscreen_results()
	await shot("16_results")
	print("MENU_THEME_CAPTURES_OK")
	game.free()
	quit()
