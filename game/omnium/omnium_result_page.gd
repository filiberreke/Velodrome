extends RefCounted
## Read-only full result view; never restores or restarts a race simulation.
const Style := preload("res://menu_theme.gd")
const Flags := preload("res://national_flags.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
const Results := preload("res://omnium/omnium_results.gd")

static func render(page: Node, tournament: Dictionary, index: int) -> void:
	var result: Dictionary = tournament.results[index]
	if index == 3:
		page.body.add_child(page.menu.label("Omnium · Puntenkoers · Uitslag",32))
		var table := GridContainer.new(); table.name = "OmniumSavedResultTable"; page.body.add_child(table)
		preload("res://omnium/omnium_points_presentation.gd").populate(table,tournament.riders,tournament.results.slice(0,3),result)
		return
	var title: String = ["Scratch", "Temporace", "Afvalling", "Puntenkoers"][index]
	page.body.add_child(page.menu.label("Omnium · %s · Uitslag" % title, 32))
	page.body.add_child(page.menu.label("OFFICIËLE WEDSTRIJDRESULTATEN · %d deelnemers" % result.order.size(), 17, Style.MUTED))
	var totals := Scores.totals(tournament.riders, tournament.results.slice(0, index + 1))
	var riders := {}
	for rider in tournament.riders:
		riders[String(rider.id)] = rider
		if rider.get("is_player", false):
			var place: int = result.order.find(String(rider.id)) + 1
			page.body.add_child(page.menu.label("JOUW PLAATS  %d / %d   ·   OMNIUM  %+d punten · totaal %d" % [place, result.order.size(), points(result, index, place, String(rider.id)), totals[rider.id]], 21, Style.BLUE))
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", Style.panel(Style.PAPER, Style.LINE, 18, 12))
	page.body.add_child(shell)
	var table := GridContainer.new()
	table.name = "OmniumSavedResultTable"
	table.columns = 5 if index == 1 else 4
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 0)
	table.add_theme_constant_override("v_separation", 0)
	shell.add_child(table)
	var headers := ["PL.", "RENNER", "KOERSPUNTEN", "TIJD / ACHTERSTAND", "OMNIUMPUNTEN"] if index == 1 else ["PL.", "RENNER", "TIJD / ACHTERSTAND", "OMNIUMPUNTEN"]
	if index == 3: headers[2] = "KOERSPUNTEN"
	for text in headers: cell(page, table, text, Style.PALE)
	for i in range(result.order.size()):
		var id := String(result.order[i])
		var rider: Dictionary = riders.get(id, {"name":id, "country":""})
		var fill: Color = Style.GOLD if rider.get("is_player", false) else (Style.IVORY if i % 2 == 0 else Style.PAPER)
		cell(page, table, str(i + 1), fill)
		var name_cell := cell(page, table, "", fill)
		var empty_label := name_cell.get_child(0)
		name_cell.remove_child(empty_label); empty_label.queue_free()
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
		name_cell.add_child(row)
		var flag := TextureRect.new(); flag.texture = Flags.texture(String(rider.country))
		flag.custom_minimum_size = Vector2(28, 20)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(flag)
		row.add_child(page.menu.label(String(rider.name), 20))
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == 1: cell(page, table, str(int(result.get("race_points", {}).get(id, 0))), fill)
		cell(page, table, str(int(result.get("points", {}).get(id, 0))) if index == 3 else time_text(result, id), fill)
		cell(page, table, str(points(result, index, i + 1, id)), fill)
	if index == 0 and not result.has("lap_credits"):
		page.body.add_child(page.menu.label("Bij deze eerder opgeslagen uitslag zijn rondeverschillen niet bewaard.", 17, Style.MUTED))

static func points(result: Dictionary, index: int, place: int, id: String) -> int:
	return int(result.get("points", {}).get(id, 0)) if index == 3 else Scores.place_points(place)

static func time_text(result: Dictionary, id: String) -> String:
	var times: Dictionary = result.get("finish_times", {})
	if result.order.is_empty() or float(times.get(id, -1)) < 0: return "—"
	var winner := String(result.order[0])
	if id == winner: return Results.clock(float(times[id]))
	var credits: Dictionary = result.get("lap_credits", {})
	if credits.has(winner) and credits.has(id):
		var gap := int(credits[winner]) - int(credits[id])
		if gap != 0: return "%+d ronde%s" % [gap, "" if absi(gap) == 1 else "n"]
	if float(times.get(winner, -1)) < 0: return "—"
	return "+" + Results.clock(float(times[id]) - float(times[winner]))

static func cell(page: Node, parent: Node, text: String, fill: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.panel(fill, Color.TRANSPARENT, 12, 0))
	parent.add_child(box)
	box.add_child(page.menu.label(text, 20))
	return box
