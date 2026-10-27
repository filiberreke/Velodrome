extends RefCounted
## Deterministic single-file relay. The player's effort controls the shared train.
const GAP := 2.5
const OUT_SECONDS := 0.9
const DROP_MPS := 1.8
const IN_SECONDS := 0.9
var size := 3
var player := 0
var order: Array[int] = []
var offsets: Array[float] = []
var lanes: Array[float] = []
var turn_seconds := 0.0
var turn_energy := 0.0
var copied_seconds := 20.0
var copied_watts := 300.0
var rotation := -1
var phase := ""
var phase_seconds := 0.0
var reference_power := 0.0
var has_player_pull := false
var leader_power := 0.0
var required_watts := 0.0
var exchanges := 0
var position_factors: Array[float] = [1.0, 0.8, 0.5, 0.4]

func configure_factors(values: Array[float]) -> void:
	position_factors = values.duplicate()

func reset(count: int, controlled_player: int = 0) -> void:
	size = clampi(count, 3, 4)
	position_factors.assign([1.0, 0.8, 0.5] if size == 3 else [1.0, 0.8, 0.6, 0.4])
	player = controlled_player
	order.clear(); offsets.clear(); lanes.clear()
	for i in range(size):
		order.append(i); offsets.append(-float(i) * GAP); lanes.append(0.0)
	turn_seconds = 0.0; turn_energy = 0.0
	copied_seconds = 20.0; copied_watts = 300.0
	rotation = -1; phase = ""; phase_seconds = 0.0
	reference_power = 0.0; has_player_pull = false; leader_power = 0.0; required_watts = 0.0
	exchanges = 0

func factor(rank: int) -> float:
	if rank <= 0:
		return 1.0
	return position_factors[mini(rank, position_factors.size() - 1)]

func player_rank() -> int:
	return order.find(player)

func player_is_out() -> bool:
	return player >= 0 and rotation == player

func request_exchange() -> bool:
	if rotation >= 0 or (player >= 0 and order[0] != player):
		return false
	_begin_exchange()
	return true

func _begin_exchange() -> void:
	rotation = order[0]
	if rotation == player:
		copied_seconds = maxf(0.1, turn_seconds)
		copied_watts = turn_energy / maxf(turn_seconds, 0.000001)
		reference_power = copied_watts
		has_player_pull = true
	order.pop_front(); order.append(rotation)
	phase = "OUT"; phase_seconds = 0.0
	turn_seconds = 0.0; turn_energy = 0.0
	exchanges += 1

func step(dt: float, watts: float, _hold_watts: float, forward_m: float = INF) -> float:
	if dt <= 0.0:
		return leader_power
	if player < 0:
		leader_power = maxf(0.0, watts)
	elif player_is_out():
		# Coasting while leaving the head has no effect on the train.
		leader_power = copied_watts
	elif order[0] == player:
		leader_power = maxf(0.0, watts)
	else:
		leader_power = maxf(0.0, watts) / factor(player_rank())
	var out_before: int = rotation
	if rotation >= 0:
		phase_seconds += dt
		if phase == "OUT":
			lanes[rotation] = minf(1.0, phase_seconds / OUT_SECONDS)
			if phase_seconds >= OUT_SECONDS:
				phase = "DROP"; phase_seconds = 0.0
		elif phase == "DROP":
			offsets[rotation] = move_toward(offsets[rotation], -float(size - 1) * GAP, minf(DROP_MPS * dt, maxf(0.0, forward_m) * 0.8))
			if is_equal_approx(offsets[rotation], -float(size - 1) * GAP):
				phase = "IN"; phase_seconds = 0.0
		elif phase == "IN":
			lanes[rotation] = maxf(0.0, 1.0 - phase_seconds / IN_SECONDS)
			if phase_seconds >= IN_SECONDS:
				lanes[rotation] = 0.0
				rotation = -1; phase = ""
	for rank in range(size):
		var id: int = order[rank]
		if id != out_before and (phase != "OUT" or rotation < 0):
			offsets[id] = move_toward(offsets[id], -float(rank) * GAP, minf(3.0 * dt, maxf(0.0, forward_m) * 0.6))
	turn_seconds += dt
	if order[0] == player and not player_is_out():
		turn_energy += maxf(0.0, watts) * dt
	required_watts = target_watts()
	if order[0] != player and rotation < 0 and turn_seconds >= copied_seconds:
		_begin_exchange()
	return leader_power

func target_watts() -> float:
	if player_is_out(): return 0.0
	if not has_player_pull: return -1.0
	return reference_power * factor(maxi(0, player_rank()))

