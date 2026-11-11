extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for i in range(4): await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://verification/madison_v02/"+name+".png") == OK)
func capture() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	var menu = game.setup_panel; menu.training_store.folder = "user://capture_madison_feedback"
	menu.show_madison_training(); menu.madison_page.begin()
	var scene = game.madison_training_environment
	scene._present(1.0)
	await shot("10_settling_in_half_lap")
	scene._spawn_partner() # Explicit exchange fixture after the normal settling-in start.
	scene.distances.assign([90.0,95.0]); scene.speeds.assign([12.0,8.0]); scene.lane_offsets.assign([4.78,3.58])
	scene.madison.step(scene,.02); scene._present(1.0)
	await shot("05_invalid_position")
	scene.lane_offsets[0] = 2.38; scene.madison.step(scene,.1); scene._present(1.0)
	await shot("06_outgoing_zone")
	scene.madison.reset(); scene.madison.active_rider = 1; scene.attempt_giver = 1
	scene.distances.assign([95.0,90.0]); scene.speeds.assign([8.0,12.0]); scene.lane_offsets.assign([3.58,2.38])
	scene.madison.step(scene,.1); scene._present(1.0)
	await shot("07_incoming_zone")
	scene.feedback = "Inkomend · 100% · Geslaagd"; scene.feedback_until = 100
	scene.partner_present = false; scene._present(1.0)
	await shot("08_exchange_score")
	# Visual fixture for a complete ten-row report, including failed attempts.
	scene.exchange_results.clear(); scene.page.progress.reset_session(10)
	for i in range(10):
		scene.pending_trial = true; scene.attempt_giver = i%2
		scene.madison.efficiency = .7 if i%3 else 0.0
		scene.madison.failure_reason = ("Je reed te traag als inkomende renner: 20 km/u (minimum 35 km/u)" if i%2 else "Te ver van je ploegmaat") if i%3 == 0 else ""
		scene._score(i%3 != 0)
	scene.finish_session("Training voltooid")
	await shot("09_exchange_results")
	game.queue_free(); await process_frame; await process_frame
	print("MADISON_FEEDBACK_CAPTURES_OK"); quit()
