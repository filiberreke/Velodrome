extends SceneTree
class Game extends "res://main.gd":
	var test_port := 0
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(test_port)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	var game := Game.new(); game.test_port = int(args[0]); game.trainer_control.port = int(args[1]); root.add_child(game); game.set_physics_process(false)
	var menu = game.setup_panel
	menu.training_store.folder = "user://test_piste_exercise_udp"
	for i in range(150):
		await create_timer(.02).timeout; game._read_bridge()
		if menu.ftp_page.fresh(game._now_s()): break
	check(menu.ftp_page.fresh(game._now_s()) and game.trainer_virtual,"Actual virtual bridge supplies fresh exercise power")
	for kind in ["flying_start","take_lap","free_ride"]:
		menu.show_piste_exercise(kind); menu.exercise_page.begin()
		var scene = game.piste_training
		check(scene != null and scene.active and not scene.demo,"Real trainer route starts "+kind)
		if scene == null: continue
		for i in range(200):
			await create_timer(.02).timeout; game._read_bridge(); scene.advance(.02)
			if game.trainer_control.phase == "ACTIVE": break
		check(game.trainer_control.owned and game.trainer_control.state.get("desired_mode") == "SIM","Exercise acquires actual UDP SIM control: "+kind)
		if kind == "flying_start":
			print("VIRTUAL_BRIDGE_STEER")
			for i in range(120):
				await create_timer(.02).timeout; game._read_bridge(); scene.advance(.02)
				if scene.player_lane_target > 0: break
			check(scene.player_lane_target > 0,"Actual simulator paddle controls flying-start lane height")
		menu.exercise_page.finish("Integratietest voltooid")
		for i in range(100):
			await create_timer(.02).timeout; game._read_bridge(); game.trainer_control.tick(false,0,1,game._now_s())
			if game.trainer_control.state.get("release_confirmed",false) and not game.trainer_control.owned and game.trainer_control.pending.is_empty(): break
		check(not scene.active and not game.trainer_control.owned and game.trainer_control.state.get("release_confirmed",false),"Stopping confirms release through actual UDP: "+kind)
		check(menu.exercise_page.selected_activity.kind == kind and menu.exercise_page.selected_activity.get("final",false),"Actual trainer session is saved with the right exercise kind")
	for item in menu.training_store.recent(100): DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(item.id)))
	game.free()
	print("PISTE_EXERCISE_UDP failures=",failures)
	if failures == 0: print("VIRTUAL_BRIDGE_OK")
	quit(0 if failures == 0 else 1)
