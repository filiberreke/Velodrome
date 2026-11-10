extends SceneTree
class Game extends "res://main.gd":
	var test_port := 0
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(test_port)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	var game := Game.new()
	game.test_port = int(args[0])
	game.trainer_control.port = int(args[1])
	root.add_child(game)
	game.set_physics_process(false)
	var menu = game.setup_panel
	menu.training_store.folder = "user://test_derny_virtual_bridge"
	for i in range(150):
		await create_timer(.02).timeout
		game._read_bridge()
		if menu.ftp_page.fresh(game._now_s()): break
	check(menu.ftp_page.fresh(game._now_s()) and menu.ftp_page.measured == 0, "Actual virtual bridge supplies fresh stationary zero-watt power")
	check(game._piste_start_blocker().is_empty(), "Released simulator does not block start")
	menu.show_derny()
	menu.derny_page.begin()
	check(menu.derny_page.session.running() and game.piste_training != null, "Derny starts at 0 W from RELEASED")
	if game.piste_training != null:
		for i in range(180):
			await create_timer(.02).timeout
			game._read_bridge()
			game.piste_training.advance(.02)
			if game.trainer_control.phase == "ACTIVE": break
		check(game.trainer_control.phase == "ACTIVE" and game.trainer_control.owned, "Real UDP handshake reactivates released simulator into SIM")
		check(menu.derny_page.session.running(), "Stationary zero-power readings remain fresh during assisted approach")
		game.piste_training.session.phase = "PACE"
		for virtual in [true,false]:
			game.trainer_virtual = virtual
			for button in ["RIGHT","LEFT"]:
				game._process_bridge_packet({"type":"controller_button","source_button":button,"pressed":true,"mapped_action":""})
				check(game.piste_training.hud.call_label.text == ("ALLEZ" if button == "RIGHT" else "HOW"),"Physical direction requests tempo for simulator and real trainer")
				game._process_bridge_packet({"type":"controller_button","source_button":button,"pressed":false})
				game.piste_training.tempo_requests.clear()
		menu.derny_page.finish("Integratietest voltooid")
		for i in range(60):
			await create_timer(.02).timeout
			game._read_bridge()
			game.trainer_control.tick(false,0,1,game._now_s())
			if game.trainer_control.phase == "IDLE": break
		check(not game.trainer_control.owned, "Stopping releases training control")
	# Keep rejecting an outdated bridge instead of treating sample_id as real power proof.
	game._process_bridge_packet({"type":"telemetry","valid":true,"power_w":0,"sample_id":99999})
	check(game._piste_start_blocker().contains("Werk de bridge bij"), "Old protocol receives an accurate update message")
	menu.ftp_page.receive({"type":"telemetry","valid":true,"power_w":0,"power_sample_id":99999,"power_age_s":0},game._now_s())
	game.trainer_control.phase = "RELEASING"
	check(game._piste_start_blocker().contains("trainerbediening"), "Actual release wait has a distinct message")
	game.trainer_control.phase = "IDLE"
	menu.ftp_page.telemetry_ok = false
	check(game._piste_start_blocker().contains("Geen verse"), "Missing measurements are distinguished from release")
	for activity in menu.training_store.recent(100):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store.folder.path_join(str(activity.id)+".json")))
	game.free()
	print("DERNY_VIRTUAL_BRIDGE failures=",failures)
	if failures == 0: print("VIRTUAL_BRIDGE_OK")
	quit(0 if failures == 0 else 1)
