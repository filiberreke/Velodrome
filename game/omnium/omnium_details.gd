extends RefCounted
const Style := preload("res://menu_theme.gd")
const Formats := preload("res://omnium/omnium_formats.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
const Flags := preload("res://national_flags.gd")
var page
var menu
var active: Dictionary

func render(owner_page: Node) -> void:
	page = owner_page; menu = page.menu; active = page.manager.state.active
	var heading := HBoxContainer.new()
	page.body.add_child(heading)
	heading.add_child(menu.label("Jouw omnium", 32))
	heading.add_spacer(false)
	heading.add_child(menu.label("%d deelnemers" % active.riders.size(), 20, Style.MUTED))
	render_settings()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	page.body.add_child(columns)
	var races := VBoxContainer.new()
	races.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	races.size_flags_stretch_ratio = 1.45
	races.add_theme_constant_override("separation", 12)
	columns.add_child(races)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = 1.0
	sidebar.add_theme_constant_override("separation", 16)
	columns.add_child(sidebar)
	var settings := Formats.settings(active.format)
	var elimination_laps: int = Formats.race_laps(String(active.format), "elimination", active.riders.size())
	var specs := [
		["Losrijden", "Rustig opwarmen op de piste.", "Vrije duur", 0],
		["Scratch", "Kies je moment: de finish bepaalt je plaats.", distance_and_duration(int(settings.scratch)), 0],
		["Temporace", "Verzamel punten bij de doorkomsten.", distance_and_duration(int(settings.tempo)), 8],
		["Afvalling", "Blijf uit de gevarenzone · elke %d ronde(n) een afvaller." % settings.elimination_interval, distance_and_duration(elimination_laps), 5],
		["Puntenkoers", "Sprintpunten en rondewinst bepalen het eindklassement.", distance_and_duration(int(settings.points)), 3]
	]
	for i in range(specs.size()): race_card(races, specs[i], i - 1)
	var participants := panel(sidebar)
	participants.add_child(menu.label("Deelnemers", 24))
	participants.add_child(menu.label("%d renners · vaste tegenstanders" % active.riders.size(), 18, Style.MUTED))
	page.button("Startlijst →", page.edit_active, participants)
	var standings := panel(sidebar)
	standings.add_child(menu.label("Algemeen klassement", 24))
	if active.results.is_empty(): standings.add_child(menu.label("Nog geen wedstrijdresultaten", 17, Style.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 330
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	standings.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var totals := Scores.totals(active.riders, active.results)
	var riders: Array = active.riders.duplicate(true)
	riders.sort_custom(func(a, b): return Scores.compare(String(a.id), String(b.id), totals, active.results) < 0)
	var previous_score: Variant = null
	var rank := 0
	for i in range(riders.size()):
		var rider: Dictionary = riders[i]
		if previous_score == null or totals[rider.id] != previous_score: rank = i + 1
		previous_score = totals[rider.id]
		rider_row(list, rider, "%d." % rank, "%d" % totals[rider.id])

func distance_and_duration(laps: int) -> String:
	return "%d ronden · %s" % [laps, duration(laps)]

func duration(laps: int) -> String:
	# Estimate at 40 km/h on a 250 m track; never affects race timing.
	return "± %d min" % maxi(1, roundi(laps * 0.375))

func date_text(timestamp: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%02d · %02d:%02d UTC" % [date.day, date.month, int(date.year) % 100, date.hour, date.minute]

func panel(parent: Node) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", Style.panel(Style.PAPER, Style.LINE, 16, 16))
	parent.add_child(shell)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	shell.add_child(box)
	return box

func race_card(parent: Node, spec: Array, discipline_index: int) -> void:
	var completed: int = active.results.size()
	var done := discipline_index >= 0 and discipline_index < completed
	var next := discipline_index == completed
	var warmup := discipline_index < 0
	var available := done or next or warmup
	var card := Button.new()
	card.custom_minimum_size.y = 132
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not available
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, Style.panel(Style.PALE if next else Style.PAPER, Style.BLUE if next else Style.LINE, 12, 10))
	parent.add_child(card)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12; content.offset_top = 10; content.offset_right = -14; content.offset_bottom = -10
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)
	var image := TextureRect.new()
	image.texture = menu.previews[int(spec[3])].get_texture()
	image.custom_minimum_size.x = 160
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if not available: image.modulate = Color(0.48, 0.48, 0.48)
	content.add_child(image)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(copy)
	var ink: Color = Style.INK if available else Style.MUTED
	copy.add_child(menu.label(String(spec[0]) + (" · VOLTOOID" if done else " · VOLGENDE" if next else ""), 23, ink))
	var description: Label = menu.label(spec[1], 17, ink)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	copy.add_child(menu.label(spec[2], 17, Style.MUTED))
	if next and page.manager.deadline() > 0:
		copy.add_child(menu.label("Deadline: " + date_text(page.manager.deadline()), 17, Style.BLUE))
	if done:
		var result: Dictionary = active.results[discipline_index]
		var player_id := "player"
		for rider in active.riders:
			if rider.get("is_player", false): player_id = String(rider.id)
		var place: int = result.order.find(player_id) + 1
		var earned: int = int(result.get("points", {}).get(player_id, 0)) if discipline_index == 3 else Scores.place_points(place)
		copy.add_child(menu.label("%s · plaats %d · %d punten" % [date_text(int(result.get("finished_unix", 0))), place, earned], 17, Style.BLUE))
		card.pressed.connect(show_result.bind(discipline_index))
	elif warmup: card.pressed.connect(menu.start_omnium_warmup)
	elif next:
		if discipline_index == 0: card.pressed.connect(menu.start_omnium_scratch)
		elif discipline_index == 1: card.pressed.connect(menu.start_omnium_tempo)
		else: card.pressed.connect(show_start_notice)
	ignore_children(content)

func ignore_children(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_children(child)

func rider_row(parent: Node, rider: Dictionary, prefix: String, suffix: String) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	row.add_child(menu.label(prefix, 17, Style.MUTED))
	var flag := TextureRect.new(); flag.texture = Flags.texture(String(rider.country))
	flag.custom_minimum_size = Vector2(28, 20)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(flag)
	var name_label: Label = menu.label(String(rider.name), 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	row.add_child(menu.label(suffix, 18, Style.BLUE))

func popup(title: String) -> VBoxContainer:
	var dialog := AcceptDialog.new(); dialog.title = title
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(740, 480)
	dialog.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free)
	page.add_child(dialog); dialog.popup_centered()
	return list

func show_participants() -> void:
	var list := popup("Deelnemerslijst")
	for rider in active.riders:
		rider_row(list, rider, "", "Speler" if rider.get("is_player", false) else String(rider.get("category", "")))

func show_result(index: int) -> void:
	var list := popup(["Scratch", "Temporace", "Afvalling", "Puntenkoers"][index] + " · uitslag")
	var result: Dictionary = active.results[index]
	for i in range(result.order.size()):
		for rider in active.riders:
			if rider.id == result.order[i]:
				var points: int = int(result.get("points", {}).get(rider.id, 0)) if index == 3 else Scores.place_points(i + 1)
				var detail := "%d pt" % points
				if index == 1: detail = "%d koerspunten · %d omniumpt" % [int(result.get("race_points", {}).get(rider.id, 0)), points]
				rider_row(list, rider, "%d." % (i + 1), detail)

func show_start_notice() -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "De omniumwedstrijd is nog niet beschikbaar in deze ontwikkelversie."
	dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free)
	page.add_child(dialog); dialog.popup_centered()

func render_settings() -> void:
	var box := panel(page.body)
	var title_row := HBoxContainer.new(); box.add_child(title_row)
	title_row.add_child(menu.label("Speelinstellingen", 24))
	title_row.add_spacer(false)
	var locked := int(active.started) > 0
	title_row.add_child(menu.label("Vergrendeld · scratch gestart" if locked else "Bewerkbaar tot de start van de scratch", 17, Style.MUTED))
	var stop: Button = page.button("Omnium stoppen", page.confirm_stop, title_row)
	stop.tooltip_text = "Je resultaten blijven bewaard. Na stoppen kun je dit omnium niet hervatten."
	stop.add_theme_color_override("font_color", Color("a63838"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(menu.label("Format", 19))
	var format_picker := OptionButton.new()
	format_picker.custom_minimum_size = Vector2(330, 44)
	for title in ["Verkort omnium", "Mannenomnium · UCI-afstanden", "Vrouwenomnium · UCI-afstanden"]: format_picker.add_item(title)
	format_picker.select(["short", "men", "women"].find(String(active.format)))
	format_picker.disabled = locked
	format_picker.item_selected.connect(change_format)
	row.add_child(format_picker)
	row.add_spacer(false)
	row.add_child(menu.label("AI-sterkte", 19))
	var strength := SpinBox.new()
	strength.min_value = 40; strength.max_value = 120; strength.step = 5
	strength.value = float(active.strength); strength.suffix = "%"
	strength.custom_minimum_size = Vector2(150, 44)
	strength.editable = not locked
	strength.value_changed.connect(change_strength)
	row.add_child(strength)

func change_format(index: int) -> void:
	if int(active.started) != 0: return
	if page.manager.update_setup(active.riders, ["short", "men", "women"][index], float(active.strength), int(Time.get_unix_time_from_system())):
		active = page.manager.state.active
		page.refresh.call_deferred()
	else: settings_error()

func change_strength(value: float) -> void:
	if int(active.started) != 0: return
	if page.manager.update_setup(active.riders, String(active.format), value, int(Time.get_unix_time_from_system())):
		active = page.manager.state.active
	else: settings_error()

func settings_error() -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "Instellingen konden niet worden opgeslagen. " + page.manager.error
	dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free)
	page.add_child(dialog); dialog.popup_centered()
