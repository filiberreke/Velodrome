class_name ShoulderPushLayer
extends SkeletonModifier3D
## Shoulder push ("schouderduwtje") as an ADDITIVE upper-body layer on top of whatever the rider is doing
## (cruise, seated sprint, standing sprint). Created by rider_visual.shoulder_push() /
## receive_shoulder_push(), removes itself when done, so riders without a push cost nothing.
##
## Clips (shoulder_push_anims.glb, built by assets/source_blender/contact/build_shoulder_push.py) hold, per
## upper-body bone, the rotation DELTA from the neutral riding pose. Per frame this modifier:
##   1. remembers where both wrists are (hands on the bars, from the pedalling clip),
##   2. multiplies the clip delta onto spine / chest / neck / head / clavicles / arms,
##   3. solves both arms (analytic two-bone IK, never stretches) back onto the remembered wrist positions
##      and restores the grip orientation, so the hands never leave the bars.
##
## Timing: the clip is 2.0 s. A different duration only changes the HOLD (the furthest point of the push);
## going out (0.30 s) and coming back stay exactly as fast as authored.

signal contact(side: String)             # The authored contact cue for a giver.
signal finished(role: String, side: String)

const GLB_PATH := "res://assets/riders/contact/shoulder_push_anims.glb"
const DEFAULT_DURATION := 2.0
const CLIP_LENGTH := 2.0
const HOLD_FROM := 0.70        # clip seconds: everything before plays 1:1 (push out, shove, brace)
const HOLD_TO := 1.45          # clip seconds: everything after plays 1:1 (release, return)
const MIN_DURATION := CLIP_LENGTH - (HOLD_TO - HOLD_FROM)
const CONTACT_TIME := 0.22
const KEYED_BONES: Array[String] = ["spine", "chest", "neck", "head", "clavicle.L", "clavicle.R",
	"upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"]

static var _clips: Dictionary = {}       # clip name -> Animation
static var _rest_inv: Dictionary = {}    # bone -> inverse rest rotation of the clip skeleton

var role: String = "give"               # "give" or "take"
var side: String = "L"                  # where the OTHER rider is, seen from this rider
var duration: float = DEFAULT_DURATION
var elapsed: float = 0.0
var done: bool = false
var paused: bool = false
var contact_emitted: bool = false

# measurements (for tests / tuning); valid after a modification pass
var last_wrist_error: Dictionary = {"L": 0.0, "R": 0.0}   # metres between wrist and its bar position after IK
var last_clamped: bool = false
var last_clip_time: float = 0.0
var last_chest_angle: float = 0.0       # degrees of the chest delta applied this frame

var _anim: Animation
var _tracks: Dictionary = {}            # bone index -> track index
var _arm: Dictionary = {}               # side -> [upper, fore, hand] bone indices

func setup(p_role: String, p_side: String, p_duration: float = DEFAULT_DURATION) -> bool:
	role = p_role
	side = p_side.to_upper()
	duration = maxf(p_duration, MIN_DURATION)
	if role not in ["give", "take"] or side not in ["L", "R"]:
		push_error("ShoulderPushLayer: role give/take and side L/R expected")
		return false
	if not load_clips():
		return false
	_anim = _clips.get(clip_name(role, side))
	return _anim != null

static func clip_name(p_role: String, p_side: String) -> String:
	return "push_%s_%s" % [p_role, p_side]

static func load_clips() -> bool:
	if not _clips.is_empty():
		return true
	var scene := load(GLB_PATH) as PackedScene
	if scene == null:
		push_error("ShoulderPushLayer: %s missing" % GLB_PATH)
		return false
	var inst := scene.instantiate()
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for b in KEYED_BONES:
		var i := sk.find_bone(b)
		_rest_inv[b] = sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse()
	if player != null:
		for n in player.get_animation_list():
			_clips[String(n)] = player.get_animation(n).duplicate()
	inst.free()
	return not _clips.is_empty()

## Elapsed seconds -> clip seconds. Only the hold stretches or shrinks.
func clip_time(t: float) -> float:
	var hold := duration - (CLIP_LENGTH - (HOLD_TO - HOLD_FROM))
	if t <= HOLD_FROM:
		return t
	if t <= HOLD_FROM + hold:
		return HOLD_FROM + (t - HOLD_FROM) * (HOLD_TO - HOLD_FROM) / maxf(hold, 0.0001)
	return minf(HOLD_TO + (t - HOLD_FROM - hold), CLIP_LENGTH)

func _ready() -> void:
	var sk := get_skeleton()
	if sk == null or _anim == null:
		return
	for i in _anim.get_track_count():
		if _anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(_anim.track_get_path(i).get_concatenated_subnames())
		if bone in KEYED_BONES:
			_tracks[sk.find_bone(bone)] = i
	for s in ["L", "R"]:
		_arm[s] = [sk.find_bone("upper_arm." + s), sk.find_bone("forearm." + s), sk.find_bone("hand." + s)]

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _anim == null or done:
		return
	if not paused:
		elapsed += delta
	if role == "give" and not contact_emitted and elapsed >= CONTACT_TIME:
		contact_emitted = true
		contact.emit.call_deferred(side)
	if elapsed >= duration:
		done = true
		finished.emit.call_deferred(role, side)
		queue_free.call_deferred()
		return
	var ct := clip_time(elapsed)
	last_clip_time = ct
	var grips := {}
	for s in ["L", "R"]:
		grips[s] = sk.get_bone_global_pose(_arm[s][2])
	for bone_idx in _tracks:
		var bname := sk.get_bone_name(bone_idx)
		var d: Quaternion = _rest_inv[bname] * _anim.rotation_track_interpolate(_tracks[bone_idx], ct)
		if bname == "chest":
			last_chest_angle = rad_to_deg(d.get_angle())
		sk.set_bone_pose_rotation(bone_idx, sk.get_bone_pose_rotation(bone_idx) * d)
	last_clamped = false
	for s in ["L", "R"]:
		var g: Transform3D = grips[s]
		_solve_arm(sk, _arm[s], g.origin)
		var h := sk.get_bone_global_pose(_arm[s][2])
		last_wrist_error[s] = (h.origin - g.origin).length()
		sk.set_bone_global_pose(_arm[s][2], Transform3D(g.basis, h.origin))   # keep the grip orientation

## Two-bone IK (upper arm -> forearm) putting the wrist on `wrist` (skeleton space). Keeps the bend plane of
## the incoming pose (so the elbow flare of the clip survives) and clamps to the arm length.
func _solve_arm(sk: Skeleton3D, bones: Array, wrist: Vector3) -> void:
	var ri: int = bones[0]
	var mi: int = bones[1]
	var ei: int = bones[2]
	for _i in 3:
		var a := sk.get_bone_global_pose(ri).origin
		var b := sk.get_bone_global_pose(mi).origin
		var c := sk.get_bone_global_pose(ei).origin
		var l1 := (b - a).length()
		var l2 := (c - b).length()
		var to_t := wrist - a
		var d_raw := to_t.length()
		if d_raw > l1 + l2 - 0.001:
			last_clamped = true
		var d := clampf(d_raw, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var u := to_t / maxf(d_raw, 0.0001)
		var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
		var pole := (b - a) - u * (b - a).dot(u)
		if pole.length() < 0.0001:
			return
		pole = pole.normalized()
		var b_new := a + u * along + pole * h
		var w_new := a + u * d
		var gr := sk.get_bone_global_pose(ri)
		sk.set_bone_global_pose(ri, Transform3D(Basis(_swing(b - a, b_new - a)) * gr.basis, a))
		var gm := sk.get_bone_global_pose(mi)
		sk.set_bone_global_pose(mi, Transform3D(Basis(_swing(gm.basis.y, w_new - b_new)) * gm.basis, b_new))

static func _swing(from: Vector3, to: Vector3) -> Quaternion:
	var f := from.normalized()
	var t := to.normalized()
	var dot := clampf(f.dot(t), -1.0, 1.0)
	var axis := f.cross(t)
	if dot > 0.99999 or axis.length() < 0.00001:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(), acos(dot))
