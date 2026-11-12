extends SceneTree
class Game extends "res://main.gd":
	var test_now := 100.0
	func _now_s() -> float: return test_now
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
class Source extends RefCounted:
	var load := {}
	func drive_trainer(_client, enabled, grade, aero, now, target = 0, rate = 10):
		load = {"enabled":enabled,"grade":grade,"aero":aero,"now":now,"target":target,"rate":rate}
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	game.setup_panel.training_store.folder = "user://test_madison_trainer_integration"
	game.setup_panel.show_madison_training(); game.setup_panel.madison_page.begin()
	var scene = game.madison_training_environment
	var source := Source.new()
	game.trainer_control._open()
	game.trainer_control.enabled_before = true
	game.trainer_control.phase = "ACTIVE"
	game.trainer_control.owned = true
	scene.trainer_feedback.recovery_until = 99
	scene.road_grade = 2.0
	scene._drive_trainer(source,true,true,100)
	check(source.load.grade == 2 and source.load.rate == 10,"Normal riding preserves actual route grade")
	scene.madison._impulse = 2; scene.speeds.assign([12.0,10.0])
	scene.madison.released.emit(0,1,.5)
	check(scene.speeds == [11.0,11.0] and not scene.trainer_feedback.event.is_empty(),"Actual release signal applies one impulse and starts output feedback")
	scene._drive_trainer(source,true,true,100.2)
	check(source.load.grade > 10 and scene.road_grade == 2,"Trainer-only uphill offset leaves track grade unchanged")
	check(scene.speeds == [11.0,11.0],"Trainer output never mutates virtual speed")
	scene._drive_trainer(source,true,true,102)
	check(source.load.grade == 2,"Pulse restores current route load")
	game.test_now = 103; scene.speeds.assign([10.0,12.0])
	scene.madison.released.emit(1,0,.5)
	scene._drive_trainer(source,true,true,103.2)
	check(source.load.grade < -6 and scene.speeds == [11.0,11.0],"Player can receive as well as give")
	scene._drive_trainer(source,true,false,103.3)
	check(source.load.grade == 2 and scene.trainer_feedback.event.is_empty(),"Telemetry pause clears force immediately")
	scene._drive_trainer(source,true,true,103.4)
	check(source.load.grade == 2,"Recovery does not replay force")
	game.test_now = 104; scene.madison.released.emit(0,1,.5)
	scene.madison.active = true; scene.madison.phase = scene.madison.Phase.SLING
	scene.madison.cancel("Test interruption")
	check(scene.trainer_feedback.event.is_empty(),"Cancellation clears feedback via production phase signal")
	game.test_now = 105; scene.madison.released.emit(0,1,.5)
	scene.finish_session("Test stop",false)
	check(scene.trainer_feedback.event.is_empty() and game.trainer_control.grade_deadline == INF,"Training stop clears feedback/deadline")
	check(game.trainer_control.pending.get("packet",{}).get("watts",-1) == 0,"Training stop sends trainer Reset")
	var derny = preload("res://derny_environment.gd").new(); derny.game = game
	derny.road_grade = -1.5; derny.reduction = .25
	derny._drive_trainer(source,true,true,106)
	check(source.load.grade == -1.5 and source.load.aero == .75 and source.load.rate == 10,"Other exercise uses original grade, aero and ramp")
	derny.free()
	scene.leave(); game.free()
	print("MADISON_TRAINER_INTEGRATION_OK" if failures == 0 else "MADISON_TRAINER_INTEGRATION_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)
