extends RefCounted
const MenuSkin := preload("res://menu_theme.gd")

static func results(game) -> void:
	if game.finish_results == null or game.finish_table == null: return
	var jury = game.tempo_rules
	var order: Array[int] = []
	for i in range(game.rider_count): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return jury.better(a, b, game.distances))
	game.finish_heading.text = String(TranslationServer.translate("TEMPO_RESULTS_LAPS")) % game.race_laps
	game.finish_subtitle.text = "TEMPO_RESULTS_TIEBREAK"
	game.finish_badge.text = "#%d / %d" % [order.find(0) + 1, game.rider_count]
	game.pursuit_save_box.visible = false
	var status: String = String(TranslationServer.translate("RESULT_FINAL_CLASSIFICATION")) if jury.complete() else String(TranslationServer.translate("TEMPO_RESULTS_PENDING"))
	game.finish_results.text = String(TranslationServer.translate("RESULT_LAP_SCORE")) % [jury.points[0], jury.gains[0], jury.losses[0], status]
	var omnium = game.get("omnium_race")
	if omnium != null and omnium.enabled():
		var scores := preload("res://omnium/omnium_scoring.gd")
		var earned: int = scores.place_points(order.find(0) + 1)
		var totals: Dictionary = scores.totals(omnium.context.riders, omnium.context.results)
		game.finish_results.text += String(TranslationServer.translate("RESULT_OMNIUM_D_POINTS_TOTAL_D_S")) % [earned, int(totals[game.rider_identities[0].id]) + earned, "opgeslagen" if omnium.committed else "voorlopig"]
	for child in game.finish_table.get_children():
		game.finish_table.remove_child(child)
		child.queue_free()
	var gold := MenuSkin.INK
	var white := MenuSkin.INK
	var header := MenuSkin.PALE
	for cell in [[String(TranslationServer.translate("RESULT_PLACE")),54],[String(TranslationServer.translate("SETTINGS_RIDER")),205],[String(TranslationServer.translate("RESULT_POINTS")),100],[String(TranslationServer.translate("TEMPO_NET_LAPS")),140],[String(TranslationServer.translate("TEMPO_POINTS_BY_LAP")),300]]:
		game._result_cell(cell[0], gold, header, cell[1], false, true)
	for rank in range(order.size()):
		var id: int = order[rank]
		var bg := MenuSkin.GOLD if rank == 0 else MenuSkin.PAPER
		var sprint_text := ""
		for sprint in jury.sprints:
			var place: int = sprint.order.find(id)
			var award: String = str(sprint.awards[place]) if place >= 0 else "…"
			sprint_text += ("  |  " if not sprint_text.is_empty() else "") + "%d: %s" % [sprint.lap, award]
		game._result_cell(str(rank + 1), gold if rank == 0 else white, bg, 54)
		game._result_rider_cell(id, gold if id == 0 else white, bg, 205)
		game._result_cell(str(jury.points[id]), white, bg, 100, true)
		game._result_cell("+%d / −%d" % [jury.gains[id], jury.losses[id]], white, bg, 140, true)
		game._result_cell(sprint_text, white, bg, 300)
