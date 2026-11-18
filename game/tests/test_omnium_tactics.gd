extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
const Controller := preload("res://omnium/omnium_points_controller.gd")
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
func _initialize() -> void:
	var game := Game.new(); root.add_child(game)
	var catalog := Catalog.new(); assert(catalog.load_catalog())
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var riders := catalog.generate({"id":"player","country":"belgium","name":"Player","is_player":true,"profile":0},8,"mixed",rng)
	var ids: Array = []
	for rider in riders: ids.append(rider.id)
	var history: Array = []
	for kind in ["scratch","tempo","elimination"]: history.append({"discipline":kind,"order":ids})
	game.omnium_race = Controller.new(); game.omnium_race.context = {"riders":riders,"results":history}
	game.race_mode = 1; game.rider_count = 8; game.race_laps = 40; game._configure_peloton()
	var tactics = game.omnium_race.tactics
	for rider in riders: tactics.previous[rider.id] = 70
	tactics.previous[riders[1].id] = 120; tactics.previous[riders[7].id] = 101
	game.distances.fill(0.0); game.distances[7] = 15.0; game.clock = 10
	tactics.update(game)
	assert(tactics.should_chase(1) and tactics.plans[1].rival == 7) # Outsider can take +20.
	game.peloton_info = {"ids":[0,1,2,3,4,5,6,7],"front":15.0}
	game.clock += 1; tactics.update(game)
	assert(not tactics.should_chase(1)) # Same front rider inside the bunch is not an escape.
	game.peloton_info = {}; game.clock += 1; tactics.update(game)
	var attack: float = tactics.attack_factor(3)
	assert(attack > 1.0)
	tactics.previous[riders[1].id] = 140; game.clock += 1; tactics.update(game)
	assert(not tactics.should_chase(1)) # Same ranks, different point gap.
	game.x_ai.wprime[3] = game.x_ai.wmax[3]*0.1; game.clock += 1; tactics.update(game)
	assert(tactics.attack_factor(3) < attack)
	# A new points event changes the threat immediately, without waiting 0.5 seconds.
	game.points_rules.points[7] = 20; tactics.update(game)
	assert(tactics.should_chase(1))
	game.finish_times[7] = 1.0; game.clock += 1; tactics.update(game)
	assert(not tactics.should_chase(1))
	var ai = game.x_ai; ai.fatigue[1] = 0; ai.wprime[1] = 1000; tactics.plans[1] = {"scale":1.18}
	var old: float = ai.wprime[1]; var power: float = ai._phys_power(1,ai.cp[1]+100,1.0)
	assert(power > ai.cp[1] and power <= ai.pmax[1])
	assert(absf(ai.wprime[1] - (old-(power-ai.cp[1]))) < 0.000001)
	# Elimination saving is allowed only safely ahead, away from the next cut.
	tactics.discipline = "elimination"; game.race_mode = 2
	game.finish_times.fill(-1.0); game.distances.fill(0.0); game.distances[1] = 10.0
	var rear: Array[float] = []; rear.resize(8); rear.fill(0.0)
	game.elimination_rules.reset(8,rear,500.0); ai.wprime[1] = ai.wmax[1]*0.4
	game.clock += 1; tactics.update(game); assert(tactics.plans[1].scale < 1.0)
	game.distances[1] = 400.0; game.clock += 1; tactics.update(game); assert(tactics.plans[1].scale == 1.0)
	game.free()
	print("PASS omnium tactics: point gaps over ranks, dangerous outsider, remaining sprints, reserve budget, event reaction and existing Wprime accounting")
	quit()
