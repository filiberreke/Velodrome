extends "res://derny_environment.gd"
## Dedicated v0.2 training state: never changes game race arrays or race_mode.
var madison = preload("res://madison_exchange.gd").new()
var animation: Node
var race_mode := 6 # Adapter-local role identifier, never assigned to game.race_mode.
var bikes: Array[Node3D] = []
var distances: Array[float] = [0.0,0.0]
var speeds: Array[float] = [12.0,8.0]
var lane_offsets: Array[float] = [2.38,3.58]
var finish_times: Array[float] = [-1.0,-1.0]
var baseline_speed := 12.0
var finished := false
var input_sources := {}
var pending_trial := false
signal partner_spawned
signal partner_despawned
const RESPAWN_SECONDS := 0.0
const PARTNER_FADE_SECONDS := 0.3
var partner_present := false
var respawn_remaining := 0.0
var fade_in_remaining := 0.0
var partner_meshes: Array[Node] = []
var next_spawn_player_distance := 0.0
var _outfit := {}
var exchange_results: Array[Dictionary] = []
var attempt_giver := 0
var feedback := ""
var feedback_until := 0.0
var exchange_zone: MeshInstance3D
var _zone_key := ""

func _setup_session() -> void:
	name = "MadisonTrainingEnvironment"
	page = game.setup_panel.madison_page; session = page.session; page.scene = self
	store = game.setup_panel.training_store
	popup = preload("res://race_popup.gd").new(); game.setup_panel.add_child(popup)
	hud = preload("res://madison_training_hud.gd").new(); game.setup_panel.add_child(hud); hud.hide()
	hud.stop_button.pressed.connect(func(): finish_session("Handmatig gestopt"))
	hud.leave_button.pressed.connect(page.leave)
	for i in range(2):
		var bike := Node3D.new(); bike.name = "Speler" if i == 0 else "Ploegmaat"; add_child(bike); bikes.append(bike)
		var rider := preload("res://rider_visual.gd").new(); rider.set_meta("rider_index",i); rider.set_meta("appearance_profile",0); bike.add_child(rider)
	exchange_zone = MeshInstance3D.new(); exchange_zone.name = "Wisselzone"; add_child(exchange_zone)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0,0.82,0.05,0.55)
	exchange_zone.material_override = material
	animation = preload("res://madison_animation.gd").new(); add_child(animation)
	partner_meshes.assign(bikes[1].find_children("*","GeometryInstance3D",true,false))
	animation.reach_limit.connect(madison.release_for_reach)
	madison.phase_changed.connect(_phase_changed); madison.released.connect(_released)
func enter() -> void:
	if active: leave()
	saved_camera = {"transform":game.camera.transform,"fov":game.camera.fov}
	demo = not game.trainer_seen; demo_power = 300.0; control_started = game._now_s()
	player_lane_target = 2; player_lane_offset = 2.38
	distances.assign([start_distance,start_distance+10.0]); speeds.assign([12.0,8.0]); lane_offsets.assign([2.38,3.58])
	finish_times.fill(-1.0); baseline_speed = 12.0; finished = false
	madison.reset(); madison.advanced = page.difficulty.selected == 1; input_sources.clear(); pending_trial = true
	exchange_results.clear(); attempt_giver = 0; feedback = ""; feedback_until = 0; _zone_key = ""
	partner_present = true; respawn_remaining = 0; fade_in_remaining = PARTNER_FADE_SECONDS
	next_spawn_player_distance = start_distance+game.LAP
	page.progress.reset_session(page.count.get_selected_id())
	session.start("madison",start_distance,0.0,0.0)
	total_elapsed = 0; total_distance = 0; player_speed = speeds[0]; road_grade = 0; reduction = 0
	samples = []; last_sample = -1; last_save = 0; saved_final = false; assisted_seconds = 0; too_close = false
	var stamp := Time.get_datetime_string_from_system().replace(":","-")
	activity = {"version":1,"id":stamp+"-%08x" % randi(),"kind":"madison","title":"Aflossingstraining","started_unix":int(Time.get_unix_time_from_system()),"started_local":Time.get_datetime_string_from_system(false,true),"demo":demo,"advanced":madison.advanced}
	if not demo:
		game.setup_panel.ftp_page.reset_session(game._now_s(),game.trainer_control)
		game.trainer_control.arm()
	_sync_kit()
	_enter_training_venue()
	game.bikes[0].hide()
	page.selected_activity = {}
	_capture_sample(); _persist(false); hud.show(); _present(0)
func leave() -> void:
	_score_interrupted("Training verlaten tijdens de aflossing")
	animation.clear(); input_sources.clear()
	super.leave()
	partner_present = false; bikes[1].hide(); exchange_zone.hide()
func _at(at: float, lane: float) -> Vector3: return game._at(at,lane)
func grab_button(source: String, pressed: bool) -> void:
	if pressed and active and session.running(): input_sources[source] = true
	else: input_sources.erase(source)
	madison.button(not input_sources.is_empty())
func steer(direction: int) -> void:
	if session.running(): player_lane_target = clampi(player_lane_target+direction,0,game.LANES.size()-1)
func request_tempo(direction: int) -> void: steer(direction)
func _phase_changed(phase: String, _giver: int, _receiver: int) -> void:
	if phase == "APPROACH":
		pending_trial = true; attempt_giver = madison.giver
	elif phase == "SEPARATE": _score(false)
func _released(g: int, r: int, efficiency: float) -> void:
	madison.apply_release(self,g,r,efficiency)
	_score(efficiency > 0.0)
func _score(success: bool) -> void:
	if not pending_trial or page.progress.complete(): return
	pending_trial = false
	var reason: String = "" if success else madison.failure_reason
	if not success and reason.is_empty():
		var placement: Dictionary = madison.positioning(self)
		var pace: Dictionary = madison.speed_guidance(self)
		reason = str(placement.reason) if not placement.valid else str(pace.reason) if not pace.valid else "Greep gemist — niet op tijd op A gedrukt"
	var score: int = clampi(roundi(madison.score_percent()),1,100) if success else 0
	var role: String = "Uitgaand" if attempt_giver == 0 else "Inkomend"
	exchange_results.append({"number":exchange_results.size()+1,"role":role,"player_role":"giver" if attempt_giver == 0 else "receiver","success":success,"reason":reason,"score":score,"momentum_percent":madison.efficiency*100.0 if success else 0.0})
	feedback = "%s · %d%% · %s" % [role,score,"Geslaagd" if success else "Mislukt: " + reason]
	feedback_until = total_elapsed+5.0
	page.progress.record(success,not madison.advanced)
func _update_exchange_zone() -> void:
	exchange_zone.visible = active and session.running()
	if not exchange_zone.visible: return
	var incoming: bool = (madison.giver if madison.active else madison.active_rider) == 0
	var lane: float = 2.38 if incoming else 3.58
	# Follow the banked surface; only rebuild once every 5 m or when roles change.
	var anchor: float = floorf(distances[0]/5.0)*5.0
	var key := str(anchor)+":"+str(incoming)
	if key == _zone_key: return
	_zone_key = key
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(40):
		var d: float = anchor-5.0+step*2.0
		var half_width := 0.14
		var a: Vector3 = game._at(d,lane-half_width)+Vector3.UP*0.04
		var b: Vector3 = game._at(d,lane+half_width)+Vector3.UP*0.04
		var c: Vector3 = game._at(d+2.0,lane-half_width)+Vector3.UP*0.04
		var e: Vector3 = game._at(d+2.0,lane+half_width)+Vector3.UP*0.04
		for point in [a,b,c,b,e,c]: mesh.surface_add_vertex(point)
	mesh.surface_end(); exchange_zone.mesh = mesh
func _ai_lane() -> float:
	if (madison.active and madison.giver == 1 and madison.phase in [madison.Phase.RELEASE,madison.Phase.SEPARATE]) or (madison.cooldown > 0 and madison.active_rider == 0):
		if lane_offsets[1] < lane_offsets[0] and absf(wrapf(distances[0]-distances[1],-125,125)) < 2.2: return lane_offsets[1]
		return 4.78
	return clampf(lane_offsets[0]-1.2,1.18,2.38) if madison.active_rider == 1 else 3.58
func _step(dt: float, power: float) -> void:
	# An unattempted/uncatchable opportunity must not block the next player lap.
	if partner_present and distances[0] >= next_spawn_player_distance and not page.progress.complete():
		if madison.active and madison.phase == madison.Phase.APPROACH:
			var placement: Dictionary = madison.positioning(self)
			var pace: Dictionary = madison.speed_guidance(self)
			madison.cancel(str(placement.reason) if not placement.valid else str(pace.reason) if not pace.valid else "Ploegmaat niet tijdig binnen handbereik")
		elif not madison.active:
			_score(false)
			_despawn_partner()
	if not partner_present and not page.progress.complete() and distances[0] >= next_spawn_player_distance:
		respawn_remaining = maxf(0,respawn_remaining-dt)
		if respawn_remaining <= 0: _spawn_partner()
	if partner_present:
		var was_active: bool = madison.active
		madison.step(self,dt)
		if was_active and not madison.active: _despawn_partner()
	if page.progress.complete() and not madison.active:
		finished = true; session.stop("Training voltooid"); return
	var previous: Vector3 = game._at(distances[0],lane_offsets[0])
	for i in range(2):
		if i == 1 and not partner_present: continue
		var old_lane: float = lane_offsets[i]
		lane_offsets[i] = move_toward(old_lane,game.LANES[player_lane_target] if i == 0 else _ai_lane(),game.LANE_CHANGE_MPS*dt)
		var target: float = speeds[0] if madison.active and madison.phase in [madison.Phase.GRAB,madison.Phase.SLING] else minf(17,speeds[0]+2) if madison.active_rider == 1 else 7.5
		var watts: float = power if i == 0 else clampf(240+(target-speeds[1])*190,0,850)
		var before: float = distances[i]
		speeds[i] = Session.next_speed(speeds[i],watts,0,dt)
		var side: Vector3 = game._at(before,lane_offsets[i])
		var forward: Vector3 = game._at(before+speeds[i]*dt/game._path_metric(before,lane_offsets[i]),lane_offsets[i])
		speeds[i] = game._banked_speed(speeds[i],forward.y-side.y,side.y-game._at(before,old_lane).y,absf(lane_offsets[i]-old_lane),dt,watts)
		distances[i] += speeds[i]*dt/game._path_metric(before,lane_offsets[i])
		if i == 0: total_distance += speeds[i]*dt
	baseline_speed = speeds[0]; player_speed = speeds[0]; player_lane_offset = lane_offsets[0]; distance = distances[0]
	road_grade = lerpf(road_grade,game.TrainerControl.route_grade(previous,game._at(distance,player_lane_offset)),1-exp(-8*dt))
	session.elapsed += dt; session.peak_w = maxf(session.peak_w,power); session.energy_j += power*dt
	total_elapsed = session.elapsed
func _despawn_partner() -> void:
	# SEPARATE has already faded this model; reset only after hiding it.
	partner_present = false
	bikes[1].hide()
	animation.clear()
	madison.active_rider = 1-attempt_giver
	respawn_remaining = RESPAWN_SECONDS
	partner_despawned.emit()
func _spawn_partner() -> void:
	bikes[1].hide()
	animation.clear()
	attempt_giver = madison.active_rider
	madison.failure_reason = ""; madison.release_reason = ""
	if madison.active_rider == 0:
		distances[1] = distances[0]+madison.approach_distance
		lane_offsets[1] = 3.58
		speeds[1] = maxf(4.0,speeds[0]-2.0)
	else:
		distances[1] = distances[0]-madison.approach_distance
		lane_offsets[1] = clampf(lane_offsets[0]-1.2,1.18,2.38)
		speeds[1] = minf(17.0,maxf(10.0,speeds[0]+2.0))
	madison.cooldown = 0; madison.visual_offsets.assign([0.0,0.0])
	partner_present = true; fade_in_remaining = PARTNER_FADE_SECONDS; pending_trial = true
	# One opportunity for each player lap; no wait for an AI lap or full cooldown.
	next_spawn_player_distance = start_distance+(floorf((distances[0]-start_distance)/game.LAP)+1.0)*game.LAP
	# Keep the recycled model invisible until _present has placed it at spawn.
	for mesh in partner_meshes: mesh.transparency = 1.0
	partner_spawned.emit()
func _sync_kit() -> void:
	var outfit: Dictionary = game.player_appearance.resolve(game.get_player_appearance_base())
	if outfit == _outfit: return
	_outfit = outfit.duplicate(true)
	for bike in bikes: game.PlayerAppearance.apply_to_rider(bike.get_child(0),outfit)
func _present(dt: float) -> void:
	_sync_kit()
	game.bikes[0].hide()
	for i in range(2):
		var at: float = distances[i]
		var lane: float = lane_offsets[i]+madison.visual_offsets[i]
		var forward: Vector3 = game._direction(at,lane)
		bikes[i].position = game._at(at,lane)+Vector3.UP*.1
		bikes[i].rotation = Vector3(0,atan2(forward.x,forward.z),-game._bank_angle(game._track_s(at)))
	animation.update_pair(self,dt)
	if partner_present:
		fade_in_remaining = maxf(0,fade_in_remaining-maxf(dt,0))
		var alpha: float = fade_in_remaining/PARTNER_FADE_SECONDS
		if madison.active and madison.phase == madison.Phase.SEPARATE: alpha = maxf(alpha,clampf(madison.elapsed/madison.separate_seconds,0,1))
		for mesh in partner_meshes: mesh.transparency = alpha
	bikes[1].visible = partner_present
	for i in range(2): bikes[i].get_child(0).pedal(dt,(85 if demo else maxf(0,game.cadence)) if i == 0 else clampf(speeds[i]*6,0,120),demo_power if demo else game.setup_panel.ftp_page.measured)
	game.visual_rolls[0] = bikes[0].rotation.z
	game._follow_rider_camera(distance,player_lane_offset,dt,false,bikes[0].position)
	bikes[0].visible = game.look_back_held or game.camera_mode != 2
	_update_exchange_zone()
	hud.update_training(self)
func _persist(final: bool) -> void:
	if activity.is_empty(): return
	activity.merge({"samples":samples,"duration_s":total_elapsed,"distance_m":total_distance,"reason":session.reason,"final":final,"attempts":page.progress.attempts,"successes":page.progress.successes,"target":page.progress.target,"completed":page.progress.complete(),"exchanges":exchange_results.duplicate(true),"peak_power_w":session.peak_w,"mean_power_w":session.energy_j/maxf(.001,session.elapsed)},true)
	var ok: bool = store.save(activity)
	save_status = "Training opgeslagen in het spel." if ok else "Opslaan mislukt: "+store.error
	if ok:
		last_save = total_elapsed
		if final: saved_final = true
func _score_interrupted(reason: String) -> void:
	if pending_trial and madison.active and madison.phase in [madison.Phase.GRAB,madison.Phase.SLING]:
		madison.failure_reason = reason
		_score(false)
func finish_session(reason: String, show_result: bool = true) -> void:
	_score_interrupted(reason)
	session.stop(reason); finished = true; animation.clear(); input_sources.clear()
	_capture_sample(); _persist(true); release_trainer(); hud.hide(); popup.clear()
	page.show_activity(activity,save_status)
	if show_result:
		game.setup_panel._madison_environment(false)
		game.setup_panel.show_madison_training()
