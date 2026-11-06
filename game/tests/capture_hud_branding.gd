extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
var game
const OUTPUT := "res://verification/hud_branding/"
func _initialize() -> void: call_deferred("capture")
func save_view(name: String) -> void:
	for i in range(5): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.setup_panel.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	game.broadcast_intro.holding_chase = false
	game.start_state = "RACING"
	game.running = true
	game.clock = 132.4
	for i in range(game.distances.size()):
		game.distances[i] = 1280.0 - i*3.8
		game.speeds[i] = 14.5
	game.watts = 328.0
	game.trainer_gear = "14"
	game.connected = true
	game._update_visuals(1.0)
	game._update_countdown_display()
	game._update_hud()
	game.race_overlay.signals.set_process(false)
	await save_view("01_race")
	game.trainer_seen = true
	game.start_state = "WAIT_STOP"
	game._update_countdown_display()
	game._update_hud()
	await save_view("02_stop_pedalling")
	game.start_state = "COUNTDOWN"
	game.countdown = 3.0
	game._update_countdown_display()
	game._update_hud()
	await save_view("03_countdown")
	game.start_state = "RACING"
	game.clock = 250.0
	game.distances[0] = game._race_length()-250.0
	game._update_countdown_display()
	game.race_overlay.signals._process(0.12)
	game._update_hud()
	await save_view("04_last_lap_bell")
	game.race_overlay.signals.clear()
	game.race_mode = 4
	game.race_laps = 16
	game.rider_count = 2
	game._configure_peloton()
	game._prepare_pursuit({}, 350.0)
	game.broadcast_intro.holding_chase = false
	game.start_state = "RACING"
	game.clock = 63.42
	game._update_countdown_display()
	game._update_hud()
	game._update_visuals(1.0)
	await save_view("05_pursuit")
	game.race_mode = 7
	game.race_laps = 4
	game.rider_count = 1
	game._configure_peloton()
	game._prepare_pursuit({}, 0.0)
	game.broadcast_intro.holding_chase = false
	game.start_state = "RACING"
	game.clock = 47.8
	game._update_countdown_display()
	game._update_hud()
	game._update_visuals(1.0)
	await save_view("06_time_trial")
	game.race_mode = 5
	game.race_laps = 16
	game.team_size = 3
	game.rider_count = 6
	game._configure_peloton()
	game._prepare_pursuit({}, 350.0)
	game.team_race.prepare(game, {}, 350.0)
	game.team_race.front.assign([500.0,425.0])
	game.team_race.progress.assign([500.0,425.0])
	game.team_race.velocity.assign([12.5,12.5])
	game.team_race._apply_formation(game)
	game.pursuit_half_crossings = [[10.0,20.5,30.3,40.1],[10.8,21.1,30.0]]
	game.pursuit_half_stats = [[],[]]
	for team in range(2):
		for unused in game.pursuit_half_crossings[team]:
			game.pursuit_half_stats[team].append({"kmh":45.0,"watts":328.0})
	game.clock = 40.1
	game._update_countdown_display()
	game._update_hud()
	game._update_visuals(1.0)
	await save_view("07_team_half_laps")
	game.free()
	print("HUD_BRANDING_CAPTURES_OK")
	quit()
