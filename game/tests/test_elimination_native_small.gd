extends "res://tests/test_elimination_gameplay.gd"
func run_test() -> void:
	var g:=race(4)
	var rng:=RandomNumberGenerator.new();rng.seed=17
	for i in range(1,4):g.rider_forms[i]=rng.randf_range(0.97,1.03)
	g.x_ai.reset(g.rider_profiles,g.rider_forms,g.lane_offsets);g.x_ai.configure_riders(g.rider_identities,g.rider_forms)
	var samples:=0;var hard:=0;var sheltered:=0
	var recovery_samples:=0;var recovery_sheltered:=0
	while not g._all_riders_finished() and g.clock<1800.0:
		g.clock+=0.1;g._update_race(0.1)
		if g.clock<=20.0 or g.elimination_rules.remaining_count()<=2:continue
		for i in range(1,4):
			if g.finish_times[i]>=0.0:continue
			samples+=1
			if g.ai_power_w[i]>g.x_ai.cp[i]*1.2:hard+=1
			if g._effective_draft_strength(i)>0.12:sheltered+=1
			if g.x_ai.cycle_urgency(g.distances.max()-g.REAR_TRAILING_EDGE_M)<=0.0:
				recovery_samples+=1
				if g._effective_draft_strength(i)>0.12:recovery_sheltered+=1
	print("NATIVE_SMALL hard=",float(hard)/samples," sheltered=",float(sheltered)/samples," recovery_sheltered=",float(recovery_sheltered)/maxi(1,recovery_samples))
	check(g._all_riders_finished(),"Small field finishes")
	g.free();quit(0 if failures==0 else 1)
