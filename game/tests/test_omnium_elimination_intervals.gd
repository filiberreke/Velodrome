extends SceneTree
const Rules := preload("res://elimination_race_rules.gd")
const AI := preload("res://elimination_ai.gd")
const Formats := preload("res://omnium/omnium_formats.gd")
func _initialize() -> void:
	for interval in [250.0, 500.0]:
		for count in range(8,25):
			var jury := Rules.new()
			var positions: Array[float] = []; positions.resize(count); positions.fill(0)
			jury.reset(count, positions, interval)
			for cut in range(count - 2):
				var line: float = interval * (cut + 1)
				for i in range(count): positions[i] = line + 1.0 + i * 0.01
				var event := jury.sample(positions, float(cut), 1.0)
				assert(not event.is_empty())
				assert(event.line_m == line and jury.eliminated.size() == cut + 1)
				assert(jury.remaining_count() == count - cut - 1)
				assert(jury.next_line_m == line + interval)
			assert(jury.remaining_count() == 2 and jury.eliminated.size() == count - 2)
			assert(jury.sample(positions, 100.0, 1.0).is_empty())
		# A leader's future crossing survives the current jury's delayed decision.
		var jury := Rules.new()
		var initial: Array[float] = [0,0,0,0]; jury.reset(4,initial,interval)
		var spread: Array[float] = [2.2*interval,2.1*interval,1.8*interval,0.98*interval]
		assert(jury.sample(spread,0,10).is_empty())
		var next: Array[float] = [2.4*interval,2.3*interval,1.9*interval,1.02*interval]
		assert(jury.sample(next,10,1).eliminated_id == 3)
		var final: Array[float] = [2.6*interval,2.5*interval,2.02*interval,1.02*interval]
		var event := jury.sample(final,11,1)
		assert(event.eliminated_id == 2)
		assert(absf(float(event.crossing_times_s[0]) - 2.0/2.2*10.0) < 0.00001)
	assert(AI.cycle_urgency(199) == 0 and AI.cycle_urgency(300) == 1 and AI.cycle_urgency(500) == 0)
	assert(AI.cycle_urgency(99,250) == 0 and AI.cycle_urgency(150,250) == 1 and AI.cycle_urgency(250,250) == 0)
	assert(Formats.race_laps("short","elimination",24) == 24)
	assert(Formats.race_laps("women","elimination",24) == 46)
	print("PASS elimination 250/500 m intervals, every field size 8–24, future crossings, final pair and AI urgency")
	quit()
