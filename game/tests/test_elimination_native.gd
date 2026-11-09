extends "res://tests/measure_elimination_native.gd"

func run_test() -> void:
	# Stop-and-pass is required with a real human who supplies zero watts.
	for count in [4,12,16]:
		var g := make_race(count,17);g.watts=0.0
		for tick in range(250): g.clock+=0.1;g._update_race(0.1)
		for i in range(1,count): check(g.distances[i]>g.distances[0]+5.0,"AI passes a stationary player safely")
		g.free()
	# Same physical inputs, different frame sizes. Only the presentation clock
	# can round differently when the last physical tick is inside a frame.
	for seed_value in [17,23]:
		var reference: Dictionary={}
		for dt in [0.1,0.4,0.13]:
			var row := run_case(12,seed_value,dt,false)
			if reference.is_empty(): reference=row
			else:
				check(row.eliminated==reference.eliminated,"Frame interval preserves jury decisions")
				for field in ["distances","speeds","energy","finish_times"]:
					for i in range(12): check(absf(float(row[field][i])-float(reference[field][i]))<0.000001,"Frame interval preserves "+field)
	# Check the real curved-track state at every step, including lane changes.
	var g := make_race(16,43)
	var minimum_gap:=INF;var checks:=0
	while not g._all_riders_finished() and g.clock<1800.0:
		g.clock+=0.1;g._update_race(0.1)
		for a in range(16):
			if g.finish_times[a]>=0.0: continue
			for b in range(a+1,16):
				if g.finish_times[b]>=0.0 or absf(g.lane_offsets[a]-g.lane_offsets[b])>=0.55: continue
				var gap: float=absf(preload("res://elimination_motion.gd").signed_gap(g.distances[a],g.distances[b]))
				minimum_gap=minf(minimum_gap,gap);checks+=1
				check(gap>=2.0-0.00001,"Actual banked-track following gap stays legal")
	check(g._all_riders_finished(),"Safety race completes")
	print("NATIVE_SAFETY minimum_gap=",minimum_gap," pair_checks=",checks)
	g.free()
	print("ELIMINATION_NATIVE failures=",failures)
	quit(0 if failures==0 else 1)
