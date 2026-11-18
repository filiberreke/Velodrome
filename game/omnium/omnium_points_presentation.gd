extends RefCounted
const Style := preload("res://menu_theme.gd")
const Flags := preload("res://national_flags.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
static func ranking(riders: Array, history: Array, result: Dictionary) -> Array[Dictionary]:
	var results := history.duplicate(); results.append(result)
	var totals := Scores.totals(riders, results)
	var ordered: Array = riders.duplicate()
	ordered.sort_custom(func(a, b): return Scores.compare(String(a.id), String(b.id), totals, results) < 0)
	var rows: Array[Dictionary] = []; var last := ""; var rank := 0
	for i in range(ordered.size()):
		var rider: Dictionary = ordered[i]; var id := String(rider.id)
		if last.is_empty() or Scores.compare(last,id,totals,results) != 0: rank = i+1
		rows.append({"rider":rider,"rank":rank,"total":int(totals[id])}); last = id
	return rows
static func results(game: Node) -> void:
	if game.finish_results == null or game.finish_table == null: return
	var context: Dictionary = game.omnium_race.context
	var result: Dictionary = game.omnium_race.result_data(game)
	var rows := ranking(context.riders, context.results, result)
	var player_rank := 0; var total := 0
	for row in rows:
		if row.rider.get("is_player",false): player_rank = int(row.rank); total = int(row.total)
	game.finish_heading.text = "Omnium · Puntenkoers · Eindklassement" if game.omnium_race.committed else "Omnium · Puntenkoers · Uitslag"
	game.finish_subtitle.text = "KLIK OP EEN RENNER VOOR PLAATSEN EN PUNTEN PER SPRINT"
	game.finish_badge.text = "#%d / %d" % [player_rank, game.rider_count]
	game.pursuit_save_box.hide()
	game.finish_results.text = "PUNTENKOERS  %+d punten · OMNIUMTOTAAL  %d\n%s" % [game.points_rules.points[0],total,"Definitief · omnium opgeslagen in gereden toernooien" if game.omnium_race.committed else "Voorlopig · resterende uitslag wordt versneld berekend"]
	if not game.omnium_race.error.is_empty(): game.finish_results.text += "\n" + game.omnium_race.error
	populate(game.finish_table, context.riders, context.results, result)
static func populate(table: GridContainer, riders: Array, history: Array, result: Dictionary) -> void:
	var key := JSON.stringify([riders,history,result])
	if table.get_meta("points_result_key", "") == key: return
	table.set_meta("points_result_key",key)
	for child in table.get_children(): table.remove_child(child); child.queue_free()
	table.columns = 1
	var before := Scores.totals(riders,history)
	var widths := [40,230,75,75,95,85,90]
	var header := HBoxContainer.new(); table.add_child(header)
	var titles := ["PL.","RENNER","VOORAF","SPRINT","RONDEPT","KOERSPT","OMNIUM"]
	for i in range(titles.size()): add_label(header,String(titles[i]),int(widths[i]),16)
	for row_data in ranking(riders,history,result):
		var rider: Dictionary = row_data.rider; var id := String(rider.id)
		var sprint_total := 0; var detail := ""
		for sprint in result.get("sprints",[]):
			var place: int = sprint.order.find(id)
			var award: int = int(sprint.awards[place]) if place >= 0 else 0
			sprint_total += award
			detail += "Ronde %d%s · %s · %d punten\n" % [sprint.lap," · FINISH ×2" if sprint.lap == result.get("laps",0) else "",("plaats %d" % (place+1)) if place >= 0 else "Nog niet gepasseerd",award]
		var earned := int(result.points.get(id,0))
		var lap_points := earned-sprint_total
		var row := Button.new(); row.name = "OmniumResult_" + id; row.toggle_mode = true
		row.custom_minimum_size = Vector2(830,54)
		row.set_meta("rider_id",id); row.set_meta("omnium_total",int(row_data.total))
		var fill: Color = Style.GOLD if rider.get("is_player",false) else Style.PAPER
		row.add_theme_stylebox_override("normal",Style.panel(fill,Style.LINE,12,8)); Style.toggle_focus(row)
		var cells := HBoxContainer.new(); row.add_child(cells); cells.position = Vector2(12,12)
		add_label(cells,str(row_data.rank),int(widths[0]),20)
		var name_box := HBoxContainer.new(); name_box.custom_minimum_size.x = int(widths[1]); cells.add_child(name_box)
		var flag := TextureRect.new(); flag.texture = Flags.texture(String(rider.country)); flag.custom_minimum_size = Vector2(26,18)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		name_box.add_child(flag); add_label(name_box,String(rider.name),0,20)
		for field in [[str(before[id]),widths[2]],[str(sprint_total),widths[3]],["%+d" % lap_points,widths[4]],["%+d" % earned,widths[5]],[str(row_data.total)+"  +",widths[6]]]: add_label(cells,field[0],int(field[1]),20)
		ignore(cells); table.add_child(row)
		var panel := PanelContainer.new(); panel.name = "OmniumSprintDetails_" + id
		panel.add_theme_stylebox_override("panel",Style.panel(Style.PALE,Style.LINE,16,8)); panel.hide(); table.add_child(panel)
		add_label(panel,detail+"\n%d sprintpunten %+d rondepunten = %+d koerspunten · omniumtotaal %d" % [sprint_total,lap_points,earned,row_data.total],0,18)
		row.toggled.connect(func(open: bool): panel.visible = open)
static func add_label(parent: Node, text: String, width: int, font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.custom_minimum_size.x = width
	label.add_theme_font_size_override("font_size",font_size); parent.add_child(label)
	return label
static func ignore(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore(child)
