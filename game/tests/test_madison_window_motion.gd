extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	var page = game.setup_panel.madison_page
	game.setup_panel.training_store.folder = "user://test_window_motion"
	page.progress.path = "user://test_window_motion_progress.cfg"
	game.setup_panel.show_madison_training(); page.begin()
	var scene = game.madison_training_environment
	for role in [0,1]:
		for at in [95.0,180.0]:
			scene.enter()
			var model = scene.madison
			model.active_rider = role; scene.attempt_giver = role
			scene.distances.assign([at,at]); scene.lane_offsets.assign([2.38,3.58] if role == 0 else [3.58,2.38])
			var slow: float = 10.0 if at == 95.0 else 8.0
			scene.speeds.assign([12.0,slow] if role == 0 else [slow,12.0])
			scene.player_lane_target = 2 if role == 0 else 4
			for tick in range(40):
				model.step(scene,1.0/60.0); scene._present(1.0/60.0); await process_frame
			var target: float = model.grab_right-.001
			scene.distances[1-role] = at+model.approach_distance-target*(model.approach_distance+2.5)
			model.step(scene,.0001); scene._present(.0001)
			check(model.can_grab,"Late green edge is accepted, role=%d at=%.0f marker=%.4f window=%.4f..%.4f" % [role,at,model.marker,model.grab_left,model.grab_right])
			scene.grab_button("edge",true); scene.grab_button("edge",false)
			for tick in range(190):
				scene._step(1.0/120.0,300)
				if tick%2 == 0:
					scene._present(1.0/60.0); await process_frame
			check(scene.exchange_results.size() == 1 and scene.exchange_results[0].success,"Late green click completes a moving exchange with IK, role=%d at=%.0f result=%s" % [role,at,str(scene.exchange_results)])
	# The first early press is the only scored press until a fresh opportunity.
	scene.enter(); scene.madison.step(scene,.01); scene._present(.01)
	scene.grab_button("early",true); scene.grab_button("early",false)
	var first_result: Array = scene.exchange_results.duplicate(true)
	scene.grab_button("retry",true); scene.grab_button("retry",false)
	check(first_result.size() == 1 and not first_result[0].success and scene.exchange_results == first_result,"Early click scores once; retry cannot rescue or duplicate the result")
	for i in range(50): scene._step(.01,300)
	check(not scene.partner_present,"Failed early attempt despawns without another exchange")
	game.queue_free(); await process_frame; await process_frame
	print("MADISON_WINDOW_MOTION_OK" if failures == 0 else "MADISON_WINDOW_MOTION_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
