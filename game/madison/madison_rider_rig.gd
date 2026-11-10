class_name MadisonRiderRig
extends Node
## Temporary Madison overlay for ONE rider_visual (giver or receiver). Created when an exchange starts,
## freed after SEPARATE. Other riders never get this node, so they cost nothing extra.
##
## AnimationTree layout (all inputs are SEEKED, nothing plays by time -> no fixed duration):
##   pedal(crank phase) --\
##                         Blend2 "overlay" (filtered on the 12 upper-body bones, weight = overlay)
##   approach(approach_t) \                 /
##   sling(sling_t) ----- Blend2 "mix_sling"  -- Blend2 "mix_release" (release(release_t))
## IK: one analytic MadisonTwoBoneIK on the grab arm (upper_arm -> forearm -> hand + virtual end at the clasp point)
## aimed at the shared HandContact node; influence = ik weight (GRAB: 0 -> 1, RELEASE: 1 -> 0).

signal attached

var visual: Node3D
var role: String = "giver"
var animator: AnimationPlayer
var skeleton: Skeleton3D
var tree: AnimationTree
var ik: MadisonTwoBoneIK
var contact_node: Node3D
var hand_idx: int = -1
var active: bool = false

# Single source of truth for what the rider shows (the HUD reads the same sling_t / efficiency):
var approach_t: float = 0.0
var sling_t: float = 0.0
var release_t: float = 0.0
var mix_sling: float = 0.0       # 0 = approach pose, 1 = sling pose  (GRAB crossfade)
var mix_release: float = 0.0     # 0 = sling/approach pose, 1 = release clip (RELEASE crossfade)
var overlay: float = 0.0         # 0 = pure pedalling pose, 1 = Madison upper body (SEPARATE fades to 0)
var ik_weight: float = 0.0       # TwoBoneIK3D influence

var _pedal_clip: StringName = &""
var _pedal_node: AnimationNodeAnimation
static var _library: AnimationLibrary
var _modifier_mode: int

func attach(p_visual: Node3D, p_role: String, p_contact: Node3D) -> bool:
	visual = p_visual
	role = p_role
	contact_node = p_contact
	animator = visual.get("animator") as AnimationPlayer
	var rig_scene := visual.get("rig_scene") as Node3D
	if animator == null or rig_scene == null:
		push_error("MadisonRiderRig: rider_visual is not ready")
		return false
	skeleton = rig_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	_modifier_mode = skeleton.modifier_callback_mode_process
	if _library == null:
		_library = MadisonProfile.load_library()
	if _library == null or _library.get_animation_list().is_empty():
		push_error("MadisonRiderRig: madison_anims.glb library missing")
		return false
	if not animator.has_animation_library(MadisonProfile.LIBRARY_NAME):
		animator.add_animation_library(MadisonProfile.LIBRARY_NAME, _library)
	hand_idx = skeleton.find_bone("hand." + MadisonProfile.grab_side(role))
	_build_tree(rig_scene)
	_build_ik()
	visual.set("exchange_overlay", self)
	active = true
	attached.emit()
	return true

func _anim_node(clip_kind: String) -> StringName:
	return StringName("%s/%s" % [MadisonProfile.LIBRARY_NAME, MadisonProfile.clip_name(role, clip_kind)])

func _build_tree(rig_scene: Node3D) -> void:
	var bt := AnimationNodeBlendTree.new()
	_pedal_node = AnimationNodeAnimation.new()
	var poses: Array = visual.get("resolved_poses")
	_pedal_clip = poses[maxi(int(visual.get("current_pose")), 0)]
	_pedal_node.animation = _pedal_clip
	bt.add_node("pedal", _pedal_node)
	bt.add_node("pedal_seek", AnimationNodeTimeSeek.new())
	bt.connect_node("pedal_seek", 0, "pedal")
	for kind in ["approach", "sling", "release"]:
		var a := AnimationNodeAnimation.new()
		a.animation = _anim_node(kind)
		bt.add_node("a_" + kind, a)
		bt.add_node("s_" + kind, AnimationNodeTimeSeek.new())
		bt.connect_node("s_" + kind, 0, "a_" + kind)
	bt.add_node("mix_sling", AnimationNodeBlend2.new())
	bt.connect_node("mix_sling", 0, "s_approach")
	bt.connect_node("mix_sling", 1, "s_sling")
	bt.add_node("mix_release", AnimationNodeBlend2.new())
	bt.connect_node("mix_release", 0, "mix_sling")
	bt.connect_node("mix_release", 1, "s_release")
	var ov := AnimationNodeBlend2.new()
	ov.filter_enabled = true
	for b in MadisonProfile.KEYED_BONES:
		ov.set_filter_path(NodePath("RiderRig/Skeleton3D:" + b), true)
	bt.add_node("overlay", ov)
	bt.connect_node("overlay", 0, "pedal_seek")
	bt.connect_node("overlay", 1, "mix_release")
	bt.connect_node("output", 0, "overlay")
	tree = AnimationTree.new()
	tree.name = "MadisonTree"
	tree.tree_root = bt
	rig_scene.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(animator)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true

func _build_ik() -> void:
	var side := MadisonProfile.grab_side(role)
	ik = MadisonTwoBoneIK.new()
	ik.name = "MadisonHandIK"
	ik.root_bone = StringName("upper_arm." + side)
	ik.middle_bone = StringName("forearm." + side)
	ik.end_bone = StringName("hand." + side)
	ik.anchor_length = MadisonProfile.HAND_ANCHOR
	ik.target = contact_node
	ik.influence = 0.0
	skeleton.add_child(ik)
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL

## Called by rider_visual.pedal() every frame while attached (instead of its own animator.advance).
func drive(cadence_phase: float, pedal_clip: StringName) -> void:
	if not active:
		return
	if pedal_clip != _pedal_clip:
		_pedal_clip = pedal_clip
		_pedal_node.animation = pedal_clip
	var pa := animator.get_animation(_pedal_clip)
	tree.set("parameters/pedal_seek/seek_request", (cadence_phase / TAU) * pa.length)
	tree.set("parameters/s_approach/seek_request", approach_t * animator.get_animation(_anim_node("approach")).length)
	tree.set("parameters/s_sling/seek_request", sling_t * animator.get_animation(_anim_node("sling")).length)
	tree.set("parameters/s_release/seek_request", release_t * animator.get_animation(_anim_node("release")).length)
	tree.set("parameters/mix_sling/blend_amount", mix_sling)
	tree.set("parameters/mix_release/blend_amount", mix_release)
	tree.set("parameters/overlay/blend_amount", overlay)
	ik.influence = ik_weight
	ik.active = ik_weight > 0.0001
	if not ik.active:
		ik.last_applied = false
	tree.advance(0.0)
	skeleton.advance(1.0 / 60.0)

## World position of the clasp point of the grab hand. After IK this is only valid once the skeleton has done
## its deferred modifier update, i.e. after the next `await process_frame` (the modifier records the result).
func anchor_world() -> Vector3:
	if ik != null and ik.last_applied and ik_weight > 0.0001:
		return ik.last_anchor_world
	var pose := skeleton.get_bone_global_pose(hand_idx)
	return skeleton.global_transform * (pose * Vector3(0.0, MadisonProfile.HAND_ANCHOR, 0.0))

## Remove everything; the rider returns to the plain AnimationPlayer flow.
func detach() -> void:
	active = false
	if is_instance_valid(visual):
		visual.set("exchange_overlay", null)
	if is_instance_valid(tree):
		tree.active = false
		tree.queue_free()
	if is_instance_valid(ik):
		ik.active = false
		ik.queue_free()
	if is_instance_valid(skeleton): skeleton.modifier_callback_mode_process = _modifier_mode
	if is_instance_valid(animator) and animator.has_animation_library(MadisonProfile.LIBRARY_NAME):
		animator.remove_animation_library(MadisonProfile.LIBRARY_NAME)
	if is_instance_valid(visual) and visual.has_method("resume_riding"):
		visual.call("resume_riding")
