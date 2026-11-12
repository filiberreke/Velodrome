extends SceneTree
class Track extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _save_recording(_reason: String) -> void: pass
const Motor := preload("res://derny_motor.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var track := Track.new()
	root.add_child(track)
	for case in [[10.0,1.18],[30.0,1.18],[30.0,3.55],[60.0,3.55]]:
		var target: float = case[0]
		var lane: float = case[1]
		var motor := Motor.new()
		var began := Time.get_ticks_msec()
		motor.configure(track,target,lane)
		print("MOTOR_CALIBRATION lane=",lane," ms=",Time.get_ticks_msec()-began," power=",motor.power_w)
		motor.speed_mps = target/3.6
		var power := motor.power_w
		var distance := 0.0
		var elapsed := 0.0
		var physical := 0.0
		var lap := 0
		var last_time := 0.0
		var last_physical := 0.0
		var minimum := INF
		var maximum := 0.0
		var slowed_uphill := false
		var sped_downhill := false
		for i in range(70000):
			var speed := motor.speed_mps
			var before := track._at(distance,lane)
			motor.advance_speed(track,distance,lane,lane,1.0/120)
			distance += motor.speed_mps/120/track._path_metric(distance,lane)
			elapsed += 1.0/120
			physical += motor.speed_mps/120
			var after := track._at(distance,lane)
			if lap >= 2:
				minimum = minf(minimum,motor.speed_mps*3.6)
				maximum = maxf(maximum,motor.speed_mps*3.6)
				if after.y-before.y > .0001 and motor.speed_mps < speed: slowed_uphill = true
				if after.y-before.y < -.0001 and motor.speed_mps > speed: sped_downhill = true
			if int(distance/250) > lap:
				lap += 1
				var mean := (physical-last_physical)/(elapsed-last_time)*3.6
				if lap >= 3: check(absf(mean-target) < .3,"Fixed-power motor matches chosen mean: lane %s mean %s" % [lane,mean])
				last_time = elapsed; last_physical = physical
				if lap == 4: break
		check(lap == 4,"Full four-lap pacing measurement completes")
		check(is_equal_approx(motor.power_w,power),"Drive watts stay fixed through every bend")
		check(slowed_uphill and sped_downhill and maximum-minimum > .1,"Pacer genuinely slows uphill and accelerates downhill at fixed watts")
		print("MOTOR_SPEEDS lane=",lane," min=",minimum," max=",maximum)
	track.free()
	print("DERNY_MOTOR failures=",failures)
	quit(0 if failures == 0 else 1)
