extends "res://omnium/omnium_race_controller.gd"
func discipline() -> String: return "tempo"
func stage() -> int: return 1
func mode() -> int: return 8

func result_data(game: Node) -> Dictionary:
	var result := super.result_data(game)
	var points := {}; var sprints: Array = []
	for i in range(game.rider_count): points[String(game.rider_identities[i].id)] = game.tempo_rules.points[i]
	for sprint in game.tempo_rules.sprints:
		var ids: Array = []
		for i in sprint.order: ids.append(String(game.rider_identities[int(i)].id))
		sprints.append({"lap":sprint.lap, "seconds":sprint.seconds, "order":ids, "times":sprint.times.duplicate(), "awards":sprint.awards.duplicate()})
	result["race_points"] = points
	result["sprints"] = sprints
	return result
