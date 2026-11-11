class_name MadisonDemoExchange
extends Node
## One controller for BOTH riders of a Madison hand-sling.
## States: IDLE -> APPROACH -> GRAB -> SLING -> RELEASE -> SEPARATE -> IDLE.
## The game calls tick(delta) every frame BEFORE rider_visual.pedal() of the two riders, sets `a_held`
## (Advanced) and feeds the gameplay distances with set_gameplay(). The controller never moves a rider's gameplay
## position: it only (a) shifts the VISUAL model (child offset of rider_visual: `rig_scene`), (b) drives the animation
## variables the HUD reads, and (c) outputs speed / steering requests (`speed_*`, `outward_progress`).
## A player-receiver is never steered; a player-giver keeps his own steering as well.

enum State { IDLE, APPROACH, GRAB, SLING, RELEASE, SEPARATE }
enum Mode { EASY, ADVANCED }

signal approach_started
signal grab_window_opened
signal grabbed
signal grab_failed(reason: String)      # "too_far" | "too_early" | "missed"
signal sling_peak                        # sling_t crossed PEAK_T
signal released(efficiency: float)       # efficiency (0..1) at the release moment; also see release_reason
signal separated

const APPROACH_SECONDS := 1.0
const GRAB_WINDOW_FROM := 0.80          # approach_t at which the grab window opens (sweet spot = 1.0)
const GRAB_GRACE_SECONDS := 0.25        # window stays open this long after approach_t reached 1.0
const GRAB_SECONDS := 0.20
const SLING_RATE := 0.60                # sling_t per second -> peak (0.6) after 1.0 s of holding
const RELEASE_SECONDS := 0.75           # release_t sweep after the crossfade
const SEPARATE_SECONDS := 0.30
const ABORT_SECONDS := 0.40             # overlay fade after a failed grab
const MAX_GRAB_GAP := 1.80              # 3 lanes
const VISUAL_GAP_MAX := 1.40
const VISUAL_GAP_MIN := 1.00            # brief: >= 0.75; measured: IK needs >= ~0.95 m to keep the hands within 5 mm (folded arms below that)
const MAX_LEAN_DEG := 4.0
const STRETCH_EARLY_RELEASE := 0.94
const TRANSFER_MAX_MPS := 3.0           # speed gained by the receiver at efficiency 1
const GIVER_LOSS_FACTOR := 0.8
const TRANSFER_RAMP_SECONDS := 0.6
const OUTWARD_SECONDS := 1.5

var mode: Mode = Mode.EASY
var state: State = State.IDLE
var player_role: String = ""            # "giver" | "receiver" | "" (both AI)
var a_held: bool = false                # Advanced: A button state, set by the game every frame

# --- shared progress variables (animation AND HUD)
var approach_t: float = 0.0
var sling_t: float = 0.0
var release_t: float = 0.0
var efficiency: float = 0.0             # MadisonProfile.efficiency(sling_t) while grabbed
var lateral_gap: float = MadisonProfile.REF_GAP   # gameplay distance between the bike centre lines (m)
var grab_window_open: bool = false
var release_reason: String = ""         # "auto" | "player" | "max_hold" | "reach"
var visual_gap: float = MadisonProfile.REF_GAP

# --- outputs for the game
var speed_giver: float = 0.0            # requested speeds (m/s); game decides for the player
var speed_receiver: float = 0.0
var outward_progress: float = 0.0       # 0..1: AI giver steers outward (to above the blue line); never the player
var outward_role: String = ""

var giver: Node3D
var receiver: Node3D
var rig_g: MadisonRiderRig
var rig_r: MadisonRiderRig
var contact: Node3D
var target_g: Node3D
var target_r: Node3D

var _ahead: float = 0.0                  # gameplay: how far the receiver is ahead of the giver (m)
var _t_state: float = 0.0
var _grab_t: float = 0.0
var _xf: float = 0.2
var _a_prev: bool = false
var _peaked: bool = false
var _vis_k: float = 0.0
var _reach_frames: int = 0
var _window_announced: bool = false
var _post: bool = false
var _post_t: float = 0.0
var _speed_target_g: float = 0.0
var _speed_target_r: float = 0.0
var _speed_from_g: float = 0.0
var _speed_from_r: float = 0.0
var _abort: bool = false

## Start an exchange. giver = fast rider (left/inside), receiver = slower rider (right/outside); both rider_visual nodes.
func start(p_giver: Node3D, p_receiver: Node3D, p_mode: Mode = Mode.EASY, p_player_role: String = "",
		v_giver: float = 0.0, v_receiver: float = 0.0) -> bool:
	if state != State.IDLE:
		return false
	giver = p_giver
	receiver = p_receiver
	mode = p_mode
	player_role = p_player_role
	speed_giver = v_giver
	speed_receiver = v_receiver
	contact = Node3D.new()
	contact.name = "HandContact"
	target_g = Node3D.new()
	target_r = Node3D.new()
	add_child(contact)
	add_child(target_g)
	add_child(target_r)
	rig_g = MadisonRiderRig.new()
	rig_r = MadisonRiderRig.new()
	add_child(rig_g)
	add_child(rig_r)
	if not rig_g.attach(giver, "giver", target_g) or not rig_r.attach(receiver, "receiver", target_r):
		cancel()
		return false
	for r in [rig_g, rig_r]:
		r.overlay = 1.0
		r.mix_sling = 0.0
		r.mix_release = 0.0
		r.approach_t = 0.0
		r.sling_t = 0.0
		r.release_t = 0.0
		r.ik_weight = 0.0
	approach_t = 0.0
	sling_t = 0.0
	release_t = 0.0
	efficiency = 0.0
	_t_state = 0.0
	_grab_t = 0.0
	_peaked = false
	_abort = false
	_vis_k = 0.0
	_reach_frames = 0
	_window_announced = false
	grab_window_open = false
	release_reason = ""
	outward_progress = 0.0
	outward_role = ""
	_post = false
	state = State.APPROACH
	approach_started.emit()
	return true

## Gameplay distances, every frame: lateral bike-to-bike distance and how far the receiver is ahead of the giver.
func set_gameplay(gap_m: float, receiver_ahead_m: float) -> void:
	lateral_gap = gap_m
	_ahead = receiver_ahead_m

func ik_active_both() -> bool:
	return rig_g != null and is_instance_valid(rig_g) and rig_g.ik_weight > 0.99 and rig_r.ik_weight > 0.99

func is_active() -> bool:
	return state != State.IDLE

## Immediate clean-up (no animation) - e.g. race ended or exchange cancelled.
func cancel() -> void:
	_cleanup()
	state = State.IDLE
	grab_window_open = false

func tick(delta: float) -> void:
	var a_pressed := a_held and not _a_prev
	var a_released := _a_prev and not a_held
	_a_prev = a_held
	if state == State.IDLE:
		_tick_post(delta)
		return
	_t_state += delta
	match state:
		State.APPROACH:
			_tick_approach(delta, a_pressed)
		State.GRAB:
			_tick_grab(delta)
		State.SLING:
			_tick_sling(delta, a_released)
		State.RELEASE:
			_tick_release(delta)
		State.SEPARATE:
			_tick_separate(delta)
	if state != State.IDLE:
		_apply()
	_tick_post(delta)

# ------------------------------------------------------------------------------------------ states
func _tick_approach(delta: float, a_pressed: bool) -> void:
	approach_t = minf(approach_t + delta / APPROACH_SECONDS, 1.0)
	_vis_k = smoothstep(0.0, 1.0, approach_t)
	var was_open := grab_window_open
	grab_window_open = approach_t >= GRAB_WINDOW_FROM and lateral_gap <= MAX_GRAB_GAP
	if grab_window_open and not was_open:
		grab_window_opened.emit()
	if approach_t >= GRAB_WINDOW_FROM and lateral_gap > MAX_GRAB_GAP:
		_fail("too_far")
		return
	if mode == Mode.ADVANCED and a_pressed:
		if grab_window_open:
			_begin_grab()
		else:
			_fail("too_early")
		return
	if mode == Mode.EASY and grab_window_open and approach_t >= 0.95:
		_begin_grab()
		return
	if approach_t >= 1.0 and _t_state > APPROACH_SECONDS + GRAB_GRACE_SECONDS:
		_fail("missed")

func _begin_grab() -> void:
	state = State.GRAB
	_grab_t = 0.0
	grab_window_open = false

func _tick_grab(delta: float) -> void:
	_grab_t = minf(_grab_t + delta / GRAB_SECONDS, 1.0)
	_vis_k = 1.0
	if _grab_t >= 1.0:
		state = State.SLING
		sling_t = 0.0
		_peaked = false
		_t_state = 0.0
		_reach_frames = 0
		grabbed.emit()

func _tick_sling(delta: float, a_released: bool) -> void:
	_vis_k = 1.0
	var advancing := mode == Mode.EASY or a_held
	if advancing:
		sling_t = minf(sling_t + SLING_RATE * delta, 1.0)
	efficiency = MadisonProfile.efficiency(sling_t)
	if not _peaked and sling_t >= MadisonProfile.PEAK_T:
		_peaked = true
		sling_peak.emit()
	# gameplay distance drifted so far that the arm would have to stretch -> controlled early release
	var st := _stretch()
	_reach_frames = _reach_frames + 1 if st >= STRETCH_EARLY_RELEASE else 0
	if _reach_frames >= 2:
		_begin_release("reach")
	elif mode == Mode.EASY and sling_t >= MadisonProfile.PEAK_T:
		sling_t = MadisonProfile.PEAK_T
		_begin_release("auto")
	elif mode == Mode.ADVANCED and a_released:
		_begin_release("player")
	elif sling_t >= 1.0:
		_begin_release("max_hold")

func _begin_release(reason: String) -> void:
	release_reason = reason
	efficiency = MadisonProfile.efficiency(sling_t)
	state = State.RELEASE
	_t_state = 0.0
	_xf = MadisonProfile.release_crossfade_seconds(sling_t)
	var transfer := efficiency * TRANSFER_MAX_MPS
	_speed_from_g = speed_giver
	_speed_from_r = speed_receiver
	_speed_target_g = speed_giver - transfer * GIVER_LOSS_FACTOR
	_speed_target_r = speed_receiver + transfer
	_post = true
	_post_t = 0.0
	outward_role = "giver" if player_role != "giver" else ""    # slowed rider; never steered when it is the player
	released.emit(efficiency)

func _tick_release(delta: float) -> void:
	var total := _xf + RELEASE_SECONDS
	release_t = clampf((_t_state - _xf) / RELEASE_SECONDS, 0.0, 1.0)
	_vis_k = 1.0 - smoothstep(0.0, 1.0, _t_state / total)
	if _t_state >= total:
		state = State.SEPARATE
		_t_state = 0.0

func _tick_separate(delta: float) -> void:
	var dur := ABORT_SECONDS if _abort else SEPARATE_SECONDS
	_vis_k = 0.0 if not _abort else _vis_k
	if _abort:
		_vis_k = lerpf(_vis_k, 0.0, 0.1)
	if _t_state >= dur:
		_cleanup()
		state = State.IDLE
		separated.emit()

func _tick_post(delta: float) -> void:
	if not _post:
		return
	_post_t += delta
	var k := clampf(_post_t / TRANSFER_RAMP_SECONDS, 0.0, 1.0)
	speed_giver = lerpf(_speed_from_g, _speed_target_g, k)
	speed_receiver = lerpf(_speed_from_r, _speed_target_r, k)
	outward_progress = smoothstep(0.0, 1.0, _post_t / OUTWARD_SECONDS) if outward_role != "" else 0.0
	if _post_t >= maxf(TRANSFER_RAMP_SECONDS, OUTWARD_SECONDS):
		_post = false

func _fail(reason: String) -> void:
	grab_window_open = false
	_abort = true
	state = State.SEPARATE
	_t_state = 0.0
	grab_failed.emit(reason)

# ------------------------------------------------------------------------------------------ outputs to the rigs
func _apply() -> void:
	if rig_g == null or not is_instance_valid(rig_g):
		return
	_update_visual_offsets()
	var t_c := sling_t if state in [State.GRAB, State.SLING, State.RELEASE] else 0.0
	var cg: Vector3 = giver.get("rig_scene").global_transform * MadisonProfile.contact_giver(t_c)
	var cr: Vector3 = receiver.get("rig_scene").global_transform * MadisonProfile.contact_receiver(t_c)
	contact.global_position = (cg + cr) * 0.5
	var hd := Basis.IDENTITY
	var hd_g := (giver.get("rig_scene") as Node3D).global_basis * Vector3(-0.94, -0.15, 0.30).normalized()
	if state == State.APPROACH or (state == State.SEPARATE and _abort):
		target_g.global_position = contact.global_position - hd_g * MadisonProfile.REACH_SHORT
		target_r.global_position = contact.global_position + hd_g * MadisonProfile.REACH_SHORT
	else:
		target_g.global_position = contact.global_position
		target_r.global_position = contact.global_position
	var ik := 0.0
	var mix_s := 0.0
	var mix_r := 0.0
	var ov := 1.0
	match state:
		State.APPROACH:
			ik = smoothstep(0.0, 1.0, approach_t)
		State.GRAB:
			ik = smoothstep(0.0, 1.0, _grab_t)
			mix_s = ik
		State.SLING:
			ik = 1.0
			mix_s = 1.0
		State.RELEASE:
			mix_s = 1.0
			mix_r = smoothstep(0.0, 1.0, _t_state / _xf)
			ik = 1.0 - mix_r
		State.SEPARATE:
			mix_s = 0.0 if _abort else 1.0
			mix_r = 0.0 if _abort else 1.0
			var dur := ABORT_SECONDS if _abort else SEPARATE_SECONDS
			ov = 1.0 - smoothstep(0.0, 1.0, _t_state / dur)
			ik = (1.0 - smoothstep(0.0, 1.0, _t_state / dur)) if _abort else 0.0
	for r in [rig_g, rig_r]:
		r.approach_t = approach_t
		r.sling_t = sling_t
		r.release_t = release_t
		r.mix_sling = mix_s
		r.mix_release = mix_r
		r.overlay = ov
		r.ik_weight = ik

func _update_visual_offsets() -> void:
	# Visual model only: shift towards the partner above 1.40 m, outwards below 0.75 m, with a slight lean.
	visual_gap = clampf(lateral_gap, VISUAL_GAP_MIN, VISUAL_GAP_MAX)
	var d := (lateral_gap - visual_gap) * _vis_k
	var lean := deg_to_rad(MAX_LEAN_DEG) * clampf(absf(lateral_gap - visual_gap) / 0.4, 0.0, 1.0) * _vis_k * signf(lateral_gap - visual_gap)
	(giver.get("rig_scene") as Node3D).position.x = -d * 0.5
	(receiver.get("rig_scene") as Node3D).position.x = d * 0.5
	(giver.get("rig_scene") as Node3D).rotation.z = lean
	(receiver.get("rig_scene") as Node3D).rotation.z = -lean

## shoulder -> wrist distance the IK needs, as fraction of the straight arm (worst of both arms)
func _stretch() -> float:
	var a := rig_g.ik.last_required_reach / maxf(rig_g.ik.max_reach, 0.001)
	var b := rig_r.ik.last_required_reach / maxf(rig_r.ik.max_reach, 0.001)
	return maxf(a, b)

func _cleanup() -> void:
	for v in [giver, receiver]:
		if v != null and is_instance_valid(v):
			var rs := v.get("rig_scene") as Node3D
			if rs != null:
				rs.position.x = 0.0
				rs.rotation.z = 0.0
	for r in [rig_g, rig_r]:
		if r != null and is_instance_valid(r):
			r.detach()
			r.queue_free()
	for n in [contact, target_g, target_r]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	rig_g = null
	rig_r = null
