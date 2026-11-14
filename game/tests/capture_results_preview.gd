extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var game
const DEST := "/workspace/scratch/febdc52abbf2/"
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(2): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+name+".png")
func run() -> void:
	root.size = Vector2i(1600,900)
	game = Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(5): await process_frame
	game.setup_panel.select_mode(3);game._confirm_start();game.broadcast_intro.finish();game.broadcast_intro.cancel()
	game.rider_count = 8;game.race_mode = 1;game.race_laps = 40;game._configure_peloton()
	game.points_rules.points.assign([21,31,15,8,0,0,0,0])
	game.points_rules.gains[1] = 1
	var orders := [[1,0,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[2,0,3,1,4,5,6,7],[0,2,3,1,4,5,6,7]]
	for j in range(4): game.points_rules.sprints.append({"lap":(j+1)*10,"seconds":195.*(j+1),"order":orders[j],"awards":[10,6,4,2,0,0,0,0] if j == 3 else [5,3,2,1,0,0,0,0]})
	for i in game.rider_count:
		game.finish_times[i] = 787.+i*.13
		game.distances[i] = 10000.
	game.clock=788.;game.finished=true
	game.setup_panel.hide();game.finish_overlay.show();game._set_race_hud_visible(false)
	game._refresh_fullscreen_results()
	await shot("godot-puntenkoers")
	game.finish_table.get_node("ResultRider0").button_pressed = true
	game._refresh_fullscreen_results()
	assert(game.finish_table.get_node("SprintDetails0").visible, "Details survive repeated refreshes")
	await shot("godot-sprintdetails")
	game.race_mode=0;game.race_laps=10;game._configure_peloton()
	for i in game.rider_count: game.finish_times[i]=196.84+i*.13
	game.player_power_integral=286.*196.84;game.player_peak_watts=1042.
	game._refresh_fullscreen_results()
	await shot("godot-scratch")
	game.race_mode=2;game.rider_count=8;game._configure_peloton()
	game.elimination_rules.eliminated.assign([7,6,0,5,4,3])
	for i in game.rider_count: game.finish_times[i]=196.84+i*.13
	game._refresh_fullscreen_results()
	await shot("godot-afvalling")
	print("RESULTS_PREVIEW_CAPTURED")
	quit()
