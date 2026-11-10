extends SceneTree
const Formation := preload("res://training_peloton.gd")
const Exercise := preload("res://piste_exercise_session.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var leaders := {}
	var previous := Formation.sample(1000,0)
	var session := Exercise.new(); session.start("take_lap",0,30,600)
	var initial_progress := session.progress(Exercise.pack_tail(1000)-3,1000)
	var velocity := 30.0/3.6
	for tick in range(1,1121):
		var time := tick*.05
		var reference := 1000+velocity*time
		var state := Formation.sample(reference,time)
		leaders[state.leader] = true
		check(state.distances.size() == 8 and state.lanes.size() == 8,"All eight riders keep a slot")
		check(state.front-state.tail <= 9.001 and state.front-state.tail > 8,"Group remains compact instead of splitting or becoming a long line")
		var center := 0.0; var minimum := INF; var maximum := -INF
		for i in range(8):
			center += state.distances[i]/8.0
			minimum = minf(minimum,state.lanes[i]); maximum = maxf(maximum,state.lanes[i])
			check(absf(state.distances[i]-previous.distances[i]-velocity*.05) < .026,"Internal speed changes remain small with no attack or teleport")
			check(absf(state.lanes[i]-previous.lanes[i]) < .007,"Riding corridors change continuously")
		check(is_equal_approx(center,Formation.center_distance(reference)),"Bunch centre stays on the prescribed constant tempo")
		check(maximum-minimum > 2.2 and minimum >= 1.179 and maximum <= 3.581,"Formation spreads over two to three riding corridors")
		check(is_equal_approx(session.progress(Exercise.pack_tail(reference)-3,reference),initial_progress),"Lead rotation cannot create relative lap gain")
		previous = state
	check(leaders.size() == 8,"Every rider takes the lead during a full rotation")
	var start := Formation.sample(1000,0)
	var end := Formation.sample(1000,Formation.ROTATION_SECONDS)
	for i in range(8):
		check(is_equal_approx(start.distances[i],end.distances[i]) and is_equal_approx(start.lanes[i],end.lanes[i]),"Rotation closes smoothly at its period boundary")
	print("TRAINING_PELOTON failures=",failures)
	quit(0 if failures == 0 else 1)
