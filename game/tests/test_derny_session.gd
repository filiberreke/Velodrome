extends SceneTree
const Session := preload("res://derny_session.gd")
var failures := 0
var changes: Array[int] = []
var signals: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var session := Session.new()
	session.speed_changed.connect(func(kmh): changes.append(kmh))
	session.gesture_requested.connect(func(action): signals.append(action))
	session.start(100)
	check(session.phase == "RUNUP" and session.derny_distance == 103, "Starts behind derny with an approach lap")
	for i in range(10000):
		session.advance(.01, 1.0, session.derny_distance - 3, 1.0)
		if session.phase == "PACE": break
	check(session.runup_distance >= 250 and changes == [30], "Full physical lap precedes 30 km/h announcement")
	for i in range(6000): session.advance(.01, 1.0, session.derny_distance - 3, 1.0)
	check(is_equal_approx(session.target_kmh, 31) and session.completed_kmh == 30, "Minute one completes 30 and raises speed to 31")
	check(changes == [30,31], "One central speed event per new step")
	check(signals.count("speed_up") == 2, "One thumbs-up for start and one for first increase")
	var sheltered := Session.draft_reduction(3, 0)
	check(is_equal_approx(sheltered, .60), "Derny shelter is capped at 60 percent")
	check(Session.draft_reduction(-2, 0) == 0 and Session.draft_reduction(3, 1.1) == 0, "Passing and riding beside derny remove shelter")
	check(Session.draft_reduction(10, 0) < sheltered, "Wake fades with distance")
	check(Session.next_speed(12, 150, sheltered, .1) > Session.next_speed(12, 150, 0, .1), "Wake affects force-based speed")
	for i in range(400): session.advance(.01, 1, session.derny_distance - 20, 1)
	check(session.running(), "Brief gap does not end training")
	session.advance(.01, 1, session.derny_distance - 3, 1)
	check(session.loss_seconds == 0, "Rejoining resets loss timer")
	for i in range(501): session.advance(.01, 1, session.derny_distance - 20, 1)
	check(session.phase == "RESULT" and session.reason == "Aansluiting verloren", "Sustained gap ends session")
	session.start(0)
	signals.clear()
	for i in range(1600): session.advance(.01, 1, session.derny_distance - 3, 1)
	var close_count := signals.count("look_back")
	session.look_cooldown = 0
	for i in range(1600): session.advance(.01, 1, session.derny_distance - 7, 1)
	check(signals.count("look_back") - close_count > close_count, "Pilot checks behind more frequently at larger gap")
	check(not signals.has("slow_down"), "No slowing hand in increasing-speed training")
	changes.clear()
	session.start(0,35)
	for i in range(10000):
		session.advance(.01,1,session.derny_distance-3,1)
		if session.phase == "PACE": break
	check(changes == [35] and session.target_kmh == 35,"Chosen start speed follows approach lap")
	for i in range(6000): session.advance(.01,1,session.derny_distance-3,1)
	check(changes == [35,36] and session.completed_kmh == 35,"Minute steps and result use chosen starting speed")
	session.start(0,10)
	check(session.target_kmh < 10,"Low chosen speeds still have a gradual approach")
	check(Session.lane_at_speed(30,30) == 1.18 and Session.lane_at_speed(34.9,30) == 1.18,"Pilot begins on lowest line")
	check(is_equal_approx(Session.lane_at_speed(35,30),1.78) and is_equal_approx(Session.lane_at_speed(40,30),2.38),"Every extra 5 km/h raises one riding corridor")
	check(Session.lane_at_speed(100,30) == 3.55,"Pilot never moves above blue line")
	session.phase = "PACE"
	session.target_kmh = 30
	session.step_elapsed = 45
	session.change_tempo(1)
	check(session.target_kmh == 31 and session.step_elapsed == 0 and signals[-1] == "speed_up","Manual increase changes one km/h and resets countdown")
	session.change_tempo(-1)
	check(session.target_kmh == 30 and signals[-1] == "slow_down","Manual decrease signals the slowing hand")
	print("DERNY_SESSION failures=", failures)
	quit(0 if failures == 0 else 1)
