extends SceneTree
## Full simulated points race: production start, physics, jury, official, photo,
## and CSV writer. Only rendering, live hardware and personal records are isolated.
class Game extends "res://main.gd":
	var physical_crossings: Array[Dictionary] = []
	var photos: Array[Dictionary] = []
	var saves: Array[Dictionary] = []
	var painted_finish: Array[float] = []
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _read_bridge() -> void: pass
	func _update_visuals(_dt: float) -> void: pass
	func _update_hud() -> void: pass
	func _update_boost_dog(_dt: float) -> void: pass
	func _update_countdown_display() -> void: pass
	func _update_trainer_control() -> void: pass
	func _update_coasting(_dt: float) -> void: pass
	func _record_ai_performances() -> void: pass
	func _take_finish_photo(winner: int) -> void:
		super._take_finish_photo(winner)
		photos.append({"rider":winner,"time":finish_times[winner],"distance":distances[winner],"camera":finish_photo_camera.position})
	func _register_lap_crossings(rider: int, previous: float, step: float, dt: float) -> void:
		# Observe the physical advance before the jury freezes a finisher at
		# the interpolated line; the jury's times are not used here.
		if step > 0.0:
			for lap in range(maxi(1,floori(previous/250.0)+1),floori((previous+step)/250.0)+1):
				physical_crossings.append({"rider":rider,"lap":lap,"time":clock-dt+dt*(lap*250.0-previous)/step})
		super._register_lap_crossings(rider,previous,step,dt)
	func _save_recording(reason: String) -> void:
		if reason == "finish":
			saves.append({"reason":reason,"time":finish_times[0],"distance":distances[0]})
		super._save_recording(reason)
	func _track_band(inner: float, outer: float, color: Color, start_s: float = 0.0, extent: float = LAP, lift: float = 0.0) -> void:
		super._track_band(inner,outer,color,start_s,extent,lift)
		if is_equal_approx(start_s,-0.02) and is_equal_approx(extent,0.04):
			painted_finish.assign([start_s,extent])

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	seed(20261111)
	var game := Game.new()
	root.add_child(game)
	game.race_mode = 1; game.rider_count = 16; game.race_laps = 20
	game._configure_peloton()
	game.rider_forms.fill(1.0)
	game.demo_launch_watts = 315.0
	game._build_realistic_track()
	game.camera = Camera3D.new(); game.add_child(game.camera)
	game.finish_photo_viewport = SubViewport.new(); game.add_child(game.finish_photo_viewport)
	game.finish_photo_camera = Camera3D.new(); game.finish_photo_viewport.add_child(game.finish_photo_camera)
	game.finish_photo_caption = Label.new(); game.add_child(game.finish_photo_caption)
	var official = preload("res://infield_details.gd").new()
	official.game = game
	official._build_flag_official()
	check(official.official_clips.size()==4,"Use the actual production official and all four animations")
	var line: Vector3 = game._at(0.0,1.18)
	check(game.painted_finish == [-0.02,0.04],"Painted black finish is centred on race distance zero")
	for distance in [-5.0,-0.36,0.0,0.36,2.0]:
		check(is_zero_approx(game._curve_factor(distance)),"Finish strip and final approach are fully straight")
		check(absf(rad_to_deg(game._bank_angle(game._track_s(distance)))-12.0)<0.001,"Finish has straight banking")
	check(game._curve_factor(4.0)>0.0,"Smooth turn begins beyond the 2 m finish clearance")
	var official_point: Vector3 = game._at(0.0,-1.05); official_point.y = 0.0
	check(official.flag_node.position.distance_to(official_point)<0.0001,"Official stands beside the same physical finish")
	check(absf(official.flag_node.position.z-line.z)<0.001,"Official and finish share the same longitudinal position")
	for distance in [game.PURSUIT_START_M,game.NEUTRAL_DEPARTURE_M,game.OPPOSITE_STRAIGHT_GATE_M]:
		check(absf(game._at(distance,1.18).z)<0.001 and is_zero_approx(game._curve_factor(distance)),"Pursuit, neutral departure and exit gate remain at straight centres")
	game._begin_riding()
	var dt := 0.1
	var neutral_first_crossings := 0
	var race_starts := 0
	var neutral_duration := 0.0
	var actions: Array[Dictionary] = []
	var previous_action := ""
	for tick in range(14000):
		var before: Array[float] = game.distances.duplicate()
		var state: String = game.start_state
		# Synthetic telemetry exercises the real CSV writer only in this isolated
		# test's user-data directory; it never reaches a trainer or account.
		if tick % 10 == 0 and not game.finished:
			game.ride_records.append({"time_s":game._training_seconds(),"distance_m":game._training_distance(),"power_w":315.0,"trainer_speed_kmh":game.speeds[0]*3.6,"game_speed_kmh":game.speeds[0]*3.6,"cadence_rpm":90.0,"lane":1,"draft_pct":0.0,"heart_rate_bpm":null})
		game._physics_process(dt)
		official._process(dt)
		if official.flag_anim != null: official.flag_anim.advance(dt)
		if official.official_action != previous_action:
			previous_action = official.official_action
			if not previous_action.is_empty(): actions.append({"action":previous_action,"state":game.start_state,"lead":game.distances.max(),"clock":game.clock})
		if state == "NEUTRAL":
			if before[0]<0.0 and game.distances[0]>=0.0: neutral_first_crossings+=1
			if game.start_state=="NEUTRAL":
				check(game.clock==0.0 and game.points_rules.sprints.is_empty(),"Neutral lap cannot start race clock or score a sprint")
			else:
				race_starts+=1; neutral_duration=game.neutral_start.elapsed
				check(before[0]>249.0 and game.distances[0]>=0.0 and game.distances[0]<2.0,"Race starts on the actual line after exactly one neutral lap")
				check(game._at(250.0,1.18).distance_to(line)<0.001,"Neutral start crossing and race zero share physical finish")
				game.x_ai.rng.seed = 20261111
		if game._all_riders_finished(): break
	check(neutral_first_crossings==1 and race_starts==1,"One approach passage, one neutral lap and one race start")
	check(neutral_duration>25.0,"Neutral lap was simulated, not skipped")
	check(game._all_riders_finished() and game.points_rules.complete(),"All 16 riders finish the complete 20-lap race")
	check(game.points_rules.sprints.size()==2,"One intermediate sprint and one final sprint, with no duplicate scoring")
	for sprint in game.points_rules.sprints:
		check(sprint.order.size()==16,"Each sprint judges all riders once")
		check(sprint.awards.slice(0,4)==([10,6,4,2] if sprint.lap==20 else [5,3,2,1]),"Intermediate and double final awards are correct")
		for n in range(sprint.order.size()):
			var rider: int = sprint.order[n]
			var matched := false
			for crossing in game.physical_crossings:
				if crossing.rider==rider and absf(crossing.time-sprint.times[n])<0.00001:
					matched=true
					check(game._at(float(crossing.lap)*250.0,game.lane_offsets[rider]).distance_to(game._at(0.0,game.lane_offsets[rider]))<0.001,"Jury sprint crossing lies on the painted finish")
			check(matched,"Sprint timing matches independently detected physical line passage")
	var observed: Array = actions.map(func(event): return event.action)
	for action in ["VO_StartReady","VO_StartFire","VO_LastLapBell","VO_FinishFlag"]:
		check(observed.has(action),"Official performs "+action+" during the simulated race")
	check(observed.find("VO_StartReady")<observed.find("VO_StartFire") and observed.find("VO_StartFire")<observed.find("VO_LastLapBell") and observed.find("VO_LastLapBell")<observed.find("VO_FinishFlag"),"Official actions occur in the correct race order")
	check(official.official_finish_completed and not official.official_bell_active,"Official stops after all arrivals")
	check(not game.photos.is_empty() and game.finish_photo_taken,"Arrival triggers the production finish-photo camera")
	for photo in game.photos:
		var expected: Vector3 = game._at(game._rider_distance(photo.rider,game._race_length())+game.FINISH_PHOTO_AFTER_LINE_M,game.FINISH_PHOTO_INFIELD_OFFSET); expected.y=1.5
		check(Vector3(photo.camera).distance_to(expected)<0.001,"Finish photo follows the relocated line")
	check(game.saves.size()==1 and game.saves[0].time==game.finish_times[0] and game.recording_saved,"Player arrival saves exactly one real CSV recording")
	check(not DirAccess.get_files_at(game.recording_folder).is_empty(),"CSV recording exists in isolated test storage")
	check(game.demo_fit_records.size()>100,"Production demo recording includes the simulated race")
	var last_distance := -1.0; var last_time := -1.0
	for sample in game.demo_fit_records:
		check(sample.distance_m>=last_distance and sample.time_s>=last_time,"Recording stays continuous across neutral-lap rebase and finish")
		last_distance=sample.distance_m; last_time=sample.time_s
	game._place_finish_camera()
	check(game.camera.position.distance_to(game._at(0.0,game.FINISH_CAMERA_LANE_M))<13.0,"Arrival camera remains beside the relocated finish")
	var frozen: Array[float] = game.distances.duplicate()
	game._physics_process(dt)
	check(game.distances==frozen and game.saves.size()==1,"Completed race neither moves timing positions nor duplicates arrival recording")
	var report := {"passed":failures==0,"checks":checks,"riders":16,"laps":20,"physics_step_s":dt,"neutral_s":neutral_duration,"race_start_count":race_starts,"sprints":game.points_rules.sprints,"official_actions":actions,"finish_times":game.finish_times,"photo_count":game.photos.size(),"arrival_recordings":game.saves,"recording_folder":game.recording_folder,"finish_world":line}
	DirAccess.make_dir_recursive_absolute("res://verification/track_bowl/")
	var file := FileAccess.open("res://verification/track_bowl/finish_race_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("FINISH_LINE_RACE ",JSON.stringify(report))
	official.flag_node.free();official.free();game.free()
	print("FINISH_LINE_RACE_OK" if failures==0 else "FINISH_LINE_RACE_FAILED %d"%failures)
	quit(0 if failures==0 else 1)
