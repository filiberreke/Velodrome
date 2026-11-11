extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	var menu = game.setup_panel
	menu.training_store.folder = "user://test_madison_feedback"
	menu.show_madison_training(); menu.madison_page.begin()
	var scene = game.madison_training_environment
	var hud = scene.hud.exchange_hud
	scene.distances.assign([90.0,90.0]); scene.speeds.assign([12.0,8.0])
	for lanes in [[4.78,3.58],[1.18,3.58],[3.28,3.58]]:
		scene.lane_offsets.assign(lanes); scene.madison.reset()
		scene.madison.step(scene,.01); scene._present(.01)
		check(not hud.show_slider and hud.hint.text.contains("Aflossen niet mogelijk wegens slechte positionering"),"Bad position hides timing bar and explains why")
		check(scene.exchange_zone.visible and not scene.madison.can_grab,"Training zone remains visible while correcting a bad position")
		scene.grab_button("test",true); scene.grab_button("test",false)
		check(scene.madison.phase == scene.madison.Phase.APPROACH,"Bad positioning cannot start a grab")
	scene.lane_offsets.assign([2.38,3.58]); scene.speeds.assign([18.0,8.0]); scene.madison.reset()
	scene.madison.step(scene,.02); scene._present(.1)
	check(not hud.show_slider and hud.hint.text.contains("wegens je snelheid"),"Excessive outgoing speed hides the timing bar and explains the speed problem")
	scene.speeds.assign([12.0,8.0])
	scene.lane_offsets.assign([2.38,3.58]); scene.player_lane_target = 2
	scene.madison.reset(); scene.madison.step(scene,.02); scene._present(.1)
	var giver_mesh: Mesh = scene.exchange_zone.mesh
	check(hud.show_slider and hud.state.can_grab,"Green indicator uses actual accepted grab condition")
	check(hud.hint.text.contains("Volg de gele lijn en rij sneller dan"),"Approach has explicit positioning guidance")
	scene.grab_button("test",true); scene.grab_button("test",false)
	for tick in range(190):
		scene._step(1.0/120.0,300)
		if tick%2 == 0:
			scene._present(1.0/60.0); await process_frame
	check(scene.exchange_results.size() == 1,"Accepted green click records exactly one result during real moving physics")
	check(scene.exchange_results[0].success,"An aligned green click succeeds with moving riders")
	check(not hud.feedback_label.text.is_empty() and hud.feedback_label.text.contains("%"),"Each exchange shows a percentage score")
	# The score and Easy momentum cap are separate values.
	scene.madison.efficiency = .7
	check(is_equal_approx(scene.madison.score_percent(),100.0),"Perfect Easy scores 100 while transferring 70 percent momentum")
	scene.madison.advanced = true; scene.madison.efficiency = 1.0
	check(is_equal_approx(scene.madison.score_percent(),100.0),"Perfect Advanced scores 100")
	scene.madison.reset(); scene.madison.active_rider = 1; scene.attempt_giver = 1
	scene.lane_offsets.assign([3.58,2.38]); scene.player_lane_target = 4
	scene.speeds.assign([8.0,12.0]); scene.distances.assign([120.0,120.0])
	scene.madison.step(scene,.02); scene._present(.1)
	check(scene.exchange_zone.mesh != giver_mesh and hud.hint.text.contains("Inkomend"),"Yellow zone changes with the receiving role")
	check(hud.show_slider,"Correct incoming player position permits timing")
	scene.speeds.assign([51.0/3.6,16.0]); scene.madison.step(scene,.01); scene._present(.1)
	check(not hud.show_slider and hud.hint.text.contains("50 km/u"),"Incoming sprint warning names the maximum speed")
	scene.speeds.assign([8.0,12.0])
	scene.pending_trial = true
	scene.lane_offsets[0] = 5.38
	scene.madison.cancel("Ontvanger buiten de wisselzone")
	scene._present(.1)
	check(scene.exchange_results.size() == 2 and not scene.exchange_results[1].success,"Failed attempt receives its own result")
	check(scene.exchange_results[1].role == "Inkomend" and not scene.exchange_results[1].reason.is_empty() and scene.exchange_results[1].score == 0,"Failure records role, reason and zero score")
	check(not hud.show_slider,"No stale slider remains after cancellation")
	for i in range(8):
		scene.pending_trial = true; scene.attempt_giver = i%2
		scene._score(false)
	scene.finish_session("Training voltooid")
	var page = menu.madison_page
	var saved: Dictionary = menu.training_store.load_activity(scene.activity.id)
	check(saved.exchanges.size() == 10,"Archive retains every attempt")
	check(page.results_scroll.visible and page.results_table.get_child_count() == 55,"Results table contains five columns and all ten rows")
	check(page._display_exchange({"role":"Inkomend","reason":"Te traag als inkomende renner"}).role == "Uitgaand", "Archived legacy roles are corrected when reopened")
	page.show_activity(saved)
	check(page.results_table.get_child_count() == 55,"Reopening archived results reconstructs the same table")
	for i in range(3): await process_frame
	check(root.get_visible_rect().encloses(page.back_button.get_global_rect()),"Results keep the back button inside the screen")
	var twenty: Dictionary = saved.duplicate(true)
	twenty.exchanges.append_array(saved.exchanges.duplicate(true))
	page.show_activity(twenty)
	for i in range(3): await process_frame
	check(page.results_table.get_child_count() == 105 and page.results_scroll.get_v_scroll_bar().max_value > page.results_scroll.size.y,"Twenty-row reports are scrollable")
	page.begin()
	scene.distances.assign([90.0,90.0]); scene.lane_offsets.assign([2.38,3.58]); scene.speeds.assign([12.0,10.0])
	scene.madison.step(scene,.02); scene.grab_button("stop",true)
	scene.finish_session("Handmatig gestopt")
	check(page.selected_activity.exchanges.size() == 1 and page.selected_activity.exchanges[0].reason == "Handmatig gestopt","Stopping during a grab preserves an interrupted attempt and its reason")
	page.begin()
	scene.distances.assign([90.0,90.0]); scene.lane_offsets.assign([2.38,3.58]); scene.speeds.assign([18.0,8.0])
	scene.madison.step(scene,.02); scene.distances[0] += 4.0; scene.madison.step(scene,.02)
	scene.finish_session("Snelheidstest")
	check(page.selected_activity.exchanges.size() == 1 and page.selected_activity.exchanges[0].reason.contains("snelheidsverschil"),"Actual failed speed attempt retains its cause in the report")
	game.queue_free(); await process_frame; await process_frame
	print("MADISON_FEEDBACK_OK" if failures == 0 else "MADISON_FEEDBACK_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
