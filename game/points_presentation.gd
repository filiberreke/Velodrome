extends RefCounted
const MenuSkin := preload("res://menu_theme.gd")

static func results(game) -> void:
	if game.finish_results == null or game.finish_table == null: return
	var jury = game.points_rules
	var order: Array[int] = []
	for i in range(game.rider_count): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return jury.better(a,b,game.distances))
	game.finish_heading.text = "PUNTENKOERS · %d RONDEN" % game.race_laps
	game.finish_subtitle.text = "KLIK OP EEN RENNER VOOR PLAATSEN EN PUNTEN PER SPRINT"
	game.finish_badge.text = "#%d / %d" % [order.find(0)+1,game.rider_count]
	game.pursuit_save_box.hide()
	game.finish_results.text = "JOUW SCORE  %d PUNTEN    ·    RONDEN +%d / −%d\n%s" % [jury.points[0],jury.gains[0],jury.losses[0],"Definitieve uitslag" if jury.complete() else "Voorlopige uitslag"]
	var names: Array[String] = []
	for id in order: names.append(game._rider_name(id))
	var key := str([game.race_laps,names,order,jury.points,jury.gains,jury.losses,jury.sprints])
	if game.finish_table.get_meta("points_result_key", "") == key: return
	game.finish_table.set_meta("points_result_key", key)
	for child in game.finish_table.get_children():
		game.finish_table.remove_child(child); child.queue_free()
	game.finish_table.columns = 1
	var header := HBoxContainer.new()
	for field in [["PL.",45],["RENNER",270],["SPRINT",130],["RONDEPUNTEN",160],["TOTAAL",130]]:
		var heading := Label.new(); heading.text = field[0]
		heading.custom_minimum_size.x = field[1]; heading.add_theme_font_size_override("font_size",16)
		header.add_child(heading)
	game.finish_table.add_child(header)
	for rank in order.size():
		var id: int = order[rank]
		var sprint_total := 0
		var details := ""
		for sprint in jury.sprints:
			var place: int = sprint.order.find(id)
			var award: int = int(sprint.awards[place]) if place >= 0 and place < sprint.awards.size() else 0
			sprint_total += award
			details += "Ronde %d%s    ·    %s    ·    %d punten\n" % [sprint.lap," · FINISH ×2" if sprint.lap == game.race_laps else "",str(place+1)+"e plaats" if place >= 0 else "Nog niet gepasseerd",award]
		var lap_points: int = 20*(jury.gains[id]-jury.losses[id])
		var row := Button.new()
		row.name = "ResultRider%d" % id
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(820,56)
		row.add_theme_font_size_override("font_size",21)
		row.tooltip_text = "Sprintdetails van " + game._rider_name(id)
		var cells := HBoxContainer.new(); cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cells); cells.position = Vector2(12,12)
		for field in [[str(rank+1),45],[game._rider_name(id)+( " · JIJ" if id == 0 and game._rider_name(id) != "JIJ" else ""),270],[str(sprint_total),130],["%+d" % lap_points,160],[str(jury.points[id])+" pt    +",130]]:
			var value := Label.new(); value.text = field[0]; value.custom_minimum_size.x = field[1]
			value.add_theme_font_size_override("font_size",21);value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cells.add_child(value)

		row.add_theme_stylebox_override("normal",MenuSkin.panel(MenuSkin.PALE if id == 0 else (MenuSkin.GOLD if rank == 0 else MenuSkin.PAPER),MenuSkin.LINE,12,8))
		row.add_theme_stylebox_override("pressed",MenuSkin.panel(MenuSkin.PALE,MenuSkin.BLUE,12,8))
		game.finish_table.add_child(row)
		var panel := PanelContainer.new()
		panel.name = "SprintDetails%d" % id
		panel.add_theme_stylebox_override("panel",MenuSkin.panel(MenuSkin.PALE,MenuSkin.LINE,18,8))
		panel.hide()
		var label := Label.new()
		label.add_theme_font_size_override("font_size",19)
		label.text = "%s · SPRINTDETAILS\n\n%s\n%d sprintpunten %+d rondepunten = %d punten" % [game._rider_name(id),details,sprint_total,lap_points,jury.points[id]]
		panel.add_child(label);game.finish_table.add_child(panel)
		row.toggled.connect(func(open: bool): panel.visible = open)
