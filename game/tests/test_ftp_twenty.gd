extends SceneTree
const Ramp = preload("res://ftp_ramp.gd")
const Twenty = preload("res://ftp_twenty_min.gd")
class ClockTraining extends "res://ftp_training.gd":
	var clock := 0.0
	func now_s() -> float: return clock
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func packet(id: int, power: float = 200., age: float = 0.) -> Dictionary:
	return {"type":"telemetry", "valid":true, "power_sample_id":id, "power_age_s":age, "power_w":power, "gear":6, "cadence_rpm":90., "speed_kmh":35.}
func run() -> void:
	var model = Twenty.new()
	model.start(0.)
	model.tick(2.)
	check(not model.running() and not model.complete(),"No first measurement times out")
	model.start(0.)
	model.sample(0.,200.)
	model.sample(0.,999.)
	for i in range(1,1201): model.sample(float(i),200. if i < 600 else 300.)
	check(model.complete() and is_equal_approx(model.average_power(),250.),"Time-weighted average ignores duplicates and includes all twenty minutes")
	check(is_equal_approx(model.ftp(),237.5),"Only 95 percent of the measured mean becomes FTP")
	model.start(0.); model.sample(0.,0.)
	for i in range(1,1201): model.sample(float(i),0.)
	check(model.complete() and model.ftp() == 0.,"Zero watts are valid measurements")
	model.start(0.); model.sample(0.,200.); model.sample(2.,200.)
	check(not model.complete() and model.ftp() == 0.,"A measurement gap invalidates the result")
	var page = ClockTraining.new(); root.add_child(page); page.set_process(false)
	page.player_profile.path = "user://config/test_ftp_twenty_profile.cfg"
	page.player_profile.set_ftp(210.,"test")
	page.select_test(true)
	page.receive(packet(0),0.)
	page.begin()
	check(page.test.running() and not page.trainer.owned and not page.trainer.socket.is_bound(),"Twenty minute test starts without claiming ERG")
	for i in range(1,1201):
		page.clock = float(i)
		page.receive(packet(i),page.clock)
	page._refresh()
	check(page.test.complete() and page.player_profile.ftp() == 190,"Completed test persists measured FTP")
	var cfg := ConfigFile.new(); cfg.load(page.player_profile.path)
	check(cfg.get_value("rider","ftp_source") == "twenty_minute_test","Profile records the twenty-minute source")
	page.begin(); page.clock += 2.; page._process(2.)
	check(not page.test.complete() and page.player_profile.ftp() == 190,"Signal loss preserves the existing FTP")
	page.clock += 1.; page.receive(packet(1201),page.clock); page.begin()
	page.finish("Handmatig gestopt")
	check(page.player_profile.ftp() == 190 and not page.test.complete(),"Manual stop cannot overwrite FTP")
	page.receive(packet(1202,200.,5.),page.clock)
	page.begin()
	check(not page.test.running(),"Stale telemetry cannot start a test")
	page.select_test(false)
	check(page.test is Ramp and page.title.text == "FTP Ramp Test","Ramp remains independently selectable")
	page.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://config/test_ftp_twenty_profile.cfg"))
	print("FTP_TWENTY failures=",failures)
	quit(0 if failures == 0 else 1)
