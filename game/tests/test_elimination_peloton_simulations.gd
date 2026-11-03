extends "res://tests/test_elimination_gameplay.gd"

func run_test() -> void:
	var results: Array[Dictionary] = []
	for count in [4, 12, 16]:
		for player_watts in [230.0, 300.0, 400.0]:
			for scenario in range(3):
				var g := race(count)
				var seed_value: int = [17, 43, 91][scenario]
				var form_rng := RandomNumberGenerator.new(); form_rng.seed = seed_value
				for i in range(1, count): g.rider_forms[i] = form_rng.randf_range(0.94, 1.06)
				g.x_ai.reset(g.rider_profiles, g.rider_forms, g.lane_offsets)
				g.x_ai.configure_riders(g.rider_identities, g.rider_forms)
				g.ai_difficulty = [60.0, 80.0, 100.0][scenario]
				g.watts = player_watts
				var samples := 0; var hard := 0; var sheltered := 0; var span_sum := 0.0; var frames := 0
				var valid_physics := true; var no_attacks := true
				while not g._all_riders_finished() and g.clock < 1800.0:
					g.clock += 0.1; g._update_race(0.1)
					var active: Array[float] = []
					for i in range(1, count):
						valid_physics = valid_physics and is_finite(g.speeds[i]) and is_finite(g.distances[i]) and g.speeds[i] >= 0.0 and g.x_ai.wprime[i] >= -0.01 and g.x_ai.wprime[i] <= g.x_ai.wmax[i] + 0.01
						no_attacks = no_attacks and g.x_ai.modes[i] == g.x_ai.MODE_DRAFT and g.x_ai.attacks[i] == 0
						if g.finish_times[i] < 0.0: active.append(g.distances[i])
					if g.clock > 20.0 and g.elimination_rules.remaining_count() > 2:
						for i in range(1, count):
							if g.finish_times[i] >= 0.0: continue
							samples += 1
							if g.ai_power_w[i] > g.x_ai.cp[i] * 1.2: hard += 1
							if g._effective_draft_strength(i) > 0.12: sheltered += 1
						if active.size() > 1: span_sum += active.max() - active.min(); frames += 1
				check(valid_physics, "Finite physics and bounded energy in simulation")
				check(no_attacks, "No attack or breakaway tactics throughout simulation")
				check(g._all_riders_finished(), "Simulation finishes including the final pair")
				check(g.elimination_rules.eliminated.size() == count - 2, "Simulation has the correct number of eliminations")
				var result := {"riders":count, "player_watts":player_watts, "ai_difficulty":g.ai_difficulty, "seed":seed_value, "form_range":[0.94,1.06], "seconds":snappedf(g.clock,0.1), "finished":g._all_riders_finished(), "eliminated":g.elimination_rules.eliminated.size(), "valid_physics":valid_physics, "no_attacks":no_attacks, "hard_fraction":float(hard)/maxi(1,samples), "sheltered_fraction":float(sheltered)/maxi(1,samples), "mean_ai_span_m":span_sum/maxi(1,frames)}
				results.append(result)
				print("ELIMINATION_SIMULATION ", JSON.stringify(result))
				g.free()
	var directory := "res://verification/elimination_peloton"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/simulations.json", FileAccess.WRITE)
	check(file != null, "Simulation results are saved")
	if file != null: file.store_string(JSON.stringify({"races":results,"failures":failures}, "  ")); file.close()
	print("ELIMINATION_SIMULATIONS races=", results.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)
