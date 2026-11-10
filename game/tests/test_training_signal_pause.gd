extends SceneTree
const Tracker := preload("res://trainer_signal.gd")
class FakeTrainer extends "res://trainer_control.gd":
	func tick(enabled: bool,_grade: float,_aero: float,now: float,target: int = 0) -> void:
		if enabled_before and not enabled: armed = false; may_resume = true
		enabled_before = enabled; owned = enabled; last_response = now; phase = "ACTIVE" if enabled else "IDLE"
		state = {"mode":"ERG" if enabled and target > 0 else "SIM" if enabled else "RELEASED","desired_mode":"ERG" if target > 0 else "SIM","confirmed_target_w":target,"revision":1,"applied_revision":1,"udp_owned":enabled,"release_confirmed":not enabled}
class FTP extends "res://ftp_training.gd":
	var clock := 100.0
	func now_s() -> float: return clock
class Workout extends "res://workout_training.gd":
	var clock := 100.0
	func now_s() -> float: return clock
class Game extends "res://main.gd":
	var signal_clock := -1.0
	func _now_s() -> float: return signal_clock if signal_clock >= 0 else super._now_s()
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func packet(id: int, valid: bool = true, age: float = 0) -> Dictionary:
	return {"type":"telemetry","valid":valid,"power_w":175.0,"speed_kmh":25.0,"cadence_rpm":85.0,"power_sample_id":id,"sample_id":id,"power_age_s":age}
func feed(page,id: int,ok: bool = true,age: float = 0) -> void: page.receive(packet(id,ok,age),page.clock)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var signal_state := Tracker.new(); signal_state.receive(true,100); signal_state.reset_clock(100)
	signal_state.receive(false,101.1)
	check(signal_state.usable(110) and not signal_state.live(110),"Same race settings retain the last power through a short outage")
	check(not signal_state.usable(111.2) and is_equal_approx(signal_state.time(150),111.1),"After ten seconds the session clock pauses instead of ending")
	signal_state.receive(true,200)
	check(signal_state.live(200) and is_equal_approx(signal_state.time(200),111.1),"Recovery resumes from exactly the frozen training clock")
	var ftp := FTP.new(); ftp.trainer = FakeTrainer.new(); root.add_child(ftp); ftp.set_process(false)
	feed(ftp,1); ftp.begin(); ftp.test.phase = "RAMP"; ftp.test.ramp_at = 100
	ftp.clock = 102; feed(ftp,2); ftp._process(.1)
	check(ftp.test.running(),"Two-second real-trainer power updates do not stop the FTP test")
	ftp.clock = 103.1; feed(ftp,2,false,1.1); ftp._process(.1)
	check(ftp.last_speed_kmh == 25,"ERG venue retains the last trainer speed during the ten-second hold")
	ftp.clock = 114; ftp._process(.1)
	check(ftp.test.running() and ftp.signal_state.paused_since >= 0 and not ftp.trainer.owned,"FTP pauses and releases resistance after the race hold window")
	var paused_clock: float = ftp.session_now(ftp.clock)
	ftp.clock = 130; feed(ftp,3); ftp._process(.1)
	check(ftp.test.phase == "RAMP" and ftp.trainer.owned and is_equal_approx(ftp.session_now(130),paused_clock),"FTP recovers within one minute without consuming paused ramp time")
	check(ftp.test.segments.is_empty(),"No paused interval is fabricated as measured FTP power")
	ftp.finish("Test stop"); ftp.free()
	var source := FTP.new(); source.trainer = FakeTrainer.new(); root.add_child(source); source.set_process(false)
	feed(source,1); source.trainer.arm(); source.reset_session(100,source.trainer)
	source.clock = 101.1; feed(source,1,false,1.1); source.drive_trainer(source.trainer,true,0,1,source.clock,100)
	source.clock = 102; feed(source,2); source.drive_trainer(source.trainer,true,0,1,source.clock,100)
	check(source.trainer.allow_released_session,"A startup hiccup preserves the user's explicit permission to start a released trainer")
	source.finish("Test stop"); source.free()
	ftp = FTP.new(); ftp.trainer = FakeTrainer.new(); root.add_child(ftp); ftp.set_process(false)
	feed(ftp,1); ftp.begin(); ftp.clock = 101; feed(ftp,1,false,1)
	ftp.clock = 170.9; ftp._process(.1)
	check(ftp.test.running(),"FTP may remain paused for just under one minute after the ten-second hold")
	ftp.clock = 171.1; ftp._process(.1)
	check(not ftp.test.running() and ftp.test.reason.contains("1 minuut"),"Only FTP ends when its actual pause exceeds one minute")
	ftp.free()
	var workout := Workout.new(); workout.trainer = FakeTrainer.new(); root.add_child(workout); workout.set_process(false)
	workout.load_workout({"id":"pause","name":"Pause test","blocks":[{"kind":"SteadyState","duration":600,"power_low":.7,"power_high":.7,"events":[]}]})
	feed(workout,1); workout.begin(); workout.clock = 101; feed(workout,2); workout._process(1)
	workout.clock = 102; feed(workout,2,false,1); workout._process(1)
	workout.clock = 113; workout._process(.25)
	var paused_elapsed: float = workout.test.elapsed
	workout.clock = 300; workout._process(1)
	check(workout.test.running() and workout.test.elapsed == paused_elapsed and not workout.trainer.owned,"Ordinary ERG workout remains paused indefinitely, keeping progress")
	workout.clock = 301; feed(workout,3); workout._process(.25)
	workout.clock = 301.25; feed(workout,4); workout._process(.25)
	check(workout.test.running() and workout.test.elapsed > paused_elapsed and workout.trainer.owned,"ERG automatically resumes its prior workout on recovery")
	workout.finish("Test stop"); workout.free()
	var game := Game.new(); root.add_child(game); game.set_physics_process(false); game.trainer_control = FakeTrainer.new()
	var menu = game.setup_panel; menu.ftp_page.set_process(false); menu.workout_play_page.set_process(false)
	menu.training_store.folder = "user://test_training_pause"
	for index in range(2):
		var base := 1000.0+index*200
		game.signal_clock = base; game._process_bridge_packet(packet(10+index*10))
		if index == 0: menu.show_piste_exercise("free_ride"); menu.exercise_page.begin()
		else: menu.show_derny(); menu.derny_page.begin()
		var scene = game.piste_training
		for tick in range(1,45):
			game.signal_clock = base+tick*.25
			game._process_bridge_packet(packet(10+index*10,false,tick*.25))
			scene.advance(.25)
		var at: float = scene.distance; var elapsed: float = scene.total_elapsed
		game.signal_clock = base+80; scene.advance(.25)
		check(scene.active and scene.session.running() and scene.distance == at and scene.total_elapsed == elapsed,"Piste training pauses indefinitely without losing session or lap progress")
		check(scene.hud.status_panel.visible and scene.hud.phase_label.text.contains("gepauzeerd"),"Paused piste training clearly shows the connection state")
		game.signal_clock = base+81; game._process_bridge_packet(packet(index+1)); scene.advance(.25)
		check(scene.active and scene.total_elapsed > elapsed and scene.distance > at and game.trainer_control.owned,"Piste exercise and derny both resume automatically with fresh trainer data")
		scene.page.finish("Test stop"); scene.page.leave()
	for item in menu.training_store.recent(100): DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(item.id)))
	game.free()
	print("TRAINING_SIGNAL_PAUSE failures=",failures)
	quit(0 if failures == 0 else 1)
