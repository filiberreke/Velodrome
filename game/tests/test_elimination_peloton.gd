extends "res://tests/test_elimination_gameplay.gd"

func decision(distances: Array[float], finished: Array[float] = []) -> RefCounted:
	var ai = preload("res://elimination_ai.gd").new()
	var count := distances.size()
	var profiles: Array[int] = []; profiles.resize(count); profiles.fill(1); profiles[0] = 0
	var forms: Array[float] = []; forms.resize(count); forms.fill(1.0)
	var lanes: Array[float] = []; lanes.resize(count); lanes.fill(1.18)
	var speeds: Array[float] = []; speeds.resize(count); speeds.fill(11.0)
	var drafts: Array[float] = []; drafts.resize(count); drafts.fill(0.6)
	var credits: Array[int] = []; credits.resize(count); credits.fill(0)
	if finished.is_empty(): finished.resize(count); finished.fill(-1.0)
	ai.reset(profiles, forms, lanes)
	ai.step(0.1, 40.0, distances, speeds, lanes, drafts, finished, profiles, 30, 80.0, credits)
	return ai

func run_test() -> void:
	var ai = decision([456.0, 453.0, 450.0, 447.0, 444.0, 441.0, 438.0, 435.0])
	check(ai.power_w[1] < ai.cp[1], "Safe front rider follows the wheel close to the jury line")
	check(ai.power_w[4] < ai.cp[4], "Safe midfield rider saves energy close to the jury line")
	check(ai.power_w[7] > ai.power_w[4] * 1.5, "Rear rider accelerates to avoid elimination")
	ai = decision([350.0, 347.0, 344.0, 341.0, 338.0, 335.0, 332.0, 329.0])
	check(ai.power_w[7] < ai.cp[7], "Even the rear follows wheels outside the short danger window")
	ai = decision([456.0, 453.0, 450.0, 447.0, 444.0, 441.0, 438.0, 400.0])
	check(ai.power_w[7] > ai.cp[7], "Dropped rear rider responds to the leader reaching the line")
	ai = decision([456.0, 453.0, 450.0, 447.0], [-1.0, -1.0, 30.0, 31.0])
	# The final pair still has its own finish deadline rather than the jury line.
	check(ai.power_w[1] < ai.cp[1], "Final pair saves energy before the final sprint")
	ai = decision([7460.0, 7457.0, 450.0, 447.0], [-1.0, -1.0, 30.0, 31.0])
	check(ai.power_w[1] > ai.cp[1], "Final pair still contests the actual finish")
	check(ai.power_w[2] == 0.0 and ai.power_w[3] == 0.0, "Eliminated riders do not resume tactics")
	ai = decision([7503.0, 7457.0, 450.0, 447.0], [100.0, -1.0, 30.0, 31.0])
	check(ai.power_w[1] > ai.cp[1], "Remaining finalist keeps pedalling after the winner has finished")
	for count in [4, 12, 16]:
		for seed_value in [17, 43, 91]:
			var g := race(count)
			var form_rng := RandomNumberGenerator.new(); form_rng.seed = seed_value
			for i in range(1, count): g.rider_forms[i] = form_rng.randf_range(0.97, 1.03)
			g.x_ai.reset(g.rider_profiles, g.rider_forms, g.lane_offsets)
			g.x_ai.configure_riders(g.rider_identities, g.rider_forms)
			var samples := 0; var hard := 0; var sheltered := 0; var span_sum := 0.0; var frames := 0
			while not g._all_riders_finished() and g.clock < 1800.0:
				g.clock += 0.1; g._update_race(0.1)
				var active: Array[float] = []
				for i in range(1, count):
					check(is_finite(g.speeds[i]) and g.x_ai.wprime[i] >= -0.01, "Finite speed and nonnegative energy")
					check(g.x_ai.modes[i] == g.x_ai.MODE_DRAFT and g.x_ai.attacks[i] == 0, "Elimination never chooses an attack or breakaway tactic")
					if g.finish_times[i] < 0.0: active.append(g.distances[i])
				if g.clock > 20.0 and g.elimination_rules.remaining_count() > 2:
					for i in range(1, count):
						if g.finish_times[i] >= 0.0: continue
						samples += 1
						if g.ai_power_w[i] > g.x_ai.cp[i] * 1.2: hard += 1
						if g._effective_draft_strength(i) > 0.12: sheltered += 1
					if active.size() > 1: span_sum += active.max() - active.min(); frames += 1
			check(g._all_riders_finished(), "Complete elimination race including final sprint")
			check(g.elimination_rules.eliminated.size() == count - 2, "Exactly one elimination per jury line")
			check(float(sheltered) / maxi(1, samples) > 0.55, "Riders spend most of the elimination race sheltered in the bunch")
			check(float(hard) / maxi(1, samples) < 0.40, "Sustained hard efforts do not dominate elimination racing")
			print("PELOTON count=%d seed=%d hard=%.3f sheltered=%.3f span=%.1f" % [count, seed_value, float(hard)/maxi(1,samples), float(sheltered)/maxi(1,samples), span_sum/maxi(1,frames)])
			g.free()
	print("ELIMINATION_PELOTON failures=", failures)
	quit(0 if failures == 0 else 1)
