class_name MadisonPair
extends Node3D
## Prototype pair: two real rider_visual instances + shared HandContact + two MadisonRiderRig overlays.
## Giver rides at the origin, receiver on its right (-X) and `delta_f(t)` ahead (+Z), exactly as authored.
## Everything the animation shows is driven by the same state the HUD bar reads (sling_t).

var giver: Node3D
var recv: Node3D
var contact: Node3D
var rg: MadisonRiderRig
var rr: MadisonRiderRig
var gap: float = MadisonProfile.REF_GAP
var deviation: Vector3 = Vector3.ZERO        # extra receiver offset (x lateral, z longitudinal) = speed/steering difference
var sling_t: float = 0.0
var ik_weight: float = 1.0
var rpm: float = 70.0
var power: float = 250.0

func build(tree: SceneTree) -> void:
	if get_parent() == null:
		tree.root.add_child(self)
	giver = _make_rider(0)
	recv = _make_rider(2)
	contact = Node3D.new()
	contact.name = "HandContact"
	add_child(contact)
	await tree.process_frame
	rg = MadisonRiderRig.new()
	rr = MadisonRiderRig.new()
	add_child(rg)
	add_child(rr)
	rg.attach(giver, "giver", contact)
	rr.attach(recv, "receiver", contact)
	for r in [rg, rr]:
		r.overlay = 1.0
		r.mix_sling = 1.0

func _make_rider(index: int = 0) -> Node3D:
	var v: Node3D = load("res://rider_visual.gd").new()
	v.set_meta("rider_index", index)    # outfit colour (0 yellow, 2 blue)
	add_child(v)
	return v

## desired contact points in world space for the CURRENT placement (before any IK)
func desired_giver(t: float) -> Vector3:
	return giver.global_transform * MadisonProfile.contact_giver(t)

func desired_receiver(t: float) -> Vector3:
	return recv.global_transform * MadisonProfile.contact_receiver(t)

func place(t: float) -> void:
	giver.position = Vector3.ZERO
	recv.position = Vector3(-gap, 0.0, MadisonProfile.delta_f(t)) + deviation

## One simulation frame at 60 fps. Await it (modifier output is available after the idle frame).
func step(dt: float = 1.0 / 60.0) -> void:
	place(sling_t)
	for r in [rg, rr]:
		r.sling_t = sling_t
		r.ik_weight = ik_weight
	var t := sling_t
	contact.global_position = (desired_giver(t) + desired_receiver(t)) * 0.5
	giver.pedal(dt, rpm, power)
	recv.pedal(dt, rpm, power)
	await get_tree().process_frame

func errors_mm() -> Vector2:
	return Vector2((rg.anchor_world() - contact.global_position).length(),
			(rr.anchor_world() - contact.global_position).length()) * 1000.0

## shoulder -> wrist distance the IK asked for, as a fraction of the straight arm (1.0 = fully stretched)
func stretch() -> Vector2:
	return Vector2(rg.ik.last_required_reach / maxf(rg.ik.max_reach, 0.001),
			rr.ik.last_required_reach / maxf(rr.ik.max_reach, 0.001))
