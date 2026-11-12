extends Node
## Rendering adapter only. Input, scoring, phases and impulses remain in madison_exchange.gd.
signal reach_limit
const Profile := preload("res://madison/madison_profile.gd")
const RiderRig := preload("res://madison/madison_rider_rig.gd")
var giver: Node3D
var receiver: Node3D
var rig_g
var rig_r
var contact: Node3D
var target_g: Node3D
var target_r: Node3D
var _base_positions: Array[Vector3] = []
var _base_rotations: Array[Vector3] = []
var _last_phase := ""
var _approach_pose := 0.0
var _overlay := 0.0
var _reach_frames := 0
var _reach_sent := false
var _separate: Dictionary = {}

func clear() -> void:
	for i in range(2):
		var visual: Node3D = giver if i == 0 else receiver
		if is_instance_valid(visual) and is_instance_valid(visual.rig_scene) and _base_positions.size() == 2:
			visual.rig_scene.position = _base_positions[i]
			visual.rig_scene.rotation = _base_rotations[i]
	for rig in [rig_g, rig_r]:
		if is_instance_valid(rig):
			rig.detach()
			rig.queue_free()
	for node in [contact, target_g, target_r]:
		if is_instance_valid(node): node.queue_free()
	giver = null; receiver = null; rig_g = null; rig_r = null
	contact = null; target_g = null; target_r = null
	_base_positions.clear()
	_base_rotations.clear()
	_last_phase = ""; _approach_pose = 0.0; _overlay = 0.0
	_reach_frames = 0; _reach_sent = false; _separate.clear()

func _exit_tree() -> void:
	clear()

func _attach(g: Node3D, r: Node3D) -> bool:
	clear()
	giver = g; receiver = r
	_base_positions.assign([giver.rig_scene.position, receiver.rig_scene.position])
	_base_rotations.assign([giver.rig_scene.rotation, receiver.rig_scene.rotation])
	contact = Node3D.new(); contact.name = "MadisonHandContact"; add_child(contact)
	target_g = Node3D.new(); add_child(target_g)
	target_r = Node3D.new(); add_child(target_r)
	rig_g = RiderRig.new(); add_child(rig_g)
	rig_r = RiderRig.new(); add_child(rig_r)
	if not rig_g.attach(giver, "giver", target_g) or not rig_r.attach(receiver, "receiver", target_r):
		clear()
		return false
	return true

func update_pair(game, dt: float) -> void:
	var state: Dictionary = game.madison.parameters()
	if not state.active or game.finished or game.race_mode != 6:
		if is_instance_valid(rig_g): clear()
		return
	if game.bikes.size() < 2: return
	var g: Node3D = game.bikes[int(state.giver)].get_child(0)
	var r: Node3D = game.bikes[int(state.receiver)].get_child(0)
	if giver != g or receiver != r or not is_instance_valid(rig_g):
		if not _attach(g, r): return
	var phase: String = state.phase
	if phase == "SEPARATE" and _last_phase != phase:
		_separate = {"mix_sling":rig_g.mix_sling, "mix_release":rig_g.mix_release,
			"release_t":rig_g.release_t, "ik":rig_g.ik_weight, "overlay":rig_g.overlay}
	_adjust_models(phase, dt)
	var mix_s := 0.0
	var mix_r := 0.0
	var release_t := 0.0
	var ik := 0.0
	var opening := 0.0
	_overlay = move_toward(_overlay, 1.0, maxf(dt, 0.0) * 5.0)
	match phase:
		"APPROACH":
			_approach_pose = move_toward(_approach_pose, clampf(float(state.approach_t) / 0.8, 0.0, 1.0), maxf(dt, 0.0) * 2.0)
			ik = smoothstep(0.0, 1.0, _approach_pose)
			opening = Profile.REACH_SHORT
		"GRAB":
			_approach_pose = 1.0
			mix_s = smoothstep(0.0, 1.0, float(state.phase_t))
			ik = 1.0
			opening = Profile.REACH_SHORT * (1.0 - mix_s)
		"SLING":
			_approach_pose = 1.0; mix_s = 1.0; ik = 1.0
		"RELEASE":
			mix_s = 1.0
			var crossfade: float = Profile.release_crossfade_seconds(float(state.sling_t))
			mix_r = smoothstep(0.0, 1.0, float(state.phase_seconds) / crossfade)
			ik = 1.0 - mix_r
			release_t = clampf((float(state.phase_seconds) - crossfade) / 0.75, 0.0, 1.0)
		"SEPARATE":
			var fade: float = 1.0 - smoothstep(0.0, 1.0, float(state.phase_t))
			mix_s = float(_separate.get("mix_sling", 0.0))
			mix_r = float(_separate.get("mix_release", 0.0))
			release_t = float(_separate.get("release_t", 0.0))
			ik = float(_separate.get("ik", 0.0)) * fade
			_overlay = float(_separate.get("overlay", 0.0)) * fade
	var t: float = float(state.sling_t)
	contact.global_position = (giver.rig_scene.global_transform * Profile.contact_giver(t) + receiver.rig_scene.global_transform * Profile.contact_receiver(t)) * 0.5
	var hand_direction: Vector3 = (giver.rig_scene.global_basis * Vector3(-0.94, -0.15, 0.30)).normalized()
	target_g.global_position = contact.global_position - hand_direction * opening
	target_r.global_position = contact.global_position + hand_direction * opening
	for rig in [rig_g, rig_r]:
		rig.approach_t = _approach_pose
		rig.sling_t = t
		rig.release_t = release_t
		rig.mix_sling = mix_s
		rig.mix_release = mix_r
		rig.overlay = _overlay
		rig.ik_weight = ik
	game.madison.contact_point = contact.global_position
	if phase == "SLING" and not _reach_sent:
		var stretching := false
		for rig in [rig_g, rig_r]:
			if rig.ik.last_applied and rig.ik.max_reach > 0.0 and rig.ik.last_required_reach / rig.ik.max_reach >= 0.94: stretching = true
		_reach_frames = _reach_frames + 1 if stretching else 0
		if _reach_frames >= 2:
			_reach_sent = true
			reach_limit.emit()
	_last_phase = phase

func _adjust_models(phase: String, dt: float) -> void:
	# Main already converges the bike visuals. This only corrects the remaining
	# model gap (including the 0.60 -> 1.00 m case), never a gameplay coordinate.
	var a: Vector3 = giver.to_global(_base_positions[0])
	var b: Vector3 = receiver.to_global(_base_positions[1])
	var forward: Vector3 = (giver.global_basis.z + receiver.global_basis.z).normalized()
	var side: Vector3 = b - a
	side -= forward * side.dot(forward)
	var distance: float = side.length()
	var direction: Vector3 = side / maxf(distance, 0.001)
	var correction := 0.0
	if phase in ["APPROACH", "GRAB", "SLING"]: correction = clampf((distance - clampf(distance, 1.0, 1.4)) * 0.5, -0.2, 0.2)
	for i in range(2):
		var visual: Node3D = giver if i == 0 else receiver
		var offset: Vector3 = visual.global_basis.inverse() * direction * correction * (1.0 if i == 0 else -1.0)
		visual.rig_scene.position = visual.rig_scene.position.move_toward(_base_positions[i] + offset, maxf(dt, 0.0) * 0.65)
		var lean: float = deg_to_rad(4.0) * clampf(absf(correction) / 0.2, 0.0, 1.0) * signf(correction) * (1.0 if i == 0 else -1.0)
		visual.rig_scene.rotation.z = move_toward(visual.rig_scene.rotation.z, _base_rotations[i].z + lean, deg_to_rad(20.0) * maxf(dt, 0.0))
