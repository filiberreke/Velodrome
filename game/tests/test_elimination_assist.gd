extends SceneTree
const Assist = preload("res://elimination_assist.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var a = Assist.new()
	var d: Array[float] = [100.0, 102.3, 90.0]
	var v: Array[float] = [10.0, 10.0, 10.0]
	var l: Array[float] = [1.18, 1.18, 4.78]
	var done: Array[float] = [-1.0, -1.0, -1.0]
	var requests: Array[float] = l.duplicate()
	var choices := [1.18, 2.38, 3.58, 4.78, 5.98, 7.18]
	check(not a.enabled, "Assist defaults off")
	a.observe(10.0, 1.0, 1.0, 0.1)
	check(a.notice(10.0).is_empty(), "Drafting without a speed clamp is not a blockage")
	a.observe(10.0, 1.0, 0.8, 0.1)
	check(a.notice(10.0).contains("GEBLOKKEERD"), "Real clamp warns while assist is off")
	check(a.lane(10.0,d,v,l,done,requests,choices,1.8) < 0.0, "Disabled assist never steers")
	a.enabled = true
	check(is_equal_approx(a.lane(10.0,d,v,l,done,requests,choices,1.8),2.38), "Open adjacent lane permits passing")
	a.manual(10.1)
	check(a.target < 0.0, "Manual input cancels the automatic manoeuvre immediately")
	a.observe(11.0,1.0,0.8,0.1)
	check(a.lane(12.09,d,v,l,done,requests,choices,1.8) < 0.0, "No automatic steering within two seconds")
	a.observe(12.11,1.0,0.8,0.1)
	check(a.lane(12.11,d,v,l,done,requests,choices,1.8) > 0.0, "Assist resumes after the pause")
	a.target = -1.0
	l[2] = 2.38; requests[2] = 2.38; d[2] = 96.0; v[2] = 18.0
	check(a.lane(12.12,d,v,l,done,requests,choices,1.8) < 0.0, "Fast rear traffic blocks the merge")
	check(a.notice(12.12).contains("GEBLOKKEERD"), "No safe lane retains the warning")
	d[2] = 100.0; v[2] = 10.0
	check(a.lane(12.12,d,v,l,done,requests,choices,1.8) < 0.0, "Occupied destination blocks the merge")
	d[2] = 100.0; l[2] = 3.58; requests[2] = 1.18
	check(a.lane(12.12,d,v,l,done,requests,choices,1.8) < 0.0, "Conflicting AI lane request blocks the swept path")
	done[2] = 5.0
	check(a.lane(12.12,d,v,l,done,requests,choices,1.8) > 0.0, "Eliminated rider is excluded")
	done[2] = -1.0; l[2] = 2.38; requests[2] = 2.38
	check(is_equal_approx(a.lane(12.13,d,v,l,done,requests,choices,1.8),l[0]), "New hazard stops an in-progress automatic merge")
	a.reset()
	check(not a.enabled and a.target < 0.0 and a.notice(0.0).is_empty(), "Reset clears option, target, warning and timers")
	print("ELIMINATION_ASSIST failures=", failures)
	quit(0 if failures == 0 else 1)
