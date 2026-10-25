extends RefCounted
## Frozen visual snapshot at the first wheel crossing; official team timing is separate.
const LIVE_LAYER := 1 << 18
const PHOTO_LAYER := 1 << 19
var snapshot: Node3D
var hidden_geometry: Array[Dictionary] = []
var saved_main_mask := 0
var saved_photo_mask := 0
var captured_front := 0.0
var captured_at := -1.0
var captured_count := 0

func clear(game: Node3D) -> void:
	for entry in hidden_geometry:
		if is_instance_valid(entry["node"]): entry["node"].layers = entry["layers"]
	hidden_geometry.clear()
	if saved_main_mask != 0 and is_instance_valid(game.camera): game.camera.cull_mask = saved_main_mask
	if saved_photo_mask != 0 and is_instance_valid(game.finish_photo_camera): game.finish_photo_camera.cull_mask = saved_photo_mask
	saved_main_mask = 0; saved_photo_mask = 0
	if is_instance_valid(snapshot): snapshot.free()
	snapshot = null

func _geometry(node: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(_geometry(child))
	return result

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is AnimationPlayer: node.active = false
	for child in node.get_children(): _freeze(child)

func capture(game: Node3D, front: float, offsets: Array[float], lanes: Array[float], seconds: float) -> void:
	if game.finish_photo_viewport == null or game.bikes.size() < game.team_size: return
	clear(game)
	captured_front = front; captured_at = seconds; captured_count = game.team_size
	saved_main_mask = game.camera.cull_mask
	saved_photo_mask = game.finish_photo_camera.cull_mask
	game.camera.cull_mask &= ~PHOTO_LAYER
	game.finish_photo_camera.cull_mask = (saved_photo_mask & ~LIVE_LAYER) | PHOTO_LAYER
	# Live riders keep rendering in the race camera, while the photo sees only clones.
	for bike in game.bikes:
		for geometry in _geometry(bike):
			hidden_geometry.append({"node": geometry, "layers": geometry.layers})
			geometry.layers = LIVE_LAYER
	snapshot = Node3D.new()
	snapshot.name = "TeamFinishSnapshot"
	game.add_child(snapshot)
	var corners: Array[Vector3] = []
	for i in range(game.team_size):
		var clone: Node3D = game.bikes[i].duplicate(0)
		_freeze(clone)
		snapshot.add_child(clone)
		clone.visible = true # Includes the player hidden by a handlebar camera.
		var lane: float = lerpf(game.LANES[0], game.LANES[2], lanes[i])
		var distance: float = game._rider_distance(i, front + offsets[i])
		clone.position = game._at(distance - game.FRONT_WHEEL_TIP_M, lane) + Vector3.UP * (0.085 + 0.18 * absf(sin(game.visual_rolls[i])))
		var tangent: Vector3 = game._direction(distance, lane)
		clone.rotation = Vector3(0.0, atan2(tangent.x, tangent.z), game.visual_rolls[i])
		for geometry in _geometry(clone):
			geometry.layers = PHOTO_LAYER
			if geometry is MeshInstance3D:
				var box: AABB = geometry.get_aabb()
				for j in range(8): corners.append(geometry.global_transform * box.get_endpoint(j))
	if corners.is_empty():
		clear(game)
		return
	var minimum: Vector3 = corners[0]
	var maximum: Vector3 = corners[0]
	for point in corners:
		minimum = minimum.min(point); maximum = maximum.max(point)
	var center := (minimum + maximum) * 0.5
	var line: float = game._rider_distance(0, game._race_length())
	var outward: Vector3 = game._at(line, 2.0) - game._at(line, 1.0)
	outward.y = 0.0; outward = outward.normalized()
	var camera: Camera3D = game.finish_photo_camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.global_position = center + outward * 12.0 + Vector3.UP * 3.0
	camera.look_at(center, Vector3.UP)
	var horizontal := 0.0
	var vertical := 0.0
	for point in corners:
		var local: Vector3 = camera.global_transform.affine_inverse() * point
		horizontal = maxf(horizontal, absf(local.x))
		vertical = maxf(vertical, absf(local.y))
	var aspect := float(game.finish_photo_viewport.size.x) / float(game.finish_photo_viewport.size.y)
	camera.size = maxf(4.0, maxf(2.0 * horizontal / aspect, 2.0 * vertical) + 2.0)
	game.finish_photo_taken = true
	game.finish_photo_rider = 0
	game.finish_photo_caption.text = "FINISHFOTO · JOUW PLOEG · EERSTE RENNER · %.2f s" % seconds
	game.finish_photo_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not game.finish_photo_capture_pending:
		game.finish_photo_capture_pending = true
		RenderingServer.frame_post_draw.connect(game._grab_finish_photo, CONNECT_ONE_SHOT)
