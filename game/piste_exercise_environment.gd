extends "res://derny_environment.gd"
const Exercise := preload("res://piste_exercise_session.gd")
const Pacers := preload("res://free_training_pacers.gd")
var pacers := Pacers.new()
var pacer_bikes: Array[Node3D] = []
const Formation := preload("res://training_peloton.gd")
var pack_distance := 0.0 # Fixed lap-progress reference; pack_state holds the visible bounds.
var pack_lane := Formation.CENTER_LANE
var pack_state := {}
var pack_markers: Node3D
var pack_bikes: Array[Node3D] = []
var line_marker: Label3D
var last_power_sample_id := -1
func _setup_session() -> void:
	name = "PisteExerciseEnvironment"
	page = game.setup_panel.exercise_page; session = page.session; page.scene = self
	store = game.setup_panel.training_store
	popup = preload("res://race_popup.gd").new(); game.setup_panel.add_child(popup)
	hud = preload("res://piste_exercise_hud.gd").new(); game.setup_panel.add_child(hud)
	hud.stop_button.pressed.connect(func(): finish_session("Handmatig gestopt"))
	hud.leave_button.pressed.connect(page.leave); hud.hide()
	pack_markers = preload("res://peloton_markers.gd").new(); add_child(pack_markers)
	line_marker = Label3D.new(); line_marker.text = "START · ACHTERVOLGINGSLIJN"; line_marker.font_size = 48; line_marker.pixel_size = .008; line_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(line_marker)
func enter() -> void:
	if active: leave()
	saved_camera = {"transform":game.camera.transform,"fov":game.camera.fov}
	demo = not game.trainer_seen; demo_power = 180; control_started = game._now_s()
	player_lane_offset = LOWEST_LANE if page.kind != "take_lap" else pack_lane
	player_lane_target = game.LANES.find(player_lane_offset)
	reduction = 0; road_grade = 0; total_elapsed = 0; total_distance = 0; assisted_seconds = 0
	samples = []; last_sample = -1; last_save = 0; saved_final = false; too_close = false
	var line := Exercise.pursuit_line(game)
	pack_distance = line
	start_distance = 0.0 if page.kind == "free_ride" else line if page.kind == "flying_start" else Exercise.pack_tail(pack_distance)-Exercise.FOLLOW_GAP
	player_speed = 0.0 if page.kind == "free_ride" else Exercise.START_KMH/3.6 if page.kind == "flying_start" else page.tempo_input.value/3.6
	session.start(page.kind,start_distance,page.tempo_input.value,0 if page.kind == "free_ride" else page.limit_input.value*60 if page.kind == "take_lap" else 600)
	if page.kind == "free_ride":
		var rng := RandomNumberGenerator.new(); rng.randomize(); pacers.reset(rng,start_distance)
	_update_pack_state()
	reduction = _draft_at(start_distance)
	last_power_sample_id = game.setup_panel.ftp_page.sample_id
	session.peak_w = demo_power if demo else game.setup_panel.ftp_page.measured
	var stamp := Time.get_datetime_string_from_system().replace(":","-")
	activity = {"version":1,"id":stamp+"-%08x" % randi(),"kind":page.kind,"title":Exercise.title(page.kind),"started_unix":int(Time.get_unix_time_from_system()),"started_local":Time.get_datetime_string_from_system(false,true),"demo":demo,"initial_speed_kmh":player_speed*3.6,"line_distance":start_distance if page.kind == "free_ride" else line}
	line_marker.position = game._at(line,8.8)+Vector3.UP*1.5; line_marker.visible = page.kind == "flying_start"
	if page.kind == "take_lap" and pack_bikes.is_empty(): _build_pack()
	for bike in pack_bikes: bike.visible = page.kind == "take_lap"
	if page.kind == "free_ride" and pacer_bikes.is_empty(): _build_pacers()
	for bike in pacer_bikes: bike.visible = page.kind == "free_ride"
	if not demo:
		game.setup_panel.ftp_page.reset_session(game._now_s(),game.trainer_control)
		game.trainer_control.arm()
	_enter_training_venue()
	page.selected_activity = {}
	_capture_sample(); _persist(false); hud.show(); _present(0)
func receive_power_sample(now: float) -> void:
	var source = game.setup_panel.ftp_page
	if demo or not active or not session.running() or not source.fresh(now): return
	if source.sample_id == last_power_sample_id: return
	last_power_sample_id = source.sample_id
	# Preserve short measured peaks even if multiple UDP samples arrive in one frame.
	session.peak_w = maxf(session.peak_w,source.measured)
func _build_pack() -> void:
	for i in range(Exercise.PACK_COUNT):
		var bike := Node3D.new(); bike.name = "TrainingPeloton%d" % i; add_child(bike)
		var rider := preload("res://rider_visual.gd").new(); rider.set_meta("rider_index",1+i%3); rider.set_meta("country_kit",["netherlands","france","belgium","germany"][i%4]); bike.add_child(rider)
		pack_bikes.append(bike)
func _build_pacers() -> void:
	for i in range(4):
		var bike := Node3D.new(); bike.name = Pacers.rider_name(i); add_child(bike)
		var rider := preload("res://rider_visual.gd").new(); rider.set_meta("rider_index",1+i%3); bike.add_child(rider)
		rider.set_training_colour(Pacers.COLOURS[i])
		var tag := Label3D.new(); tag.text = Pacers.rider_name(i); tag.position.y = 2.6; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag.font_size = 42; tag.pixel_size = .005; tag.outline_size = 10; tag.modulate = Pacers.COLOURS[i].lightened(.2); tag.no_depth_test = true; tag.layers = 2; bike.add_child(tag)
		pacer_bikes.append(bike)
func steer(direction: int) -> void:
	if session.running(): player_lane_target = clampi(player_lane_target+direction,0,game.LANES.size()-1)
func request_tempo(direction: int) -> void: steer(direction)
func _update_pack_state() -> void:
	pack_state = Formation.sample(pack_distance,session.elapsed) if session.kind == "take_lap" else {"distances":pacers.distances,"lanes":pacers.lanes} if session.kind == "free_ride" else {}
func _draft_at(player: float) -> float:
	if pack_state.is_empty(): return 0
	var best := 0.0
	for i in range(pack_state.distances.size()):
		var lateral: float = absf(player_lane_offset-float(pack_state.lanes[i]))
		if lateral >= 1: continue
		var gap: float = fposmod(float(pack_state.distances[i])-player,Exercise.LAP)*game._path_metric(player,player_lane_offset)
		if gap > 1.5 and gap < 14:
			best = maxf(best,.5*minf(1,(14-gap)/10)*pow(1-lateral,2))
	return best
func _step(dt: float, power: float) -> void:
	var before := distance; var old_speed := player_speed; var old_lane := player_lane_offset; var pack_before := pack_distance
	var previous: Vector3 = game._at(before,old_lane)
	player_lane_offset = move_toward(player_lane_offset,float(game.LANES[player_lane_target]),game.LANE_CHANGE_MPS*dt)
	reduction = _draft_at(before)
	player_speed = Session.next_speed(player_speed,power,reduction,dt)
	var next: Vector3 = game._at(before+player_speed*dt/game._path_metric(before,player_lane_offset),player_lane_offset)
	var side: Vector3 = game._at(before,player_lane_offset)
	player_speed = game._banked_speed(player_speed,next.y-side.y,side.y-previous.y,absf(player_lane_offset-old_lane),dt,power)
	distance += player_speed*dt/game._path_metric(before,player_lane_offset)
	too_close = false
	if session.kind == "take_lap":
		# Pace the bunch centre, not one changing leader. Riders are non-solid,
		# exactly as in scratch: the human is never capped behind another bike.
		pack_distance += session.target_kmh/3.6*dt/game._path_metric(Formation.center_distance(pack_distance),pack_lane)
	if session.kind == "free_ride": pacers.advance(game,dt)
	session.observe(dt,before,distance,old_speed,player_speed,power,pack_before,pack_distance)
	var fraction: float = session.last_fraction
	distance = lerpf(before,distance,fraction); player_lane_offset = lerpf(old_lane,player_lane_offset,fraction)
	pack_distance = lerpf(pack_before,pack_distance,fraction); player_speed = lerpf(old_speed,player_speed,fraction)
	var current: Vector3 = game._at(distance,player_lane_offset)
	road_grade = lerpf(road_grade,game.TrainerControl.route_grade(previous,current),1-exp(-8*dt*fraction))
	_update_pack_state()
	reduction = _draft_at(distance)
	total_elapsed = session.elapsed
	total_distance += maxf(0,distance-before)*game._path_metric(distance,player_lane_offset)
func _place(bike: Node3D, at: float, lane: float, dt: float, power: float, cadence: float) -> void:
	var point: Vector3 = game._at(at,lane); var forward: Vector3 = game._direction(at,lane)
	bike.position = point+Vector3.UP*.1
	bike.rotation = Vector3(0,atan2(forward.x,forward.z),-game._bank_angle(game._track_s(at)))
	bike.get_child(0).call("set_victory",false); bike.get_child(0).call("pedal",dt,cadence,power)
func _present(dt: float) -> void:
	_place(game.bikes[0],distance,player_lane_offset,dt,demo_power if demo else game.setup_panel.ftp_page.measured,85 if demo else maxf(0,game.cadence))
	if session.kind == "take_lap":
		for i in range(pack_bikes.size()): _place(pack_bikes[i],float(pack_state.distances[i]),float(pack_state.lanes[i]),dt,180,85)
		# Scratch's marker renderer expects front-wheel progress, whereas our
		# training poses use bike roots. Convert once so the strips align.
		pack_markers.update_bunch(game,{"front":float(pack_state.front)+game.FRONT_WHEEL_TIP_M,"tail":float(pack_state.tail)+game.FRONT_WHEEL_TIP_M},true)
	else: pack_markers.update_bunch(game,{},false)
	if session.kind == "free_ride":
		for i in range(4): _place(pacer_bikes[i],pacers.distances[i],pacers.lanes[i],dt,180+i*70,85)
	game.visual_rolls[0] = game.bikes[0].rotation.z
	game._follow_rider_camera(distance,player_lane_offset,dt,false,game.bikes[0].position)
	game.bikes[0].visible = game.look_back_held or game.camera_mode != 2
	hud.update_training(self)
func _capture_sample() -> void:
	if not demo and not game.setup_panel.ftp_page.fresh(game._now_s()): return
	if not samples.is_empty() and total_elapsed <= float(samples[-1].time_s): return
	samples.append({"time_s":total_elapsed,"distance_m":total_distance,"game_speed_kmh":player_speed*3.6,"power_w":demo_power if demo else game.setup_panel.ftp_page.measured,"heart_rate_bpm":null if demo else game.trainer_heart_rate_bpm,"cadence_rpm":-1 if demo else game.cadence,"draft_pct":reduction*100,"lane_m":player_lane_offset,"height_m":game._at(distance,player_lane_offset).y,"gained_m":session.gained_m,"assisted":false,"power_held":not demo and not game.setup_panel.ftp_page.live(game._now_s())})
	last_sample = total_elapsed; hud.graph.set_samples(samples)
func _persist(final: bool) -> void:
	if activity.is_empty(): return
	activity.merge(session.result(),true)
	activity.merge({"samples":samples,"duration_s":total_elapsed,"distance_m":total_distance,"assisted_seconds":0,"reason":session.reason,"final":final},true)
	var saved_ok: bool = store.save(activity)
	save_status = "Training opgeslagen in het spel." if saved_ok else "Opslaan mislukt: "+store.error
	if saved_ok:
		last_save = total_elapsed
		if final: saved_final = true
func finish_session(reason: String, show_result: bool = true) -> void:
	session.stop(reason); _capture_sample(); _persist(true); release_trainer(); hud.hide(); popup.clear()
	page.show_activity(activity,save_status)
	if show_result:
		game.setup_panel._exercise_environment(false)
		game.setup_panel.show_piste_exercise(session.kind, false)
