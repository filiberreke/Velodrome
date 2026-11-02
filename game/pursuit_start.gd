extends RefCounted
## Visual standing-start equipment, driven by the game's simulation clock.
const GATE: PackedScene = preload("res://assets/start_gate/pursuit_start_gate_with_helpers.glb")
const SHIRT_SHADER: Shader = preload("res://helper_team_shirt.gdshader")
const REAR_CONTACT := Vector3(0, 0, -0.40)
const CLEAR_AFTER := 2.2
var gates: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var released := false
var elapsed := 0.0

func clear() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			gate.hide()
			gate.queue_free()
	gates.clear()
	players.clear()
	released = false
	elapsed = 0.0

func surface_basis(game, distance: float, lane: float) -> Basis:
	var forward: Vector3 = game._direction(distance, lane)
	var across: Vector3 = (game._at(distance, lane + 0.05) - game._at(distance, lane - 0.05)).normalized()
	var up := forward.cross(across).normalized()
	if up.y < 0.0: up = -up
	return Basis(up.cross(forward).normalized(), up, forward).orthonormalized()

func support_weight(game, rider: int) -> float:
	if game.race_mode != 4 or game.finished: return 0.0
	if game.start_state in ["INTRO", "WAIT_STOP", "COUNTDOWN"]: return 1.0
	if game.start_state == "RACING": return clampf(1.0 - game.distances[rider] / 3.0, 0.0, 1.0)
	return 0.0

func align_rider(game, rider: int, pivot_distance: float, lift: float) -> void:
	var weight := support_weight(game, rider)
	if weight <= 0.0: return
	var bike: Node3D = game.bikes[rider]
	bike.basis = bike.basis.slerp(surface_basis(game, pivot_distance, game.lane_offsets[rider]), weight)
	bike.position.y -= lift * weight

func prepare(game) -> void:
	if game.race_mode != 4 or game.bikes.size() < 2: return
	if not gates.is_empty(): return
	for rider in range(2):
		var gate := GATE.instantiate() as Node3D
		gate.name = "PursuitStartGate%d" % rider
		game.add_child(gate)
		var distance: float = game._rider_distance(rider, 0.0) - game.FRONT_WHEEL_TIP_M
		var basis := surface_basis(game, distance, game.lane_offsets[rider])
		gate.transform = Transform3D(basis, game._at(distance, game.lane_offsets[rider]) + basis * REAR_CONTACT)
		var player := gate.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: StringName in player.get_animation_list():
			if String(clip).get_file() == "ReleaseAndWithdraw":
				player.play(clip)
				player.seek(0.0, true)
				player.advance(0.0)
				break
		gates.append(gate)
		players.append(player)
		apply_team_kit(game, rider, gate)

func apply_team_kit(game, rider: int, gate: Node3D) -> void:
	# Read the outfit actually worn, including player overrides and external PNGs.
	# Do not infer a country from the rider name or recolor shared GLB materials.
	var visual: Node = game.bikes[rider].get_child(0)
	var body := visual.get("body_mesh") as MeshInstance3D
	if body == null: return
	var color := Color("28456e")
	var atlas: Texture2D
	for surface in range(body.mesh.get_surface_count()):
		var source := body.mesh.surface_get_material(surface)
		if source == null or source.resource_name.to_lower() != "suit_kit": continue
		var active := body.get_active_material(surface)
		if active is StandardMaterial3D:
			color = active.albedo_color
			atlas = active.albedo_texture
		elif active is ShaderMaterial:
			atlas = active.get_shader_parameter("skinsuit_atlas") as Texture2D
		break
	var shirt := ShaderMaterial.new()
	shirt.shader = SHIRT_SHADER
	shirt.resource_name = "HelperTeamShirt%d" % rider
	shirt.set_shader_parameter("team_color", color)
	shirt.set_shader_parameter("team_atlas", atlas)
	shirt.set_shader_parameter("use_atlas", atlas != null)
	for mesh: MeshInstance3D in gate.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface)
			if source != null and source.resource_name.begins_with("Helper_Shirt_Atlas"):
				mesh.set_surface_override_material(surface, shirt)

func refresh_kits(game) -> void:
	for rider in range(gates.size()): apply_team_kit(game, rider, gates[rider])

func release(game) -> void:
	if game.race_mode != 4 or released: return
	prepare(game)
	released = true
	elapsed = 0.0

func update(game, dt: float) -> void:
	if game.race_mode != 4:
		if not gates.is_empty(): clear()
		return
	if game.start_state in ["INTRO", "WAIT_STOP", "COUNTDOWN"]:
		prepare(game)
	if not released: return
	elapsed += dt
	for player in players: player.advance(dt)
	if elapsed >= CLEAR_AFTER:
		for gate in gates: gate.hide()
