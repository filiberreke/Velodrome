extends RefCounted
const Scores := preload("res://omnium/omnium_scoring.gd")
const View := preload("res://omnium/omnium_result_page.gd")
const Style := preload("res://menu_theme.gd")
var sort_column := 5
var descending := true
func render_list(page: Node) -> void:
	page.body.add_child(page.menu.label("OMNIUM_PAST_TOURNAMENTS",32))
	if page.manager.state.archive.is_empty(): page.body.add_child(page.menu.label("OMNIUM_NO_PAST_TOURNAMENTS_YET",20))
	var tournaments: Array = page.manager.state.archive.duplicate(); tournaments.reverse()
	for tournament in tournaments:
		var date := Time.get_date_string_from_unix_time(int(tournament.get("ended",0)))
		var status: String = {"completed":String(TranslationServer.translate("OMNIUM_COMPLETED")),"stopped":String(TranslationServer.translate("OMNIUM_STOPPED")),"expired":String(TranslationServer.translate("OMNIUM_EXPIRED"))}.get(String(tournament.status),String(tournament.status))
		page.button(String(TranslationServer.translate("OMNIUM_S_S_D_RIDERS_D_4_RACES")) % [date,status,tournament.riders.size(),tournament.results.size()], page.open_archive.bind(tournament))
func render(page: Node) -> void:
	var tournament: Dictionary = page.archived_tournament
	var complete: bool = tournament.status == "completed"
	page.body.add_child(page.menu.label(String(TranslationServer.translate("OMNIUM_OMNIUM_FINAL_STANDINGS")) if complete else String(TranslationServer.translate("OMNIUM_OMNIUM_INTERIM_STANDINGS")),32))
	page.body.add_child(page.menu.label(String(TranslationServer.translate("OMNIUM_COMPLETED")) if complete else String(TranslationServer.translate("OMNIUM_OMNIUM_STOPPED_OR_EXPIRED_NO_FINAL_WINNER_CANNOT_RESUME")),19,Style.MUTED))
	var totals := Scores.totals(tournament.riders,tournament.results)
	var riders: Array = tournament.riders.duplicate()
	riders.sort_custom(func(a,b):
		if sort_column == 5: return Scores.compare(String(a.id),String(b.id),totals,tournament.results) < 0 if descending else Scores.compare(String(a.id),String(b.id),totals,tournament.results) > 0
		if sort_column == 0: return String(a.name) > String(b.name) if descending else String(a.name) < String(b.name)
		var first := value(tournament,String(a.id),sort_column-1); var second := value(tournament,String(b.id),sort_column-1)
		return first > second if descending else first < second)
	var table := GridContainer.new(); table.name = "OmniumArchiveMatrix"; table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page.body.add_child(table)
	var titles := [String(TranslationServer.translate("OMNIUM_RIDER")),String(TranslationServer.translate("RACE_MENU_SCRATCH_RACE")),String(TranslationServer.translate("RACE_MENU_TEMPO_RACE")),String(TranslationServer.translate("RACE_MENU_ELIMINATION_RACE")),String(TranslationServer.translate("RACE_MENU_POINTS_RACE")),String(TranslationServer.translate("OMNIUM_TOTAL"))]
	for i in range(titles.size()):
		var button: Button = page.button(titles[i], change_sort.bind(page,i),table)
		button.custom_minimum_size.x = 270 if i == 0 else 125
	for rider in riders:
		var name_box := HBoxContainer.new(); table.add_child(name_box)
		var flag := TextureRect.new(); flag.texture = preload("res://national_flags.gd").texture(String(rider.country)); flag.custom_minimum_size = Vector2(28,20)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; name_box.add_child(flag)
		name_box.add_child(page.menu.label(String(rider.name),20))
		for i in range(4): View.cell(page,table,str(value(tournament,String(rider.id),i)) if i < tournament.results.size() else "—",Style.PAPER)
		View.cell(page,table,str(totals[rider.id]),Style.PALE)
	for i in range(tournament.results.size()):
		page.button(String(TranslationServer.translate("OMNIUM_VIEW_RESULTS")) + titles[i+1], page.open_result.bind(i))
		page.activity_actions(page.body, tournament, i)
func value(tournament: Dictionary, id: String, index: int) -> int:
	if index >= tournament.results.size(): return 0
	var result: Dictionary = tournament.results[index]
	return int(result.points.get(id,0)) if index == 3 else Scores.place_points(result.order.find(id)+1)
func change_sort(page: Node, column: int) -> void:
	descending = not descending if sort_column == column else column != 0
	sort_column = column; page.refresh()
