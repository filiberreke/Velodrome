extends "res://training_environment.gd"
## Isolated piste exercise: shares the empty training venue, never race state.
const Session := preload("res://derny_session.gd")
const Visual := preload("res://derny_visual.gd")
const LANE := 2.38
var page
var session
var pilot: Node3D
var popup: Label
var player_speed := 20.0 / 3.6
var player_lane_offset := LANE
var player_lane_target := 2
var reduction := 0.0
var road_grade := 0.0
var demo := false
var demo_power := 130.0
var control_started := -1.0
var saved_camera := {}
func _ready() -> void:
	super._ready()
	name = "DernyTrainingEnvironment"
	page = game.setup_panel.derny_page
	session = page.session
	page.scene = self
	pilot = Visual.new()
	pilot.name = "DernyPilot"
	add_child(pilot)
	popup = preload("res://race_popup.gd").new()
	game.setup_panel.add_child(popup)
	session.speed_changed.connect(_speed_changed)
	session.gesture_requested.connect(pilot.gesture)
func enter() -> void:
	if active: leave()
	saved_camera = {"transform": game.camera.transform, "fov":game.camera.fov}
	demo = not game.trainer_seen
	demo_power = 130.0
	player_speed = 20.0 / 3.6
	player_lane_offset = LANE
	player_lane_target = 2
	reduction = 0.0
	road_grade = 0.0
	control_started = game._now_s()
	session.start(start_distance)
	if not demo: game.trainer_control.arm()
	super.enter()
func leave() -> void:
	session.stop("Training verlaten")
	release_trainer()
	popup.clear()
	super.leave()
	if not saved_camera.is_empty():
		game.camera.transform = saved_camera.transform
		game.camera.fov = saved_camera.fov
func release_trainer() -> void:
	game.trainer_control.tick(false, 0.0, 1.0, game._now_s())
func gap() -> float:
	return (session.derny_distance - distance) * game._path_metric(distance, LANE)
func steer(direction: int) -> void:
	if session.running(): player_lane_target = clampi(player_lane_target + direction, 0, game.LANES.size() - 1)
func _speed_changed(kmh: int) -> void:
	popup.clear()
	popup.enqueue("DERNY  ·  %d km/u" % kmh)
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
	_present(dt)
func _step(dt: float, power: float) -> void:
	var previous: Vector3 = game._at(distance, player_lane_offset)
	var lateral_before := player_lane_offset
	player_lane_offset = move_toward(player_lane_offset, game.LANES[player_lane_target], game.LANE_CHANGE_MPS * dt)
	reduction = Session.draft_reduction(gap(), player_lane_offset - LANE)
	player_speed = Session.next_speed(player_speed, power, reduction, dt)
	var forward: Vector3 = game._at(distance + player_speed * dt / game._path_metric(distance, player_lane_offset), player_lane_offset)
	var side: Vector3 = game._at(distance, player_lane_offset)
	player_speed = game._banked_speed(player_speed, forward.y - side.y, side.y - previous.y, absf(player_lane_offset - lateral_before), dt, power)
	distance += player_speed * dt / game._path_metric(distance, player_lane_offset)
	var current: Vector3 = game._at(distance, player_lane_offset)
	road_grade = lerpf(road_grade, game.TrainerControl.route_grade(previous, current), 1.0 - exp(-8.0 * dt))
	session.advance(dt, game._path_metric(session.derny_distance, LANE), distance, game._path_metric(distance, LANE))
	reduction = Session.draft_reduction(gap(), player_lane_offset - LANE)
func _present(dt: float) -> void:
	var point: Vector3 = game._at(distance, player_lane_offset)
	var forward: Vector3 = game._direction(distance, player_lane_offset)
	var bike: Node3D = game.bikes[0]
	bike.position = point + Vector3.UP * .10
	bike.rotation = Vector3(0, atan2(forward.x, forward.z), -game._bank_angle(game._track_s(distance)))
	bike.get_child(0).call("set_victory", false)
	bike.get_child(0).call("pedal", dt if session.running() else 0, 85.0 if demo else maxf(0, game.cadence), demo_power if demo else game.watts)
	pilot.animator.speed_scale = 1.0 if session.running() else 0.0
	var pilot_forward: Vector3 = game._direction(session.derny_distance, LANE)
	pilot.position = game._at(session.derny_distance, LANE)
	pilot.rotation = Vector3(0, atan2(pilot_forward.x, pilot_forward.z), -game._bank_angle(game._track_s(session.derny_distance)))
	game.camera.position = point - forward * 6.5 + Vector3(forward.z, 0, -forward.x) * 2.5 + Vector3(0, 2.8, 0)
	game.camera.look_at(point + forward * 7 + Vector3.UP)
	game.camera.fov = 70
