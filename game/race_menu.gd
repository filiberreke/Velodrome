extends Control
signal start_requested
signal difficulty_changed(value: float)
const Preview := preload("res://mode_preview.gd")
const Records := preload("res://pursuit_records.gd")
var library = Records.new()
var records_store = preload("res://performance_records.gd").new()
var records_page: VBoxContainer
var team_options
var team_scroll: ScrollContainer
var pursuit_options
var demo_settings: VBoxContainer
var bridge_label: Label
var bridge_seen := false
var bridge_live := false
var bridge_unavailable := false
const MODES := [
	{"key": "scratch", "title": "Scratch", "hint": "Eén peloton. Eén finish.", "detail": "Blijf uit de wind, kies je moment en sprint als eerste over de meet.", "race_id": 0},
	{"key": "pursuit", "title": "Achtervolging", "hint": "Jij, je tegenstander en de klok.", "detail": "Twee renners starten tegenover elkaar. Jaag op de beste tijd of haal je tegenstander in.", "race_id": 4},
	{"key": "team_pursuit", "title": "Ploegenachtervolging", "hint": "Samen op jacht naar de snelste tijd.", "detail": "Jij bepaalt het tempo. Stuur op kop naar rechts voor een automatische wissel; volg daarna het wattagedoel.", "race_id": 5},
	{"key": "points", "title": "Puntenkoers", "hint": "Elke sprint een nieuwe kans.", "detail": "Elke 10 ronden: 5–3–2–1 punten. Dubbele punten aan de finish. Een ronde winnen of verliezen geeft +20 of −20 punten.", "race_id": 1},
	{"key": "madison", "title": "Ploegkoers", "hint": "Wissel af. Blijf in de wedstrijd.", "detail": "Rijd als duo, los elkaar af en strijd samen om punten en ronden.", "race_id": 6},
	{"key": "keirin", "title": "Keirin", "hint": "Volg het tempo. Ontketen je sprint.", "detail": "Bouw snelheid op achter de gangmaker en kies je moment zodra de finale begint.", "race_id": 3},
	{"key": "records", "title": "Records", "hint": "Jouw snelste tijden aller tijden.", "detail": "Top 10 achtervolging en ploegenachtervolging.", "race_id": -1}
]
const INK := Color("f3f5fa")
const MUTED := Color("a8bdce")
const ACCENT := Color("51d7df")
var page := 1
var selected := 0
var field_settings := {0: [8, 10], 3: [16, 40]}
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.05, 0.09, 0.58)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	margin.add_child(layout)
	var brand_row := HBoxContainer.new()
	layout.add_child(brand_row)
	var brand := label("VELODROME 250", 19, ACCENT)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_row.add_child(brand)
	bridge_label = label("DEMO · nog geen bridge-telemetrie ontvangen", 18, MUTED)
	bridge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bridge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_row.add_child(bridge_label)
	page_title = label("Kies jouw wedstrijd", 48)
	layout.add_child(page_title)
	breadcrumb = label("01  SPELVORM     /     02  WEDSTRIJDINSTELLINGEN", 18, MUTED)
	layout.add_child(breadcrumb)
	choice_page = VBoxContainer.new()
	choice_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(choice_page)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	choice_page.add_child(grid)
	for i in range(MODES.size()):
		previews.append(Preview.make(self, MODES[i]["key"]) if MODES[i]["key"] != "records" else null)
		var card := Button.new()
		card.name = MODES[i]["key"]
		card.custom_minimum_size = Vector2(0, 314)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal", panel_style(Color(0.035, 0.085, 0.14, 0.96), Color("2b475b")))
		card.add_theme_stylebox_override("hover", panel_style(Color("153b50"), ACCENT))
		card.add_theme_stylebox_override("pressed", panel_style(Color("1b4b60"), ACCENT))
		card.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, ACCENT))
		grid.add_child(card)
		cards.append(card)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 18
		content.offset_right = -18
		content.offset_top = 14
		content.offset_bottom = -16
		content.add_theme_constant_override("separation", 8)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		var art: Control
		if MODES[i]["key"] == "records":
			art = preload("res://records_tile_art.gd").new()
		else:
			var image := TextureRect.new()
			image.texture = previews[i].get_texture()
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art = image
		art.custom_minimum_size = Vector2(0, 172)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(heading)
		var mode_title := label(MODES[i]["title"], 25)
		mode_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(mode_title)
		var status := label("TOP 10" if i == 6 else ("SPEEL" if i in [0, 1, 2, 3] else "BINNENKORT"), 13, ACCENT if i in [0, 1, 2, 3, 6] else MUTED)
		status.name = "Status"
		heading.add_child(status)
		var hint := label(MODES[i]["hint"], 19, MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(hint)
		card.pressed.connect(select_mode.bind(i))
	_build_settings(layout)
	records_page = preload("res://records_page.gd").new()
	records_page.store = records_store
	layout.add_child(records_page)
	records_page.back_requested.connect(show_choices)
	var footer := label("Kies een spelvorm om verder te gaan.    •    F10  Instellingen", 17, MUTED)
	layout.add_child(footer)
	show_choices()

func _build_settings(layout: VBoxContainer) -> void:
	settings_page = CenterContainer.new()
	settings_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(settings_page)
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(1260, 0)
	shell.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.085, 0.14, 0.97), Color("2b475b")))
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
	start_button.add_theme_color_override("font_color", Color("092a39"))
	start_button.add_theme_color_override("font_hover_color", Color("092a39"))
	start_button.add_theme_stylebox_override("normal", panel_style(ACCENT))
	start_button.add_theme_stylebox_override("hover", panel_style(Color("89eef0")))
	start_button.pressed.connect(func() -> void:
		if selected in [0, 3] or (selected in [1, 2] and (pursuit_options if selected == 1 else team_options).can_start()):
			start_requested.emit())
	navigation.add_child(start_button)

func _number(parent_node: VBoxContainer, title: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	parent_node.add_child(label(title, 22))
	var input := SpinBox.new()
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
	if page == 2 and selected in [0, 3]: field_settings[selected] = [int(count_input.value), int(laps_input.value)]
	page = 1
	page_title.text = "Kies jouw wedstrijd"
	choice_page.show()
	settings_page.hide()
	records_page.hide()
	breadcrumb.text = "01  SPELVORM     /     02  WEDSTRIJDINSTELLINGEN"
	if not cards.is_empty():
		cards[selected].grab_focus.call_deferred()

func select_mode(index: int) -> void:
	if page == 2 and selected in [0, 3]: field_settings[selected] = [int(count_input.value), int(laps_input.value)]
	selected = clampi(index, 0, MODES.size() - 1)
	if selected == 6:
		show_records()
		return
	records_page.hide()
	page = 2
	page_title.text = "Stel je wedstrijd in"
	choice_page.hide()
	settings_page.show()
	breadcrumb.text = "01  SPELVORM     /     02  WEDSTRIJDINSTELLINGEN"
	selected_title.text = MODES[selected]["title"]
	selected_description.text = MODES[selected]["detail"]
	selected_art.texture = previews[selected].get_texture()
	race_settings.visible = selected in [0, 3]
	if selected in [0, 3]:
		count_input.max_value = 16 if selected == 3 else 12
		laps_input.max_value = 120 if selected == 3 else 30
		laps_input.min_value = 10 if selected == 3 else 1
		laps_input.step = 10 if selected == 3 else 1
		count_input.value = field_settings[selected][0]
		laps_input.value = field_settings[selected][1]
	pursuit_options.visible = selected == 1
	team_options.visible = selected == 2
	team_scroll.visible = selected == 2
	demo_settings.visible = selected in [0, 1, 2, 3] and not bridge_seen and not bridge_unavailable
	status_label.text = "Klaar voor de start. Stel je wedstrijd in." if selected in [0, 1, 2, 3] else "Binnenkort speelbaar. Deze spelvorm is nog in ontwikkeling."
	start_button.disabled = selected not in [0, 1, 2, 3]
	start_button.text = "Start wedstrijd  →" if selected in [0, 1, 2, 3] else "Binnenkort"
	if selected in [1, 2]:
		(pursuit_options if selected == 1 else team_options).refresh_rides()
	update_bridge_status(bridge_seen, bridge_live, bridge_unavailable)
	back_button.grab_focus.call_deferred()

func update_bridge_status(seen: bool, live: bool, unavailable: bool) -> void:
	bridge_seen = seen
	bridge_live = live
	bridge_unavailable = unavailable
	bridge_label.text = "Bridge LIVE · trainertelemetrie ontvangen" if live else ("Bridge ontvangen · wacht op geldige trainerdata" if seen else "DEMO · nog geen bridge-telemetrie ontvangen")
	if unavailable:
		bridge_label.text = "Bridge niet beschikbaar: UDP 51723 bezet. Sluit andere spelinstanties en herstart Godot."
	demo_settings.visible = selected in [0, 1, 2, 3] and not seen and not unavailable
	start_button.disabled = unavailable or selected not in [0, 1, 2, 3]
	if selected in [1, 2]:
		start_button.disabled = start_button.disabled or not (pursuit_options if selected == 1 else team_options).can_start()

func _pursuit_changed() -> void:
	if selected not in [1, 2] or start_button == null:
		return
	var current = pursuit_options if selected == 1 else team_options
	start_button.disabled = bridge_unavailable or not current.can_start()
	status_label.text = "Kies je afstand en tegenstander." if current.can_start() else "Nog geen opgeslagen rit op deze afstand. Rijd eerst tegen de AI en bewaar je rit."

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and page in [2, 3] and event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		show_choices()
		get_viewport().set_input_as_handled()

func show_records() -> void:
	page = 3
	page_title.text = "Records"
	breadcrumb.text = "ALL-TIME TOP 10 · ACHTERVOLGING & PLOEGENACHTERVOLGING"
	choice_page.hide(); settings_page.hide(); records_page.show()
	records_page.refresh(true)
	records_page.back_button.grab_focus.call_deferred()
