extends RefCounted
## Track offsets are metres measured outward from the inner riding edge.
const FENCE_OFFSET := -2.45
const BOX_X := -12.60
const GATE_Z := [-20.0, -10.0, 0.0, 10.0, 20.0]
const GATE_HALF_WIDTH := 0.65

static func coach_gate(p: Vector3, margin: float = 0.0) -> bool:
	if p.x > -10.0: return false
	for z in GATE_Z:
		if absf(p.z - z) < GATE_HALF_WIDTH + margin: return true
	return false

static func inset(p: Vector3) -> float:
	return 18.0 - Vector2(p.x, maxf(absf(p.z) - (250.0 - TAU * 18.0) / 4.0, 0.0)).length()
