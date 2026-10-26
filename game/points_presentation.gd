extends RefCounted

static func results(game) -> void:
	if game.finish_results == null or game.finish_table == null: return
	var jury = game.points_rules
	var order: Array[int] = []
	for i in range(game.rider_count): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return jury.better(a, b, game.distances))
	game.finish_heading.text = "PUNTENKOERS · %d RONDEN" % game.race_laps
	game.finish_subtitle.text = "PUNTEN BESLISSEN · BIJ GELIJKE STAND TELT DE LAATSTE SPRINT"
	game.finish_badge.text = "#%d / %d" % [order.find(0) + 1, game.rider_count]
	game.pursuit_save_box.visible = false
	var status: String = "Definitieve uitslag" if jury.complete() else "Voorlopig · de laatste sprint wordt aangevuld"
	game.finish_results.text = "JOUW SCORE  %d PUNTEN    ·    RONDEN +%d / −%d\n%s" % [jury.points[0], jury.gains[0], jury.losses[0], status]
	for child in game.finish_table.get_children():
		game.finish_table.remove_child(child)
		child.queue_free()
	var gold := Color("f4d46a")
	var white := Color("f3f7fc")
	var header := Color(0.08, 0.28, 0.42, 0.97)
	for cell in [["PL.",54],["RENNER",205],["PUNTEN",100],["RONDEN + / −",140],["SPRINTPUNTEN PER RONDE",300]]:
		game._result_cell(cell[0], gold, header, cell[1], false, true)
	for rank in range(order.size()):
		var id: int = order[rank]
		var bg := Color(0.30, 0.27, 0.13, 0.94) if rank == 0 else Color(0.08, 0.17, 0.28, 0.94)
		var sprint_text := ""
		for sprint in jury.sprints:
			var place: int = sprint.order.find(id)
			var award: String = str(sprint.awards[place]) if place >= 0 else "…"
			sprint_text += ("  |  " if not sprint_text.is_empty() else "") + "%d: %s" % [sprint.lap, award]
		game._result_cell(str(rank + 1), gold if rank == 0 else white, bg, 54)
		game._result_cell(game._rider_name(id), gold if id == 0 else white, bg, 205)
		game._result_cell(str(jury.points[id]), white, bg, 100, true)
		game._result_cell("+%d / −%d" % [jury.gains[id], jury.losses[id]], white, bg, 140, true)
		game._result_cell(sprint_text, white, bg, 300)
