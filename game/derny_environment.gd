extends "res://training_environment.gd"
## Isolated piste exercise: shares the empty training venue, never race state.
const Session := preload("res://derny_session.gd")
const Motor := preload("res://derny_motor.gd")
var motor := Motor.new()
const Visual := preload("res://derny_visual.gd")
const LOWEST_LANE := 1.18
const BLUE_LINE := 3.55
const LANE_RISE_MPS := .20
var derny_lane_offset := LOWEST_LANE
var page
var session
var pilot: Node3D
var popup: Label
var player_speed := 20.0 / 3.6
var player_lane_offset := LOWEST_LANE
var player_lane_target := 0
var reduction := 0.0
var road_grade := 0.0
var demo := false
var demo_power := 130.0
var control_started := -1.0
var saved_camera := {}
var hud: Control
var store
var activity := {}
var samples: Array[Dictionary] = []
var total_elapsed := 0.0
var total_distance := 0.0
var assisted_seconds := 0.0
var last_sample := -1.0
var last_save := 0.0
var saved_final := false
var too_close := false
var save_status := ""
const FOLLOW_GAP := 2.8
const PASS_LATERAL := 1.1
func _ready() -> void:
	super._ready()
	name = "DernyTrainingEnvironment"
	page = game.setup_panel.derny_page
	session = page.session
	page.scene = self
	store = game.setup_panel.training_store
	pilot = Visual.new()
	pilot.name = "DernyPilot"
	add_child(pilot)
	popup = preload("res://race_popup.gd").new()
	game.setup_panel.add_child(popup)
	session.speed_changed.connect(_speed_changed)
	session.gesture_requested.connect(pilot.gesture)
	hud = preload("res://derny_hud.gd").new()
	game.setup_panel.add_child(hud)
	hud.stop_button.pressed.connect(func(): finish_session("Handmatig gestopt"))
	hud.leave_button.pressed.connect(page.leave)
	hud.hide()
func enter() -> void:
	if active: leave()
	saved_camera = {"transform": game.camera.transform, "fov":game.camera.fov}
	demo = not game.trainer_seen
	demo_power = 130.0
	player_speed = 20.0 / 3.6
	derny_lane_offset = LOWEST_LANE
	player_lane_offset = LOWEST_LANE
	player_lane_target = 0
	reduction = 0.0
	road_grade = 0.0
	control_started = game._now_s()
	samples = []
	total_elapsed = 0
	total_distance = 0
	assisted_seconds = 0
	last_sample = -1
	last_save = 0
	saved_final = false
	too_close = false
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	activity = {"version":1, "id":stamp + "-%08x" % randi(), "kind":"derny", "title":"Dernytraining", "started_unix":int(Time.get_unix_time_from_system()), "started_local":Time.get_datetime_string_from_system(false,true), "demo":demo}
	session.start(start_distance,page.start_speed.value)
	activity["start_speed_kmh"] = session.start_speed_kmh
	player_speed = session.target_kmh/3.6
	motor.speed_mps = player_speed
	motor.configure(game,session.start_speed_kmh,LOWEST_LANE)
	session.guidance_power_w = motor.rider_mean_power_w
	if not demo: game.trainer_control.arm()
	super.enter()
	_capture_sample()
	_persist(false)
	hud.show()
	page.selected_activity = {}
func leave() -> void:
	if session.running(): session.stop("Training verlaten")
	if not activity.is_empty() and not saved_final:
		_capture_sample()
		_persist(true)
	hud.hide()
	release_trainer()
	popup.clear()
	super.leave()
	if not saved_camera.is_empty():
		game.camera.transform = saved_camera.transform
		game.camera.fov = saved_camera.fov
func release_trainer() -> void:
	game.trainer_control.tick(false, 0.0, 1.0, game._now_s())
func _lane_gap(from: float, to: float) -> float:
	var delta := to-from
	if absf(delta) > 60: return delta * game._path_metric(from,derny_lane_offset)
	var point: Vector3 = game._at(from,derny_lane_offset)
	var length := 0.0
	for i in range(1,5):
		var next: Vector3 = game._at(lerpf(from,to,i/4.0),derny_lane_offset)
		length += point.distance_to(next)
		point = next
	return length * signf(delta)
func gap() -> float:
	return _lane_gap(distance,session.derny_distance)
func _behind_derny(metres: float) -> float:
	var low: float = session.derny_distance-metres*2
	var high: float = session.derny_distance
	for i in range(10):
		var middle := (low+high)*.5
		if _lane_gap(middle,session.derny_distance) > metres: low = middle
		else: high = middle
	return low
func steer(direction: int) -> void:
	if session.phase != "PACE": return
	var minimum := floori((game.LANES[0]-derny_lane_offset)/game.PLAYER_LANE_STEP_M)
	var maximum := ceili((game.LANES[-1]-derny_lane_offset)/game.PLAYER_LANE_STEP_M)
	player_lane_target = clampi(player_lane_target+direction,minimum,maximum)
func _speed_changed(kmh: int) -> void:
	popup.clear()
	popup.enqueue("DERNY  ·  gemiddeld %d km/u" % kmh)
func advance(dt: float) -> void:
	if not active or session == null: return
	var now: float = game._now_s()
	var live: bool = game.setup_panel.ftp_page.fresh(now)
	if session.running() and not demo and not live: session.stop("Vermogenssignaal verloren")
	if session.running() and demo and game.trainer_seen: session.stop("Trainer verbonden · start opnieuw met trainer")
	if session.running():
		# Small fixed-size steps keep the force model stable at slow frame rates.
		var remaining := minf(maxf(dt, 0), .25)
		while remaining > .00001:
			var step := minf(remaining, 1.0 / 120.0)
			_step(step, demo_power if demo else game.setup_panel.ftp_page.measured)
			remaining -= step
			if not session.running(): break
	var enabled: bool = session.running() and not demo and live
	game.trainer_control.tick(enabled, road_grade, 1.0 - reduction, now)
	if enabled and (not game.trainer_control.error.is_empty() or (now - control_started > 8 and game.trainer_control.last_response < control_started)):
		session.stop("Trainerbediening niet beschikbaar")
		release_trainer()
	if not session.running():
		finish_session(session.reason)
		return
	_present(dt)
	if total_elapsed - last_sample >= 1.0: _capture_sample()
	if total_elapsed - last_save >= 10.0: _persist(false)
func _step(dt: float, power: float) -> void:
	var previous: Vector3 = game._at(distance, player_lane_offset)
	var before := distance
	var desired_lane := Session.lane_at_speed(session.target_kmh,session.start_speed_kmh)
	var old_derny_lane := derny_lane_offset
	derny_lane_offset = move_toward(derny_lane_offset,desired_lane,LANE_RISE_MPS*dt)
	var metric: float = game._path_metric(distance,derny_lane_offset)
	var runup: bool = session.phase == "RUNUP"
	var motor_mean: float = session.start_speed_kmh if runup else session.target_kmh
	motor.configure(game,motor_mean,Session.lane_at_speed(motor_mean,session.start_speed_kmh))
	motor.advance_speed(game,session.derny_distance,old_derny_lane,derny_lane_offset,dt)
	too_close = false
	if runup:
		# Assisted approach: measured watts remain real; virtual motion follows pilot.
		player_lane_offset = derny_lane_offset
		player_lane_target = 0
		session.advance(dt,game._path_metric(session.derny_distance,derny_lane_offset),session.derny_distance-3/metric,metric,motor.speed_mps)
		distance = _behind_derny(3.0)
		player_speed = motor.speed_mps
		assisted_seconds += dt
	else:
		var lateral_before := player_lane_offset
		var gap_before := gap()
		var following_lane := clampf(derny_lane_offset + player_lane_target * game.PLAYER_LANE_STEP_M,game.LANES[0],game.LANES[-1])
		player_lane_offset = move_toward(player_lane_offset,following_lane,game.LANE_CHANGE_MPS*dt)
		reduction = Session.draft_reduction(gap_before,player_lane_offset-derny_lane_offset)
		player_speed = Session.next_speed(player_speed,power,reduction,dt)
		var forward: Vector3 = game._at(distance+player_speed*dt/game._path_metric(distance,player_lane_offset),player_lane_offset)
		var side: Vector3 = game._at(distance,player_lane_offset)
		player_speed = game._banked_speed(player_speed,forward.y-side.y,side.y-previous.y,absf(player_lane_offset-lateral_before),dt,power)
		distance += player_speed*dt/game._path_metric(distance,player_lane_offset)
		session.advance(dt,game._path_metric(session.derny_distance,derny_lane_offset),distance,metric,motor.speed_mps)
		# Hold the wheel despite excess watts. Deliberately move two lanes out to pass.
		if gap_before > 0 and absf(player_lane_offset-derny_lane_offset) < PASS_LATERAL and gap() < FOLLOW_GAP + .06:
			player_speed = minf(player_speed,motor.speed_mps)
			distance = minf(distance,before+player_speed*dt/game._path_metric(before,player_lane_offset))
			if gap() < FOLLOW_GAP: distance = _behind_derny(FOLLOW_GAP)
			too_close = true
		elif gap() < FOLLOW_GAP + .15 and gap() > 0 and player_speed > motor.speed_mps + .02 and absf(player_lane_offset-derny_lane_offset) < PASS_LATERAL:
			too_close = true
	var current: Vector3 = game._at(distance,player_lane_offset)
	road_grade = lerpf(road_grade,game.TrainerControl.route_grade(previous,current),1-exp(-8*dt))
	reduction = Session.draft_reduction(gap(),player_lane_offset-derny_lane_offset)
	session.update_guidance(dt,motor.rider_mean_power_w)
	total_elapsed += dt
	total_distance += maxf(0,(distance-before)*game._path_metric(distance,player_lane_offset))
func _present(dt: float) -> void:
	var point: Vector3 = game._at(distance, player_lane_offset)
	var forward: Vector3 = game._direction(distance, player_lane_offset)
	var bike: Node3D = game.bikes[0]
	bike.position = point + Vector3.UP * .10
	bike.rotation = Vector3(0, atan2(forward.x, forward.z), -game._bank_angle(game._track_s(distance)))
	bike.get_child(0).call("set_victory", false)
	bike.get_child(0).call("pedal", dt if session.running() else 0, 85.0 if demo else maxf(0, game.cadence), demo_power if demo else game.watts)
	pilot.animator.speed_scale = 1.0 if session.running() else 0.0
	var pilot_forward: Vector3 = game._direction(session.derny_distance, derny_lane_offset)
	pilot.position = game._at(session.derny_distance, derny_lane_offset)
	pilot.rotation = Vector3(0, atan2(pilot_forward.x, pilot_forward.z), -game._bank_angle(game._track_s(session.derny_distance)))
	game.visual_rolls[0] = bike.rotation.z
	game._follow_rider_camera(distance,player_lane_offset,dt,false,bike.position)
	bike.visible = game.look_back_held or game.camera_mode != 2
	hud.update_training(self)

func required_power() -> float:
	return session.guidance_power_w
func _capture_sample() -> void:
	if not demo and not game.setup_panel.ftp_page.fresh(game._now_s()): return
	if not samples.is_empty() and total_elapsed <= float(samples[-1].time_s): return
	samples.append({"time_s":total_elapsed,"distance_m":total_distance,"game_speed_kmh":player_speed*3.6,"power_w":demo_power if demo else game.setup_panel.ftp_page.measured,"heart_rate_bpm":null if demo else game.trainer_heart_rate_bpm,"cadence_rpm":-1.0 if demo else game.cadence,"draft_pct":reduction*100,"target_kmh":session.target_kmh,"derny_speed_kmh":motor.speed_mps*3.6,"derny_power_w":motor.power_w,"assisted":session.phase=="RUNUP"})
	last_sample = total_elapsed
	hud.graph.set_samples(samples)
func _persist(final: bool) -> void:
	if activity.is_empty(): return
	activity.merge({"samples":samples,"duration_s":total_elapsed,"distance_m":total_distance,"assisted_seconds":assisted_seconds,"completed_kmh":session.completed_kmh,"reason":session.reason,"final":final},true)
	var saved: bool = store.save(activity)
	save_status = "Training opgeslagen in het spel." if saved else "Opslaan mislukt: " + store.error
	if saved:
		last_save = total_elapsed
		if final: saved_final = true
func finish_session(reason: String, show_result: bool = true) -> void:
	session.stop(reason)
	_capture_sample()
	_persist(true)
	release_trainer()
	hud.hide()
	popup.clear()
	page.show_activity(activity,save_status)
	if show_result:
		game.setup_panel._piste_environment(false)
		game.setup_panel.show_derny()
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not saved_final and not activity.is_empty():
		session.stop("Spel gesloten")
		_persist(true)
