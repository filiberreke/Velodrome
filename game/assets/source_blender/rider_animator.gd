# rider_animator.gd — hang aan de root van de geïmporteerde velodrome_rider.glb scene (Godot 4.x)
extends Node3D

const BASE_CADENCE := 60.0     # animaties zijn 1 crankomwenteling per seconde = 60 rpm
const BLEND_TIME := 0.25

@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var rider_mesh: MeshInstance3D = find_child("Rider", true, false)

const BODY_SHAPES := ["ShoulderWidth", "TorsoMass", "HipWidth", "ThighMass", "CalfMass", "ArmMass"]
var current := ""

func _ready() -> void:
	for a in ["cruise_loop", "sprint_seated_loop", "sprint_standing_loop"]:
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	update_rider(150.0, 90.0)

## Roep elke frame (of bij elke vermogensupdate) aan.
func update_rider(watts: float, cadence_rpm: float) -> void:
	var target := "cruise_loop"
	if watts > 800.0:
		target = "sprint_standing_loop"
	elif watts > 300.0:
		target = "sprint_seated_loop"
	if target != current:
		# alle loops zijn even lang, dus we houden de crankfase vast bij het wisselen
		var phase := anim.current_animation_position if current != "" else 0.0
		anim.play(target, BLEND_TIME)
		anim.seek(phase, true)
		current = target
	anim.speed_scale = maxf(cadence_rpm, 1.0) / BASE_CADENCE

## Lichaamsbouw instellen: waarde -1.0 (slanker) tot 1.0 (voller), 0.0 = standaard.
## Voorbeeld: set_body_shape("ThighMass", 0.8)
func set_body_shape(shape_name: String, value: float) -> void:
	var idx := rider_mesh.find_blend_shape_by_name(shape_name)
	if idx >= 0:
		rider_mesh.set_blend_shape_value(idx, clampf(value, -1.0, 1.0))

## Alle zes tegelijk, bv. voor een sprinter of een duurrenner.
func set_body(values: Dictionary) -> void:
	for k in values:
		set_body_shape(k, values[k])
