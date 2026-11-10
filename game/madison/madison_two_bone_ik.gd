class_name MadisonTwoBoneIK
extends SkeletonModifier3D
## Analytic two-bone IK (upper_arm -> forearm) for the Madison grab arm, as a SkeletonModifier3D.
##
## Why not TwoBoneIK3D? In Godot 4.7.2 (GL Compatibility, headless and windowed) a configured TwoBoneIK3D
## emitted modification_processed but never changed any bone pose or rendered pixel (also CCDIK3D / FABRIK3D /
## JacobianIK3D), and the classes are undocumented. See docs/madison/RIG_ANALYSE.md. This solver is small,
## deterministic and CLAMPS to the arm reach: it never stretches a bone.
##
## The effector is a virtual point `anchor_length` metres along the end (hand) bone's +Y axis (the clasp
## point). The elbow keeps the bend plane of the incoming animation pose, so the arm bends the way the
## baked clip bends it. `influence` (SkeletonModifier3D) blends from the animated pose (0) to the IK pose (1).

@export var root_bone: StringName = &"upper_arm.R"
@export var middle_bone: StringName = &"forearm.R"
@export var end_bone: StringName = &"hand.R"
@export var anchor_length: float = 0.11
## world-space point the clasp point must reach (shared HandContact)
@export var target: Node3D
@export var iterations: int = 6

var last_error: float = 0.0          # metres between clasp point and target after the solve (0 when reached)
var last_clamped: bool = false       # true when the target was beyond the arm's reach (arm fully straight)
var last_required_reach: float = 0.0 # shoulder -> wrist distance the target asked for (m)
var max_reach: float = 0.0           # |upper arm| + |forearm| (m)
## World position of the clasp point AFTER the solve. Godot applies modifier output to the skin at the deferred
## skeleton update and restores the animated pose afterwards, so Skeleton3D.get_bone_global_pose() does not show it.
var last_anchor_world: Vector3 = Vector3.ZERO
var last_applied: bool = false

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	last_applied = false
	if sk == null or target == null or not is_instance_valid(target) or influence <= 0.0001:
		return
	var ri := sk.find_bone(root_bone)
	var mi := sk.find_bone(middle_bone)
	var ei := sk.find_bone(end_bone)
	if ri < 0 or mi < 0 or ei < 0:
		return
	var orig_r := sk.get_bone_pose_rotation(ri)
	var orig_m := sk.get_bone_pose_rotation(mi)
	var t_sk := sk.global_transform.affine_inverse() * target.global_position   # target in skeleton space
	for _i in range(maxi(iterations, 1)):
		var gr := sk.get_bone_global_pose(ri)
		var gm := sk.get_bone_global_pose(mi)
		var ge := sk.get_bone_global_pose(ei)
		var a := gr.origin
		var b := gm.origin
		var c := ge.origin
		var l1 := (b - a).length()
		var l2 := (c - b).length()
		max_reach = l1 + l2
		var hand_dir := ge.basis.y.normalized()
		var w_t := t_sk - hand_dir * anchor_length                 # wrist position that puts the anchor on target
		var to_t := w_t - a
		var d_raw := to_t.length()
		last_required_reach = d_raw
		last_clamped = d_raw > l1 + l2 - 0.001
		var d := clampf(d_raw, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var u := to_t / maxf(d_raw, 0.0001)
		var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
		var pole := (b - a) - u * (b - a).dot(u)
		pole = pole.normalized() if pole.length() > 0.0001 else gm.basis.x.normalized()
		var b_new := a + u * along + pole * h
		var w_new := a + u * d
		# 1. rotate upper arm so its axis points at the new elbow
		var q1 := _swing(b - a, b_new - a)
		var gr_new := Transform3D(Basis(q1) * gr.basis, a)
		sk.set_bone_global_pose(ri, gr_new)
		# 2. forearm: follows the parent, then rotate its axis to the new wrist
		var gm2 := sk.get_bone_global_pose(mi)
		var q2 := _swing(gm2.basis.y, w_new - b_new)
		sk.set_bone_global_pose(mi, Transform3D(Basis(q2) * gm2.basis, b_new))
	# measure + blend with the animated pose
	var ge2 := sk.get_bone_global_pose(ei)
	var anchor_sk := ge2.origin + ge2.basis.y.normalized() * anchor_length
	last_error = (anchor_sk - t_sk).length()
	if influence < 0.9999:
		sk.set_bone_pose_rotation(ri, orig_r.slerp(sk.get_bone_pose_rotation(ri), influence))
		sk.set_bone_pose_rotation(mi, orig_m.slerp(sk.get_bone_pose_rotation(mi), influence))
	var ge3 := sk.get_bone_global_pose(ei)
	last_anchor_world = sk.global_transform * (ge3.origin + ge3.basis.y.normalized() * anchor_length)
	last_applied = true

static func _swing(from: Vector3, to: Vector3) -> Quaternion:
	var f := from.normalized()
	var t := to.normalized()
	var dot := clampf(f.dot(t), -1.0, 1.0)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	var axis := f.cross(t)
	if axis.length() < 0.00001:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(), acos(dot))
