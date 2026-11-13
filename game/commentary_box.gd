extends RefCounted
## Static broadcast suite, anchored to the real finish reference and tier-2 deck.
const MODEL_PATH := "res://assets/broadcast/euromax_cycling_box.glb"
const FINISH_S := 0.0
const OFFSET := 27.83
const RESERVED_HALF_WIDTH := 3.30
const RESERVED_HALF_DEPTH := 1.95

static func placement(arena: Node3D) -> Transform3D:
	var inward: Vector3 = -arena.call("_outward", FINISH_S)
	var frame := Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	var tier: Dictionary = arena.TIERS[1]
	var deck_height: float = float(tier["base"]) + float(tier["rows"] - 1) * float(tier["rise"])
	var origin: Vector3 = arena.call("_stadium_point", FINISH_S, OFFSET, deck_height + 0.10)
	return Transform3D(frame, origin)

static func reserves_seat(arena: Node3D, tier: int, s: float, offset: float) -> bool:
	if tier != 1:
		return false
	var floor_point: Vector3 = arena.call("_stadium_point", s, offset, 0.0)
	var local: Vector3 = placement(arena).affine_inverse() * floor_point
	return absf(local.x) < RESERVED_HALF_WIDTH and absf(local.z) < RESERVED_HALF_DEPTH

static func build(arena: Node3D) -> Node3D:
	var suite := preload("res://commentary_box_controller.gd").new()
	suite.name = "EuroMaxCyclingCommentaryBox"
	suite.transform = placement(arena)
	arena.add_child(suite)
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	model.name = "BroadcastSuite"
	suite.add_child(model)
	suite.setup(model)
	# Compatibility renderer: two tightly bounded, shadowless practical lights.
	# The exported ceiling diffusers and channel signs are emissive as well.
	for x in [-1.20, 1.20]:
		var light := OmniLight3D.new()
		light.name = "CabinPractical"
		light.position = Vector3(x, 2.45, 0.25)
		light.light_color = Color("ffe5c5")
		light.light_energy = 1.20
		light.omni_range = 3.15
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		suite.add_child(light)
	suite.set_meta("channel", "EuroMaxCycling")
	suite.set_meta("finish_distance_m", FINISH_S)
	suite.set_meta("tier", 2)
	return suite
