extends Node
## Physics interpolation draws moving nodes between two 60 Hz physics ticks, so
## riders and cameras move evenly at any frame rate. A deliberate jump (camera
## cut, restart, results view) must not be drawn as a fast glide: after the game
## has moved everything in a tick, reset nodes whose pose jumped.
const JUMP_M := 3.0
const TURN_RAD := 0.6 # About 35 degrees in one tick.
const GROUP := "interpolated_movers"
var game: Node
var _last := {}

func setup(owner_game: Node) -> void:
	game = owner_game
	name = "InterpolatieBewaking"
	process_physics_priority = 1000 # After the game's own physics step.

func watched() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is Node3D: nodes.append(node)
	for environment_name in ["training_environment", "piste_training"]:
		var environment: Variant = game.get(environment_name)
		if environment is Node3D and environment.get("active"):
			for node in environment.get_children():
				if node is Node3D: nodes.append(node)
	return nodes

## Opt a node (and its children) into interpolation and jump detection.
static func interpolate(node: Node) -> Node:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	node.add_to_group(GROUP)
	return node

func _physics_process(_delta: float) -> void:
	if game == null: return
	var seen := {}
	for node in watched():
		if not is_instance_valid(node) or not node.is_inside_tree(): continue
		var id := node.get_instance_id()
		var pose: Transform3D = node.global_transform
		seen[id] = pose
		if _last.has(id) and jumped(_last[id], pose):
			node.reset_physics_interpolation()
	_last = seen

static func jumped(before: Transform3D, after: Transform3D) -> bool:
	if before.origin.distance_to(after.origin) > JUMP_M:
		return true
	var turn: Quaternion = before.basis.get_rotation_quaternion().inverse() * after.basis.get_rotation_quaternion()
	return 2.0 * acos(clampf(absf(turn.w), 0.0, 1.0)) > TURN_RAD
