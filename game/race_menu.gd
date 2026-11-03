extends Control
signal start_requested
signal difficulty_changed(value: float)
const MenuStyle := preload("res://menu_theme.gd")
const Preview := preload("res://mode_preview.gd")
const Records := preload("res://pursuit_records.gd")
var library = Records.new()
var records_store = preload("res://performance_records.gd").new()
var records_page: VBoxContainer
var pursuit_flow: VBoxContainer
var startlist_page: VBoxContainer
var footer_label: Label
var team_options
var team_scroll: ScrollContainer
var pursuit_options
var demo_settings: VBoxContainer
var time_trial_settings: VBoxContainer
var time_trial_start: OptionButton
var time_trial_distance: OptionButton
var time_trial_reference: OptionButton
var bridge_label: Label
var bridge_seen := false
var bridge_live := false
var bridge_unavailable := false
const MODES := [
	{"key": "scratch", "title": "Scratch", "hint": "Eén peloton. Eén finish.", "detail": "Start met één geneutraliseerde ronde. Blijf uit de wind, kies je moment en sprint als eerste over de meet.", "race_id": 0},
	{"key": "pursuit", "title": "Achtervolging", "hint": "Jij, je tegenstander en de klok.", "detail": "Twee renners starten tegenover elkaar. Jaag op de beste tijd of haal je tegenstander in.", "race_id": 4},
	{"key": "team_pursuit", "title": "Ploegenachtervolging", "hint": "Samen op jacht naar de snelste tijd.", "detail": "Jij bepaalt het tempo. Stuur op kop naar rechts voor een automatische wissel; volg daarna het wattagedoel.", "race_id": 5},
	{"key": "points", "title": "Puntenkoers", "hint": "Elke sprint een nieuwe kans.", "detail": "Start met één geneutraliseerde ronde. Elke 10 ronden: 5–3–2–1 punten. Dubbele punten aan de finish. Een ronde winnen of verliezen geeft +20 of −20 punten.", "race_id": 1},
	{"key": "madison", "title": "Ploegkoers", "hint": "Wissel af. Blijf in de wedstrijd.", "detail": "Rijd als duo, los elkaar af en strijd samen om punten en ronden.", "race_id": 6},
	{"key": "elimination", "title": "Afvalling", "hint": "Elke twee ronden valt de laatste af.", "detail": "Start met één geneutraliseerde ronde. Iedere twee ronden valt de laatste renner met het achterwiel over de meet af. Blijf uit de gevarenzone!", "race_id": 2},
	{"key": "keirin", "title": "Keirin", "hint": "Volg het tempo. Ontketen je sprint.", "detail": "Bouw snelheid op achter de gangmaker en kies je moment zodra de finale begint.", "race_id": 3},
	{"key": "time_trial", "title": "Tijdrit", "hint": "Jij tegen de klok.", "detail": "500 m of 1 km met staande of vliegende start en vergelijking elke 125 meter.", "race_id": 7},
	{"key": "tempo", "title": "Temporace", "hint": "Houd het tempo hoog.", "detail": "Deze discipline wordt later toegevoegd.", "race_id": -1},
	{"key": "records", "title": "Records", "hint": "Jouw snelste tijden aller tijden.", "detail": "Top 10 achtervolging en ploegenachtervolging.", "race_id": -1}
]
const INK := MenuStyle.INK
const MUTED := MenuStyle.MUTED
const ACCENT := MenuStyle.BLUE
const RECORDS_INDEX := 9
const PLAYABLE := [0, 1, 2, 3, 5, 7]
const DISPLAY_ORDER := [0, 1, 2, 3, 5, 4, 6, 7, 8, 9]
var gallery_grid: GridContainer
var page := 1
var selected := 0
var field_settings := {0: [8, 10], 3: [16, 40], 5: [12, 22]}
var cards: Array[Button] = []
var previews: Array[SubViewport] = []
var choice_page: VBoxContainer
var settings_page: CenterContainer
var breadcrumb: Label
var page_title: Label
var selected_title: Label
var selected_description: Label
var selected_art: TextureRect
var status_label: Label
var start_button: Button
var back_button: Button
var count_input: SpinBox
var elimination_count_picker: OptionButton
var laps_input: SpinBox
var demo_power_input: SpinBox
var difficulty_slider: HSlider
var difficulty_label: Label
var race_settings: VBoxContainer

static func panel_style(colour: Color, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	return style

func label(text: String, font_size: int, colour: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_color_override("font_color", colour)
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _ready() -> void:
	theme = MenuStyle.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.07, 0.16, 0.27, 0.12)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	var brand_row := HBoxContainer.new()
	brand_row.add_theme_constant_override("separation", 22)
	outer.add_child(brand_row)
	brand_row.add_child(MenuStyle.logo())
	brand_row.add_spacer(false)
	bridge_label = label("Demo beschikbaar", 18, MUTED)
	bridge_label.custom_minimum_size.x = 360
	bridge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bridge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bridge_label.add_theme_stylebox_override("normal", MenuStyle.panel(MenuStyle.IVORY, MenuStyle.LINE, 12, 10))
	bridge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand_row.add_child(bridge_label)
	var settings_space := Control.new()
	settings_space.custom_minimum_size.x = 275
	brand_row.add_child(settings_space)
	var shell := PanelContainer.new()
	shell.name = "IvoryMenuSheet"
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper := MenuStyle.panel(MenuStyle.IVORY, MenuStyle.LINE, 26, 20)
	paper.border_color = MenuStyle.WOOD
	paper.border_width_top = 5
	shell.add_theme_stylebox_override("panel", paper)
	outer.add_child(shell)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	shell.add_child(layout)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	layout.add_child(title_row)
	page_title = label("Kies jouw wedstrijd", 44)
	page_title.add_theme_font_override("font", MenuStyle.heading())
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(page_title)
	breadcrumb = label("01  Spelvorm     /     02  Instellingen", 18, MUTED)
	breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(breadcrumb)
	choice_page = VBoxContainer.new()
	choice_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(choice_page)
	gallery_grid = GridContainer.new()
	gallery_grid.columns = 5
	gallery_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery_grid.add_theme_constant_override("h_separation", 18)
	gallery_grid.add_theme_constant_override("v_separation", 18)
	choice_page.add_child(gallery_grid)
	cards.resize(MODES.size())
	previews.resize(MODES.size())
	for i in DISPLAY_ORDER:
		if i != RECORDS_INDEX: previews[i] = Preview.make(self, MODES[i]["key"])
		var card := Button.new()
		card.name = MODES[i]["key"]
		card.custom_minimum_size = Vector2(0, 282)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = MODES[i]["hint"]
		card.add_theme_stylebox_override("normal", MenuStyle.panel(MenuStyle.PAPER, MenuStyle.LINE, 0, 12))
		card.add_theme_stylebox_override("hover", MenuStyle.panel(MenuStyle.PALE, MenuStyle.BLUE, 0, 12))
		card.add_theme_stylebox_override("pressed", MenuStyle.panel(MenuStyle.PALE, MenuStyle.BLUE, 0, 12))
		gallery_grid.add_child(card)
		cards[i] = card
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_right = -12
		content.offset_top = 12
		content.offset_bottom = -12
		content.add_theme_constant_override("separation", 10)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		var art: Control
		if i == RECORDS_INDEX:
			art = preload("res://records_tile_art.gd").new()
		else:
			var image := TextureRect.new()
			image.texture = previews[i].get_texture()
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art = image
		art.custom_minimum_size = Vector2(0, 164)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var mode_title := label("Ploegen\nachtervolging" if i == 2 else MODES[i]["title"], 26)
		mode_title.add_theme_font_override("font", MenuStyle.heading())
		mode_title.custom_minimum_size.y = 62
		mode_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mode_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(mode_title)
		var status := label("TOP 10" if i == RECORDS_INDEX else ("SPEEL" if i in PLAYABLE else "BINNENKORT"), 13, MUTED)
		status.name = "Status"
		status.position = Vector2(20, 18)
		# Available modes need no extra badge; keep status available to accessibility/tests.
		status.visible = i not in PLAYABLE
		status.add_theme_stylebox_override("normal", MenuStyle.panel(MenuStyle.IVORY, MenuStyle.LINE, 5, 6))
		card.add_child(status)
		card.pressed.connect(select_mode.bind(i))
	_build_settings(layout)
	pursuit_flow = preload("res://pursuit_flow.gd").new()
	pursuit_flow.menu = self
	layout.add_child(pursuit_flow)
	startlist_page = preload("res://startlist_page.gd").new()
	startlist_page.menu = self
	layout.add_child(startlist_page)
	records_page = preload("res://records_page.gd").new()
	records_page.store = records_store
	layout.add_child(records_page)
	records_page.back_requested.connect(show_choices)
	footer_label = label("Pijltjes: kiezen  •  A: bevestigen  •  B: terug  •  Z / F10: instellingen", 17, MUTED)
	layout.add_child(footer_label)
	show_choices()

func _build_settings(layout: VBoxContainer) -> void:
	settings_page = CenterContainer.new()
	settings_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(settings_page)
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(1260, 0)
	shell.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.PAPER, MenuStyle.LINE, 22))
	settings_page.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	shell.add_child(row)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 540
	info.add_theme_constant_override("separation", 18)
	row.add_child(info)
	selected_art = TextureRect.new()
	selected_art.custom_minimum_size = Vector2(540, 260)
	selected_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	info.add_child(selected_art)
	selected_title = label("", 36)
	info.add_child(selected_title)
	selected_description = label("", 22, MUTED)
	selected_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(selected_description)
	var options := VBoxContainer.new()
	options.custom_minimum_size.x = 570
	options.add_theme_constant_override("separation", 18)
	row.add_child(options)
	options.add_child(label("Jouw wedstrijd", 30))
	status_label = label("", 21, ACCENT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(status_label)
	race_settings = VBoxContainer.new()
	race_settings.add_theme_constant_override("separation", 16)
	options.add_child(race_settings)
	count_input = _number(race_settings, "Deelnemers · inclusief jou", 6, 12, 8)
	elimination_count_picker = OptionButton.new()
	for amount in [4, 12, 16]: elimination_count_picker.add_item("%d deelnemers" % amount, amount)
	elimination_count_picker.select(1)
	race_settings.add_child(elimination_count_picker)
	elimination_count_picker.visible = false
	laps_input = _number(race_settings, "Ronden · 250 meter per ronde", 1, 30, 10)
	difficulty_label = label("AI-sterkte · 80%", 22)
	race_settings.add_child(difficulty_label)
	difficulty_slider = HSlider.new()
	difficulty_slider.min_value = 30
	difficulty_slider.max_value = 100
	difficulty_slider.step = 10
	difficulty_slider.value = 80
	difficulty_slider.custom_minimum_size.y = 36
	race_settings.add_child(difficulty_slider)
	difficulty_slider.value_changed.connect(func(value: float) -> void:
		difficulty_label.text = "AI-sterkte · %d%%" % int(value)
		difficulty_changed.emit(value))
	pursuit_options = preload("res://pursuit_options.gd").new()
	pursuit_options.library = library
	options.add_child(pursuit_options)
	pursuit_options.changed.connect(_pursuit_changed)
	team_options = preload("res://team_pursuit_options.gd").new()
	team_scroll = ScrollContainer.new()
	team_scroll.custom_minimum_size.y = 350
	team_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options.add_child(team_scroll)
	team_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_scroll.add_child(team_options)
	team_options.changed.connect(_pursuit_changed)
	time_trial_settings = VBoxContainer.new()
	time_trial_settings.add_theme_constant_override("separation", 12)
	race_settings.get_parent().add_child(time_trial_settings)
	time_trial_settings.add_child(label("Startwijze", 22))
	time_trial_start = OptionButton.new()
	time_trial_start.add_item("Staande start")
	time_trial_start.add_item("Vliegende start · 1 aanloopronde")
	time_trial_settings.add_child(time_trial_start)
	time_trial_settings.add_child(label("Afstand", 22))
	time_trial_distance = OptionButton.new()
	time_trial_distance.add_item("500 meter · 2 ronden", 500)
	time_trial_distance.add_item("1 kilometer · 4 ronden", 1000)
	time_trial_distance.select(1)
	time_trial_settings.add_child(time_trial_distance)
	time_trial_settings.add_child(label("Vergelijken met", 22))
	time_trial_reference = OptionButton.new()
	for item in ["Laatste rit", "Recent PR · 60 dagen", "All-time PR", "Geen vergelijking"]:
		time_trial_reference.add_item(item)
	time_trial_settings.add_child(time_trial_reference)
	demo_settings = VBoxContainer.new()
	demo_settings.add_theme_constant_override("separation", 8)
	options.add_child(demo_settings)
	demo_power_input = _number(demo_settings, "Demo-startvermogen · zonder trainer (W)", 0, 900, 300)
	demo_power_input.step = 25
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 14)
	options.add_child(navigation)
	back_button = Button.new()
	back_button.text = "←  Spelvormen"
	back_button.custom_minimum_size = Vector2(210, 60)
	back_button.add_theme_font_size_override("font_size", 21)
	back_button.pressed.connect(show_choices)
	navigation.add_child(back_button)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(310, 60)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", panel_style(ACCENT))
	start_button.add_theme_stylebox_override("hover", panel_style(MenuStyle.BLUE.lightened(.10)))
	MenuStyle.primary(start_button)
	start_button.pressed.connect(func() -> void:
		if not start_button.disabled and (selected in [0, 3, 5, 7] or (selected in [1, 2] and (pursuit_options if selected == 1 else team_options).can_start())):
			if selected in [0, 3, 5]: show_startlist()
			else: start_requested.emit())
	navigation.add_child(start_button)

func _number(parent_node: VBoxContainer, title: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var caption := label(title, 22)
	parent_node.add_child(caption)
	var input := SpinBox.new()
	input.set_meta("caption", caption)
	input.min_value = minimum
	input.max_value = maximum
	input.step = 1
	input.value = initial
	input.rounded = true
	input.custom_minimum_size.y = 52
	input.add_theme_font_size_override("font_size", 24)
	input.get_line_edit().add_theme_font_size_override("font_size", 24)
	parent_node.add_child(input)
	return input

func show_choices() -> void:
	footer_label.show()
	page_title.add_theme_font_size_override("font_size",44)
	if startlist_page != null: startlist_page.hide()
	if pursuit_flow != null: pursuit_flow.hide()
	if page == 2 and selected in [0, 3, 5]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	page = 1
	page_title.text = "Kies jouw wedstrijd"
	choice_page.show()
	settings_page.hide()
	records_page.hide()
	breadcrumb.text = "01  Spelvorm     /     02  Instellingen"
	if not cards.is_empty():
		cards[selected].grab_focus.call_deferred()

func select_mode(index: int) -> void:
	if page == 2 and selected in [0, 3, 5]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	footer_label.show()
	page_title.add_theme_font_size_override("font_size",44)
	selected = clampi(index, 0, MODES.size() - 1)
	if selected == RECORDS_INDEX:
		show_records()
		return
	records_page.hide()
	if startlist_page != null: startlist_page.hide()
	if pursuit_flow != null: pursuit_flow.hide()
	page = 2
	page_title.text = "Stel je wedstrijd in"
	choice_page.hide()
	settings_page.show()
	breadcrumb.text = "01  Spelvorm     /     02  Instellingen"
	selected_title.text = MODES[selected]["title"]
	selected_description.text = MODES[selected]["detail"]
	selected_art.texture = previews[selected].get_texture()
	race_settings.visible = selected in [0, 3, 5]
	time_trial_settings.visible = selected == 7
	count_input.visible = selected != 5
	count_input.get_meta("caption").visible = selected != 5
	elimination_count_picker.visible = selected == 5
	laps_input.visible = selected != 5
	laps_input.get_meta("caption").visible = selected != 5
	if selected in [0, 3]:
		count_input.max_value = 16 if selected == 3 else 12
		laps_input.max_value = 120 if selected == 3 else 30
		laps_input.min_value = 10 if selected == 3 else 1
		laps_input.step = 10 if selected == 3 else 1
		count_input.value = field_settings[selected][0]
		laps_input.value = field_settings[selected][1]
	if selected == 5:
		for idx in range(elimination_count_picker.item_count):
			if elimination_count_picker.get_item_id(idx) == field_settings[5][0]: elimination_count_picker.select(idx)
	pursuit_options.visible = selected == 1
	team_options.visible = selected == 2
	team_scroll.visible = selected == 2
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 7] and not bridge_seen and not bridge_unavailable
	status_label.text = "Klaar voor de start. Stel je wedstrijd in." if selected in [0, 1, 2, 3, 5, 7] else "Binnenkort speelbaar. Deze spelvorm is nog in ontwikkeling."
	start_button.disabled = selected not in [0, 1, 2, 3, 5, 7]
	start_button.text = "Startlijst →" if selected in [0, 3, 5] else "Start wedstrijd →" if selected in [1, 2, 7] else "Binnenkort"
	if selected in [1, 2]:
		(pursuit_options if selected == 1 else team_options).refresh_rides()
	update_bridge_status(bridge_seen, bridge_live, bridge_unavailable)
	back_button.grab_focus.call_deferred()
	if selected in [1,2]:
		settings_page.hide()
		footer_label.hide()
		pursuit_flow.begin(selected == 2)

func update_bridge_status(seen: bool, live: bool, unavailable: bool) -> void:
	bridge_seen = seen
	bridge_live = live
	bridge_unavailable = unavailable
	bridge_label.text = "●  Trainer verbonden" if live else ("Trainer gevonden · wacht op gegevens" if seen else "Demo beschikbaar · geen trainer")
	if unavailable:
		bridge_label.text = "Verbinding bezet · sluit de andere spelinstantie"
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 7] and not seen and not unavailable
	start_button.disabled = unavailable or selected not in [0, 1, 2, 3, 5, 7]
	if selected in [1, 2]:
		start_button.disabled = start_button.disabled or not (pursuit_options if selected == 1 else team_options).can_start()
	if pursuit_flow != null and pursuit_flow.visible: pursuit_flow.update_bridge()
	if startlist_page != null and startlist_page.visible: startlist_page.update_bridge()

func _pursuit_changed() -> void:
	if selected not in [1, 2] or start_button == null:
		return
	var current = pursuit_options if selected == 1 else team_options
	start_button.disabled = bridge_unavailable or not current.can_start()
	status_label.text = "Kies je afstand en tegenstander." if current.can_start() else "Nog geen opgeslagen rit op deze afstand. Rijd eerst tegen de AI en bewaar je rit."

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and page in [2, 3, 4, 5] and event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if page == 5: startlist_page.back()
		elif selected in [1,2] and pursuit_flow.visible: pursuit_flow.back()
		else: show_choices()
		get_viewport().set_input_as_handled()

func bridge_action(button: String) -> void:
	if not visible:
		return
	if page == 5:
		startlist_page.bridge_action(button)
		return
	if pursuit_options != null and is_instance_valid(pursuit_options.active_picker):
		pursuit_options.active_picker.bridge_action(button)
		return
	if selected in [1,2] and pursuit_flow.visible:
		pursuit_flow.bridge_action(button)
		return
	if button == "B":
		if page in [2, 3]: show_choices()
		return
	var actions := {"LEFT": "ui_left", "RIGHT": "ui_right", "UP": "ui_up", "DOWN": "ui_down", "A": "ui_accept"}
	if not actions.has(button): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		if page == 1: cards[selected].grab_focus()
		else: back_button.grab_focus()
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = actions[button]
		event.pressed = pressed
		get_viewport().push_input(event)

func show_records() -> void:
	footer_label.hide()
	page_title.add_theme_font_size_override("font_size",44)
	if startlist_page != null: startlist_page.hide()
	if pursuit_flow != null: pursuit_flow.hide()
	page = 3
	page_title.text = "Records"
	breadcrumb.text = "Jouw snelste tijden op de piste"
	choice_page.hide(); settings_page.hide(); records_page.show()
	records_page.open_records()
	records_page.back_button.grab_focus.call_deferred()

func show_startlist() -> void:
	if selected not in [0, 3, 5] or bridge_unavailable: return
	field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	page = 5
	choice_page.hide()
	settings_page.hide()
	pursuit_flow.hide()
	records_page.hide()
	footer_label.hide()
	page_title.text = "Jouw startlijst"
	breadcrumb.text = "01  Wedstrijdinstellingen     /     02  Startlijst"
	startlist_page.begin()
