extends SceneTree
const Feedback := preload("res://madison_trainer_feedback.gd")
const Exchange := preload("res://madison_exchange.gd")
const Session := preload("res://derny_session.gd")
const Trainer := preload("res://trainer_control.gd")
var failures := 0
class Pair extends RefCounted:
	var speeds: Array[float] = [12.0,10.0]
	var baseline_speed := 12.0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var f := Feedback.new()
	f.debug_log = OS.get_environment("MADISON_TRAINER_DEBUG") == "1"
	check(f.grade(0) == 0,"Normal riding has no offset")
	var p := Pair.new(); var m := Exchange.new(); m._impulse = 2
	var exchange := m.apply_release(p,0,1,0.5)
	check(p.speeds == [11.0,11.0],"One equal/opposite release impulse")
	f.start(exchange,10)
	check(f.grade(10) == 0 and f.grade(10.2) > 8,"Giver has a strong positive pulse with smooth onset")
	check(is_equal_approx(f.event.impulse_ns,80) and is_equal_approx(f.event.pair_energy_delta_j,-80),"Momentum and non-conserved energy reported honestly")
	var strong := f.grade(10.2)
	var impulse := 0.0
	for i in range(1600):
		var grade := f.grade(10+i*.001)
		impulse += 9.81*sin(atan(grade/100))*.001
	check(absf(impulse-1.0) < .01,"Unclipped pulse integrates to release delta-v")
	check(absf(f.grade(11.59)) < .01 and f.grade(11.6) == 0,"Smooth decay ends on time")
	check(p.speeds == [11.0,11.0],"Sampling trainer feedback never reapplies speed impulse")
	f.start(exchange,20,1)
	check(f.grade(20.2) < -8,"Receiver gets opposite strong downhill pulse")
	var weak := m.apply_release(Pair.new(),0,1,.1)
	f.start(weak,21)
	check(f.grade(21.2) > 0 and f.grade(21.2) < strong,"Weak exchange produces smaller force")
	check(f.grade(23) == 0,"Repeated exchanges replace rather than stack")
	f.start(exchange,30); f.clear(30.3)
	check(f.grade(30.4) == 0 and f.rate(30.4) == 100,"Cancellation clears pulse and requests prompt recovery")
	check(f.grade(100) == 0,"Old pulse cannot replay after pause")
	var zero := exchange.duplicate(true); zero.delta_mps = 0
	f.start(zero,100); check(f.grade(100.2) == 0,"Missed/zero-efficiency throw has no pulse")
	f.intensity = 10; f.start(exchange,110)
	check(f.event.clipped and f.grade(110.2) <= 20,"Strong force respects protocol limit and reports clipping")
	f.enabled = false
	check(f.grade(110.3) == 0,"Disabling feedback restores normal load")
	check(Session.next_speed(14,100,0,1) < 14,"Insufficient power cannot sustain a received speed boost")
	check(Session.required_power(14,0) > Session.required_power(11,0),"Virtual aerodynamic load increases at new speed")
	# Real UDP packets from the production trainer client; acknowledge mutations.
	var server := PacketPeerUDP.new()
	check(server.bind(0,"127.0.0.1") == OK,"Mock bridge binds loopback")
	var client := Trainer.new(); client.debug_commands = f.debug_log; client.port = server.get_local_port()
	client.enabled_before = true; client.phase = "ACTIVE"; client.owned = true
	client.state = {"desired_mode":"SIM"}; client.last_status = 200; client.last_heartbeat = 200
	client.aero_supported = true
	f.enabled = true; f.intensity = 1; f.start(exchange,200)
	client.grade_rate = f.rate(200.2)
	client.tick(true,f.grade(200.2),1,200.2)
	var command: Dictionary = client.pending.packet
	check(command.command == "set_grade" and command.grade_pct > 8 and command.ramp_pct_per_s == 100,"Effective giver command carries grade and fast bounded ramp")
	client.handle_response({"v":1,"type":"ack","ok":true,"id":command.id,"state":{"desired_mode":"SIM"}},200.21)
	client.tick(true,0,1,202)
	check(client.pending.packet.grade_pct == 0,"Normal grade restored after pulse")
	command = client.pending.packet
	client.handle_response({"v":1,"type":"ack","ok":true,"id":command.id,"state":{"desired_mode":"SIM"}},202.01)
	f.start(exchange,203,1); client.tick(true,f.grade(203.2),1,203.2)
	check(client.pending.packet.grade_pct < -8,"Effective receiver command is downhill")
	client.tick(false,0,1,203.3)
	check(client.pending.packet.command == "set_target_power" and client.pending.packet.watts == 0,"Stop during pending pulse issues Reset")
	client.close(); server.close()
	var expired := Trainer.new(); expired.port = 9
	expired._open(); expired.enabled_before = true; expired.phase = "ACTIVE"; expired.owned = true
	expired.state = {"desired_mode":"SIM"}; expired.grade_deadline = 301.6
	expired.tick(true,15,1,300)
	var pulse_id: String = expired.pending.packet.id
	expired.tick(true,0,1,302)
	check(expired.pending.packet.command == "set_target_power" and expired.pending.packet.watts == 0,"Expired unacknowledged pulse is Reset instead of retried")
	expired.handle_response({"v":1,"type":"ack","ok":true,"id":pulse_id,"state":{"desired_mode":"SIM"}},302.01)
	check(not expired.owned and not expired.armed,"Late pulse ACK cannot restore trainer ownership")
	expired.close()
	print("MADISON_TRAINER_FEEDBACK_OK" if failures == 0 else "MADISON_TRAINER_FEEDBACK_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)
