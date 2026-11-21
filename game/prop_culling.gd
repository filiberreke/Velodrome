extends RefCounted
## Distance culling for tiny static props. Each separate mesh costs a draw call,
## even when it covers less than a pixel: a 1.2 cm festoon cable is about 0.4 px
## wide at 20 m, a 0.5 m bidon or cup about 12 px at 30 m (1080p, 72 degree FOV).
## Larger props, people and MultiMesh crowds keep their own settings.
const THIN_SIDE_M := 0.03 # Both small sides of a cable or rod.
const THIN_MAX_DIAGONAL_M := 3.0
const THIN_END_M := 20.0
const SMALL_DIAGONAL_M := 0.5
const SMALL_END_M := 30.0
const MARGIN_M := 2.0

static func range_for(node: MeshInstance3D) -> float:
	if node.mesh == null or node.visibility_range_begin > 0.0 or node.visibility_range_end > 0.0:
		return 0.0
	var scaled: Vector3 = node.get_aabb().size * node.global_transform.basis.get_scale()
	var sides := [absf(scaled.x), absf(scaled.y), absf(scaled.z)]
	sides.sort()
	var diagonal: float = scaled.length()
	# A cable has two small sides; a flat sign or banner has only one.
	if sides[1] <= THIN_SIDE_M and diagonal <= THIN_MAX_DIAGONAL_M:
		return THIN_END_M
	if diagonal <= SMALL_DIAGONAL_M:
		return SMALL_END_M
	return 0.0

static func apply(root: Node) -> int:
	var count := 0
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var node := found as MeshInstance3D
		var end := range_for(node)
		if end <= 0.0:
			continue
		node.visibility_range_end = end
		node.visibility_range_end_margin = MARGIN_M
		count += 1
	return count
