extends SceneTree
const Jury := preload("res://points_race_rules.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
const View := preload("res://omnium/omnium_points_presentation.gd")
func _initialize() -> void:
	for count in range(8,25):
		for laps in [40,80,100]:
			var jury := Jury.new(); jury.reset(count,laps)
			var times: Array[float] = []; times.resize(count); times.fill(-1)
			var riders: Array = []; var ids: Array = []
			for i in range(count): riders.append({"id":str(i)}); ids.append(str(i))
			for lap in range(10,laps+1,10):
				var previous: Array[float] = []; var current: Array[float] = []
				for i in range(count): previous.append(lap*250.0-1.0-i*0.01); current.append(lap*250.0+1.0-i*0.01)
				jury.advance(previous,current,float(lap),1.0,times)
			assert(jury.complete() and jury.sprints.size() == laps/10)
			for sprint in jury.sprints:
				assert(sprint.order.size() == count)
				assert(sprint.awards.slice(0,4) == ([10,6,4,2] if sprint.lap == laps else [5,3,2,1]))
			jury._award_lap(0,1,999.0); jury._award_lap(count-1,-1,999.0)
			var points := {}
			for i in range(count): points[str(i)] = jury.points[i]
			var history: Array = []
			for kind in ["scratch","tempo","elimination"]: history.append({"discipline":kind,"order":ids})
			var result := {"discipline":"points","points":points,"order":ids}
			var totals := Scores.totals(riders,history+[result])
			assert(totals["0"] == 120+5*(laps/10-1)+10+20)
			assert(totals[str(count-1)] == 3*Scores.place_points(count)-20)
	# Equal omnium total: final sprint time, then best earlier places, then shared rank.
	var history: Array = [{"discipline":"scratch","order":["a","b"]},{"discipline":"tempo","order":["b","a"]},{"discipline":"elimination","order":["a","b"]}]
	var scores := {"a":100,"b":100}
	var result := {"discipline":"points","points":{"a":0,"b":0},"order":["a","b"],"final_sprint_times":{"a":11.0,"b":10.0}}
	assert(Scores.compare("a","b",scores,history+[result]) > 0)
	var pending := result.duplicate(true); pending.final_sprint_times.erase("b")
	assert(Scores.compare("a","b",scores,history+[pending]) == 0)
	result.final_sprint_times.a = 10.0
	assert(Scores.compare("a","b",scores,history+[result]) < 0)
	# Identical sorted earlier places can be 1/2/3 and 3/1/2.
	history = [{"discipline":"scratch","order":["a","x","b"]},{"discipline":"tempo","order":["b","a","x"]},{"discipline":"elimination","order":["x","b","a"]}]
	assert(Scores.compare("a","b",scores,history+[result]) == 0)
	var tied := result.duplicate(true); tied.points = {"a":0,"b":0,"x":0}; tied.final_sprint_times.x = 11.0
	var shared := View.ranking([{"id":"a"},{"id":"b"},{"id":"x"}],history,tied)
	assert(shared[0].rank == 1 and shared[1].rank == 1 and shared[2].rank == 3)
	var overall := View.ranking([{"id":"a"},{"id":"b"}],[{"discipline":"scratch","order":["b","a"]},{"discipline":"tempo","order":["b","a"]},{"discipline":"elimination","order":["b","a"]}],{"discipline":"points","points":{"a":5,"b":0},"order":["a","b"]})
	assert(overall[0].rider.id == "b" and overall[0].total == 120 and overall[1].total == 119)
	print("PASS omnium points: 51 field/format combinations, all sprint awards, direct net points, complete final order, tie-break and shared equality")
	quit()
