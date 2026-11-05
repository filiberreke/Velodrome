extends SceneTree

const Energy := preload("res://x_scratch_ai.gd")

class Team extends "res://team_race.gd":
	func _apply_formation(_game: Node3D) -> void: pass
	func _record(_game: Node3D, _seconds: float, _power: float, _force: bool) -> void: pass

class Rider extends Node3D:
	const PURSUIT_START_M := 0.0
	const LANES := [1.18]
	var model = Energy.new()
	var watts := 900.0
	var trainer_seen := false
	var delivered := 0.0
	var calls := 0
	var boost_left := 0.0
	var recovery_left := 0.0
	var clock := 1.0
	var team_size := 3
	var baseline_speed := 0.0
	var player_power_integral := 0.0
	var player_peak_watts := 0.0
	var player_speed_peak_kmh := 0.0
	var finish_times := [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
	var finished := false
	func _pc_power(dt: float) -> float:
		calls += 1
		delivered = watts if trainer_seen else model._phys_power(1, watts, dt)
		return delivered
	func _race_length() -> float: return 100000.0
	func _path_metric(_position: float, _lane: float) -> float: return 1.0
	func _next_speed(_speed: float, power: float, _dt: float, _draft: float) -> float: return power / 100.0
	func _at(_position: float, _lane: float) -> Vector3: return Vector3.ZERO
	func _banked_speed(speed: float, _height: float, _lateral_height: float, _lateral_travel: float, _dt: float, _power: float) -> float: return speed
	func _register_pursuit_half_crossings(_team: int, _prior: float, _step: float, _dt: float, _power: float) -> void: pass
	func _register_lap_crossings(_team: int, _prior: float, _step: float, _dt: float) -> void: pass
	func _capture_demo_fit_sample() -> void: pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func reset_model(model) -> void:
	var profiles: Array[int] = [0, 3]
	var forms: Array[float] = [1.0, 1.0]
	var lanes: Array[float] = [1.18, 1.18]
	model.reset(profiles, forms, lanes)
	model.cp[1] = 255.0
	model.wmax[1] = 30000.0
	model.wprime[1] = 30000.0
	model.pmax[1] = 1300.0

func _initialize() -> void:
	var model = Energy.new()
	for reserve in [30000.0, 0.5, 0.0]:
		for fatigue in [0.0, 0.5, 1.0]:
			for dt in [0.00001, 0.016, 0.1]:
				reset_model(model)
				model.wprime[1] = reserve
				model.fatigue[1] = fatigue
				var limit: float = model.power_limit(1, dt)
				check(model.wprime[1] == reserve and model.fatigue[1] == fatigue, "Reading ceiling does not consume energy")
				var actual: float = model._phys_power(1, 1300.0, dt)
				check(is_equal_approx(limit, actual), "Displayed maximum matches actual model at full/low/empty reserve")
	var rider := Rider.new()
	reset_model(rider.model)
	var team := Team.new()
	team.ours.reset(3)
	team.theirs.reset(3, -1)
	team.step(rider, 0.1)
	check(rider.calls == 1, "Team pursuit applies PC model exactly once per player step")
	check(rider.model.wprime[1] < 30000.0, "Team pursuit consumes energy above CP")
	rider.model.wprime[1] = 0.0
	team.step(rider, 0.1)
	check(rider.delivered < 256.0 and team.ours.leader_power == rider.delivered, "Empty reserve limits actual team power")
	rider.watts = 100.0
	team.step(rider, 0.1)
	check(rider.model.wprime[1] > 0.0, "Easy effort in team pursuit recovers energy")
	rider.trainer_seen = true
	rider.watts = 900.0
	var reserve: float = rider.model.wprime[1]
	team.step(rider, 0.1)
	check(rider.delivered == 900.0 and rider.model.wprime[1] == reserve, "Real trainer bypasses PC fatigue in team pursuit")
	rider.free()
	if failures == 0: print("PC_ENERGY_POWER_OK")
	quit(0 if failures == 0 else 1)
