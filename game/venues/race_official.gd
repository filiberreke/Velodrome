extends Node3D
## Shared animated official, independent of a venue's crowd and decorations.
const OFFICIAL_SCENE_PATH := "res://assets/crowd/velodrome_official.glb"
const FLAG_SCENE: PackedScene = preload("res://assets/crowd/flag_official.glb")
var game: Node3D
var official_lap_m := 250.0
# Distances are measured on the venue reference line; approach cues stay metres.
const OFFICIAL_START_READY_M := 60.0
const OFFICIAL_START_SHOT_M := 5.0
const OFFICIAL_BELL_EARLY_M := 50.0
const OFFICIAL_FINISH_EARLY_M := 100.0
var flag_node: Node3D
var flag_anim: AnimationPlayer
var flag_ready := &""
var flag_wave := &""
var flag_state := ""
var wave_timer := 0.0
var finished_seen := 0
# State shared by the animated official builder and race event handlers.
var official_new_model := false
var official_clips: Dictionary = {}
var official_previous_racing := false
var official_start_ready := false
var official_start_fired := false
var official_bell_active := false
var official_finish_active := false
var official_finish_completed := false
var official_finished_seen := 0
var official_action := ""

func _at(s: float, offset: float) -> Vector3:
	var p: Vector3 = game.call("_at", s, offset)
	p.y = 0.0
	return p

func _yaw_to(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)

func _build_flag_official() -> void:
	var scene: PackedScene = FLAG_SCENE
	if ResourceLoader.exists(OFFICIAL_SCENE_PATH):
		var loaded: Resource = load(OFFICIAL_SCENE_PATH)
		if loaded is PackedScene:
			scene = loaded as PackedScene
			official_new_model = true
	flag_node = scene.instantiate()
	flag_node.name = "Wedstrijdcommissaris" if official_new_model else "Vlagdame"
	flag_node.add_to_group("stadium_people")
	var line: Vector3 = _at(0.0, -1.05)
	var outward: Vector3 = (_at(0.0, 0.0) - _at(0.0, -1.0)).normalized()
	var oncoming: Vector3 = -(_at(1.0, -1.0) - _at(-1.0, -1.0)).normalized()
	flag_node.position = line
	flag_node.rotation.y = _yaw_to(outward + oncoming * 0.45)
	add_child(flag_node)
	flag_anim = _find_player(flag_node)
	if flag_anim == null:
		push_warning("Wedstrijdcommissaris: AnimationPlayer ontbreekt")
		return
	for name in flag_anim.get_animation_list():
		var label: String = String(name)
		var clip: Animation = flag_anim.get_animation(name)
		if official_new_model:
			for action in ["VO_StartReady", "VO_StartFire", "VO_LastLapBell", "VO_FinishFlag"]:
				if label == action or label.ends_with("/" + action):
					official_clips[action] = name
					if clip != null:
						clip.loop_mode = Animation.LOOP_NONE if action == "VO_StartFire" else Animation.LOOP_LINEAR
		else:
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
			if label.contains("flag_ready"):
				flag_ready = name
			elif label.contains("flag_wave"):
				flag_wave = name
	if official_new_model:
		_official_props("")
		flag_node.visible = true
		for action in ["VO_StartReady", "VO_StartFire", "VO_LastLapBell", "VO_FinishFlag"]:
			if not official_clips.has(action):
				push_warning("Wedstrijdcommissaris: animatie ontbreekt: " + action)
	else:
		flag_node.visible = false

func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var player: AnimationPlayer = _find_player(child)
		if player != null:
			return player
	return null

func _official_toggle(root: Node, stem: String, enabled: bool) -> void:
	for child in root.get_children():
		if String(child.name).begins_with(stem) and child is Node3D:
			(child as Node3D).visible = enabled
		else:
			_official_toggle(child, stem, enabled)

func _official_props(action: String) -> void:
	if flag_node == null:
		return
	_official_toggle(flag_node, "PROP_StartPistol", action in ["VO_StartReady", "VO_StartFire"])
	_official_toggle(flag_node, "FX_MuzzleFlash", action == "VO_StartFire")
	_official_toggle(flag_node, "FX_Smoke", action == "VO_StartFire")
	_official_toggle(flag_node, "PROP_LastLapBell", action == "VO_LastLapBell")
	_official_toggle(flag_node, "FX_BellRing", action == "VO_LastLapBell")
	_official_toggle(flag_node, "PROP_CheckeredFlag", action == "VO_FinishFlag")
	_official_toggle(flag_node, "PROP_FlagCloth", action == "VO_FinishFlag")
	_official_toggle(flag_node, "FX_FlagSwoosh", action == "VO_FinishFlag")

func _official_play(action: String) -> void:
	if flag_anim == null or not official_clips.has(action):
		return
	if official_action == action and flag_anim.is_playing():
		return
	official_action = action
	var clip_name: StringName = official_clips[action]
	flag_anim.play(clip_name, 0.12)
	_official_props(action)

func _official_ready() -> void:
	if official_start_ready or flag_anim == null or not official_clips.has("VO_StartReady"):
		return
	official_start_ready = true
	_official_play("VO_StartReady")
	# Keep the raised breathing pose playing until the distance triggers firing.

func _official_fire() -> void:
	if official_start_fired:
		return
	official_start_fired = true
	official_action = ""
	_official_play("VO_StartFire")

func _official_idle() -> void:
	if official_action == "":
		return
	official_action = ""
	if flag_anim != null:
		flag_anim.stop()
	_official_props("")

func _official_reset() -> void:
	official_previous_racing = false
	official_start_ready = false
	official_start_fired = false
	official_bell_active = false
	official_finish_active = false
	official_finish_completed = false
	official_finished_seen = 0
	_official_idle()

func _set_flag_state(state: String) -> void:
	if state == flag_state:
		return
	flag_state = state
	flag_node.visible = state != "hidden"
	if flag_anim == null:
		return
	if state == "ready" and flag_ready != &"":
		flag_anim.play(flag_ready, 0.35)
	elif state == "wave" and flag_wave != &"":
		flag_anim.play(flag_wave, 0.2)
	elif state == "hidden":
		flag_anim.stop()

func _process(delta: float) -> void:
	if game == null or flag_node == null:
		return
	var state: String = String(game.get("start_state"))
	var racing: bool = state == "RACING"
	var finished: bool = bool(game.get("finished"))
	var dists: Array = game.get("distances")
	var times: Array = game.get("finish_times")
	var lead: float = 0.0
	var tail: float = INF
	var done: int = 0
	for i in range(dists.size()):
		var distance: float = float(dists[i])
		lead = maxf(lead, distance)
		tail = minf(tail, distance)
		if i < times.size() and float(times[i]) >= 0.0:
			done += 1
	# Scratch and tempo officials follow the same peloton clock as the HUD, not odometers.
	if int(game.get("race_mode")) in [0, 8] and racing:
		lead = float(game._last_lap_progress())
		tail = lead
	var length: float = float(int(game.get("race_laps"))) * official_lap_m
	if not official_new_model:
		if done > finished_seen:
			wave_timer = 7.0 if finished_seen == 0 else maxf(wave_timer, 2.5)
		finished_seen = done
		wave_timer = maxf(0.0, wave_timer - delta)
		var last_lap: bool = (racing or finished) and lead >= length - official_lap_m
		if not last_lap:
			finished_seen = 0
			_set_flag_state("hidden")
		elif wave_timer > 0.0:
			_set_flag_state("wave")
		else:
			_set_flag_state("ready")
		return

	if state in ["SETUP", "WAIT_STOP", "INTRO"]:
		if official_previous_racing or official_start_ready or official_start_fired or official_bell_active or official_finish_active or official_finish_completed:
			_official_reset()
		return

	# Start: during a neutral/flying lap the distance is measured to the
	# actual line. Standing starts cannot fire 5 m before the stationary grid;
	# those use the countdown and RACING transition instead.
	if not official_start_fired:
		if state in ["NEUTRAL", "RUN_UP"]:
			if lead >= official_lap_m - OFFICIAL_START_READY_M:
				_official_ready()
			if lead >= official_lap_m - OFFICIAL_START_SHOT_M:
				_official_fire()
		elif state == "COUNTDOWN":
			if float(game.get("countdown")) <= 1.0:
				_official_ready()
		elif racing:
			_official_fire()

	# Final approach always takes precedence over last-lap bell.
	# Race distance is measured from the start line after the neutral lap.
	var finish_approach: bool = (racing or finished) and length > 0.0 and lead >= length - OFFICIAL_FINISH_EARLY_M
	if finish_approach and not official_finish_active and not official_finish_completed:
		official_finish_active = true
		official_bell_active = false
		_official_play("VO_FinishFlag")
	if official_finish_active:
		if done >= dists.size() and not dists.is_empty():
			official_finish_active = false
			official_finish_completed = true
			_official_idle()
		elif official_action != "VO_FinishFlag":
			_official_play("VO_FinishFlag")
		official_finished_seen = done
		official_previous_racing = racing
		return

	var bell_line: float = length - official_lap_m
	var bell_approach: bool = (racing or finished) and length > official_lap_m and lead >= bell_line - OFFICIAL_BELL_EARLY_M and tail < bell_line and not official_finish_completed
	if bell_approach and not official_bell_active:
		official_bell_active = true
		_official_play("VO_LastLapBell")
	elif official_bell_active and not bell_approach:
		official_bell_active = false
		_official_idle()

	# Keep pistol ready during an approach; after firing return to idle once
	# the short non-looping start animation has completed.
	if not official_bell_active and not official_finish_active and official_action == "VO_StartFire" and flag_anim != null and not flag_anim.is_playing():
		_official_idle()
	official_previous_racing = racing
	official_finished_seen = done
