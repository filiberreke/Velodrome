extends Control
signal start_requested
signal difficulty_changed(value: float)
signal training_environment_requested(active: bool)
signal workout_environment_requested(active: bool)
signal piste_environment_requested(active: bool)
signal exercise_environment_requested(active: bool)
signal training_upload_requested(activity: Dictionary)
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
var bridge_status_text := "Demo beschikbaar"
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
	{"key": "keirin", "title": "Keirin", "hint": "Volg het tempo. Ontketen je sprint.", "detail": "Zes renners, gelote startposities. Drie ronden begeleid achter de derny, daarna drie vrije ronden. Blijf in het wiel en kies je sprintmoment.", "race_id": 3},
	{"key": "time_trial", "title": "Tijdrit", "hint": "Jij tegen de klok.", "detail": "500 m of 1 km met staande of vliegende start en vergelijking elke 125 meter.", "race_id": 7},
	{"key": "tempo", "title": "Temporace", "hint": "Houd het tempo hoog.", "detail": "Deze discipline wordt later toegevoegd.", "race_id": -1},
	{"key": "records", "title": "Records", "hint": "Jouw snelste tijden aller tijden.", "detail": "Top 10 achtervolging en ploegenachtervolging.", "race_id": -1}
]
const INK := MenuStyle.INK
const MUTED := MenuStyle.MUTED
const ACCENT := MenuStyle.BLUE
const RECORDS_INDEX := 9
const PLAYABLE := [0, 1, 2, 3, 5, 6, 7]
const DISPLAY_ORDER := [0, 1, 2, 3, 5, 4, 6, 7, 8, 9]
var gallery_grid: GridContainer
var page := 1
var selected := 0
var field_settings := {0: [8, 10], 3: [16, 40], 5: [12, 22], 6: [6, 6]}
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
var keirin_derny: SpinBox
var race_settings: VBoxContainer
var hub_page: VBoxContainer
var training_page: VBoxContainer
var piste_page: VBoxContainer
var derny_page: VBoxContainer
var exercise_page: VBoxContainer
var training_history_page: VBoxContainer
var training_store = preload("res://training_store.gd").new()
var tournament_page: VBoxContainer
var ftp_page
var workout_editor_page: VBoxContainer
var workout_play_page: VBoxContainer
var workout_library = preload("res://workout_library.gd").new()
var workout_grid: GridContainer
var ftp_tile: Button
var editor_tile: Button
var saved_workout_tiles: Array[Button] = []
var hub_button: Button
var races_back: Button
var menu_margin: MarginContainer
var menu_layout: VBoxContainer
var menu_tint: ColorRect
var session_panel: PanelContainer

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
	menu_tint = tint
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.07, 0.16, 0.27, 0.12)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var margin := MarginContainer.new()
	menu_margin = margin
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
	# Reserve the shared status/setup button's space in the header. The button
	# lives above the pause layer, so the same control remains usable in a race.
	var bridge_space := Control.new()
	bridge_space.custom_minimum_size = Vector2(475, 52)
	bridge_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_row.add_child(bridge_space)
	var settings_space := Control.new()
	settings_space.custom_minimum_size.x = 224
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
	menu_layout = layout
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
	_build_hub(layout)
	show_hub()

func _hub_button(parent: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 90
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _hub_tile(parent: Container, caption: String, description: String, preview_indices: Array[int], action: Callable) -> Button:
	var button := Button.new()
	button.name = caption
	button.custom_minimum_size.y = 200
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = caption + " · " + description
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, MenuStyle.panel(MenuStyle.PAPER if state == "normal" else MenuStyle.PALE, MenuStyle.LINE if state == "normal" else ACCENT, 0, 12))
	parent.add_child(button)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 24
	content.offset_right = -16
	content.offset_top = 16
	content.offset_bottom = -16
	content.add_theme_constant_override("separation", 20)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(copy)
	var title := label(caption + "  →", 34)
	title.add_theme_font_override("font", MenuStyle.heading())
	copy.add_child(title)
	var detail := label(description, 19, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(detail)
	var images := HBoxContainer.new()
	images.name = "Afbeeldingen"
	images.add_theme_constant_override("separation", 10)
	images.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(images)
	if preview_indices.is_empty():
		var chart := preload("res://training_tile_art.gd").new()
		chart.custom_minimum_size.x = 280
		chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		images.add_child(chart)
	for index in preview_indices:
		var image := TextureRect.new()
		image.name = MODES[index]["key"]
		image.texture = previews[index].get_texture()
		image.custom_minimum_size.x = 260
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		images.add_child(image)
	button.pressed.connect(action)
	return button

func _build_hub(layout: VBoxContainer) -> void:
	hub_page = VBoxContainer.new()
	hub_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_page.add_theme_constant_override("separation", 16)
	layout.add_child(hub_page)
	var first_row := HBoxContainer.new()
	first_row.name = "WedstrijdenEnToernooien"
	first_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	first_row.add_theme_constant_override("separation", 16)
	hub_page.add_child(first_row)
	hub_button = _hub_tile(first_row, "Wedstrijden", "Kies je discipline en ga voor de winst.", [0], show_choices)
	_hub_tile(first_row, "Toernooien", "Binnenkort: meerdere wedstrijden, één klassement.", [2], show_tournaments)
	var second_row := HBoxContainer.new()
	second_row.name = "ErgEnPistetraining"
	second_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	second_row.add_theme_constant_override("separation", 16)
	hub_page.add_child(second_row)
	_hub_tile(second_row, "ERG-training", "Workouts op vermogen en FTP-tests.", [], show_training)
	_hub_tile(second_row, "Pistetraining", "Derny, vliegende start en een ronde winnen.", [7], show_piste_training)
	races_back = _hub_button(choice_page, "← Hoofdmenu", show_hub)
	races_back.custom_minimum_size.y = 46
	training_page = VBoxContainer.new()
	training_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(training_page)
	var workout_scroll := ScrollContainer.new()
	workout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	training_page.add_child(workout_scroll)
	workout_grid = GridContainer.new()
	workout_grid.columns = 3
	workout_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workout_grid.add_theme_constant_override("h_separation",16)
	workout_grid.add_theme_constant_override("v_separation",16)
	workout_scroll.add_child(workout_grid)
	_hub_button(training_page,"← Hoofdmenu",show_hub)
	piste_page = VBoxContainer.new()
	piste_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(piste_page)
	_hub_button(piste_page, "Dernytraining  →", show_derny)
	_hub_button(piste_page, "Vliegende start  →", show_piste_exercise.bind("flying_start"))
	_hub_button(piste_page, "Neem een ronde  →", show_piste_exercise.bind("take_lap"))
	piste_page.add_child(label("Vaste pistesessies, door ons voorbereid. Geen import of export.", 22, MUTED))
	_hub_button(piste_page, "Opgeslagen trainingen  →", show_training_history)
	_hub_button(piste_page, "← Hoofdmenu", show_hub)
	derny_page = preload("res://derny_training.gd").new()
	layout.add_child(derny_page)
	derny_page.back_requested.connect(show_piste_training)
	derny_page.environment_requested.connect(_piste_environment)
	derny_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	exercise_page = preload("res://piste_exercise_page.gd").new()
	layout.add_child(exercise_page)
	exercise_page.back_requested.connect(show_piste_training)
	exercise_page.environment_requested.connect(_exercise_environment)
	exercise_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	training_history_page = preload("res://training_history.gd").new()
	training_history_page.menu = self
	layout.add_child(training_history_page)
	tournament_page = VBoxContainer.new()
	tournament_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tournament_page)
	tournament_page.add_child(label("Toernooien worden later toegevoegd.", 28))
	_hub_button(tournament_page, "← Hoofdmenu", show_hub)
	workout_editor_page = preload("res://workout_editor.gd").new()
	workout_editor_page.library = workout_library
	layout.add_child(workout_editor_page)
	workout_editor_page.workout_saved.connect(func(_id): refresh_workout_tiles())
	workout_editor_page.workout_deleted.connect(func(_id): refresh_workout_tiles())
	workout_editor_page.back_requested.connect(show_training)
	ftp_page = preload("res://ftp_training.gd").new()
	layout.add_child(ftp_page)
	ftp_page.back_requested.connect(show_training)
	ftp_page.environment_requested.connect(_training_environment)
	workout_play_page = preload("res://workout_training.gd").new()
	workout_play_page.menu = self
	layout.add_child(workout_play_page)
	workout_play_page.back_requested.connect(show_training)
	workout_play_page.edit_requested.connect(edit_workout)
	workout_play_page.environment_requested.connect(_workout_environment)
	refresh_workout_tiles()
	session_panel = PanelContainer.new()
	session_panel.position = Vector2(30, 30)
	session_panel.custom_minimum_size = Vector2(600, 0)
	session_panel.size = Vector2(600, 0)
	session_panel.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.IVORY, MenuStyle.LINE, 24, 14))
	add_child(session_panel)
	session_panel.hide()

func _training_environment(active: bool) -> void:
	if active:
		if ftp_page.get_parent() != session_panel: ftp_page.reparent(session_panel)
		menu_margin.hide()
		menu_tint.hide()
		session_panel.show()
	else:
		if ftp_page.get_parent() != menu_layout: ftp_page.reparent(menu_layout)
		session_panel.hide()
		menu_margin.show()
		menu_tint.show()
	training_environment_requested.emit(active)

func _hide_hub_pages() -> void:
	if hub_page == null: return
	for node in [hub_page, training_page, piste_page, derny_page, exercise_page, training_history_page, tournament_page, ftp_page, workout_editor_page, workout_play_page]: node.hide()

func _show_section(index: int, caption: String, node: Control) -> void:
	if derny_page.scene != null and derny_page.scene.active: _piste_environment(false)
	if exercise_page.scene != null and exercise_page.scene.active: _exercise_environment(false)
	if workout_play_page.test.running(): workout_play_page.finish("Training verlaten")
	if ftp_page.test.running(): ftp_page.finish("Test verlaten")
	_hide_hub_pages()
	for child in [choice_page, settings_page, records_page, pursuit_flow, startlist_page]: child.hide()
	page = index
	page_title.text = caption
	breadcrumb.text = "Velodrome v0.2"
	footer_label.show()
	node.show()
	var focus: Control = node.get_child(0)
	if node == hub_page: focus = hub_button
	if node == training_page: focus = ftp_tile
	if node == derny_page: focus = derny_page.start_button
	if node == exercise_page: focus = exercise_page.start_button
	if node == training_history_page: focus = training_history_page.get_child(1)
	if node == workout_editor_page: focus = workout_editor_page.name_edit
	if node == workout_play_page: focus = workout_play_page.start_button
	if node == ftp_page: focus = ftp_page.start_button if not ftp_page.start_button.disabled else ftp_page.back_button
	focus.grab_focus.call_deferred()

func show_hub() -> void:
	_show_section(0, "Welkom in Velodrome", hub_page)

func show_training() -> void:
	refresh_workout_tiles()
	_show_section(6, "ERG-training", training_page)

func show_piste_training() -> void:
	_show_section(11, "Pistetraining", piste_page)

func show_derny() -> void:
	_show_section(12, "Dernytraining", derny_page)

func show_piste_exercise(kind: String) -> void:
	_show_section(15,preload("res://piste_exercise_session.gd").title(kind),exercise_page)
	exercise_page.configure(kind)
func _exercise_environment(active: bool) -> void:
	exercise_environment_requested.emit(active)
	if active and not exercise_page.session.running(): return
	session_panel.hide()
	menu_margin.visible = not active
	menu_tint.visible = not active

func show_training_history() -> void:
	training_history_page.refresh()
	_show_section(13,"Opgeslagen trainingen",training_history_page)

func _piste_environment(active: bool) -> void:
	piste_environment_requested.emit(active)
	if active:
		if not derny_page.session.running(): return
		menu_margin.hide()
		menu_tint.hide()
		session_panel.hide()
	else:
		session_panel.hide()
		menu_margin.show()
		menu_tint.show()

func show_tournaments() -> void:
	_show_section(7, "Toernooien", tournament_page)
	tournament_page.get_child(1).grab_focus.call_deferred()

func _workout_tile(caption: String, description: String, action: Callable, workout_blocks: Array = []) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0,210)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,MenuStyle.panel(MenuStyle.PAPER if state == "normal" else MenuStyle.PALE,MenuStyle.LINE if state == "normal" else MenuStyle.BLUE,0,12))
	workout_grid.add_child(button)
	var content := VBoxContainer.new()
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18; content.offset_right = -18; content.offset_top = 14; content.offset_bottom = -14
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := preload("res://training_tile_art.gd").new()
	if not workout_blocks.is_empty(): art.set_workout(workout_blocks)
	art.custom_minimum_size.y = 64
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	var title := label(caption,26)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font",MenuStyle.heading())
	content.add_child(title)
	var detail := label(description,18,MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	button.pressed.connect(action)
	return button
func refresh_workout_tiles() -> void:
	for child in workout_grid.get_children(): workout_grid.remove_child(child); child.queue_free()
	ftp_tile = _workout_tile("FTP-ramp test","Bepaal je FTP en bewaar die in je profiel.",show_ftp,preload("res://ftp_ramp.gd").preview_blocks(preload("res://player_profile.gd").new().ftp()))
	editor_tile = _workout_tile("Workout-editor","Nieuwe workout maken of bestaande bewerken.",show_workout_editor)
	saved_workout_tiles.clear()
	for item in workout_library.all_workouts():
		var seconds: float = workout_library.total_seconds(item.blocks)
		saved_workout_tiles.append(_workout_tile(item.name,"%d blokken · %d minuten" % [item.blocks.size(),int(ceil(seconds/60))],show_workout.bind(str(item.id)),item.blocks))
func show_workout(id: String) -> void:
	var item: Dictionary = workout_library.get_workout(id)
	if item.is_empty(): return
	workout_play_page.load_workout(item)
	_show_section(14,str(item.name),workout_play_page)
func edit_workout(id: String) -> void:
	show_workout_editor()
	workout_editor_page.load_workout(id)
func _workout_environment(active: bool) -> void:
	if active:
		if workout_play_page.get_parent() != session_panel: workout_play_page.reparent(session_panel)
		menu_margin.hide(); menu_tint.hide(); session_panel.show()
	else:
		if workout_play_page.get_parent() != menu_layout: workout_play_page.reparent(menu_layout)
		session_panel.hide(); menu_margin.show(); menu_tint.show()
	workout_environment_requested.emit(active)

func show_workout_editor() -> void:
	workout_editor_page.refresh_workout_choices()
	_show_section(10, "Workout-editor", workout_editor_page)

func show_ftp() -> void:
	_show_section(8, "FTP Ramp Test", ftp_page)

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
	keirin_derny = _number(race_settings, "Dernytempo · 70% = 45 km/u, 100% = 50 km/u", 70, 100, 100)
	keirin_derny.step = 10
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
		if not start_button.disabled and (selected in [0, 3, 5, 6, 7] or (selected in [1, 2] and (pursuit_options if selected == 1 else team_options).can_start())):
			if selected in [0, 3, 5, 6]: show_startlist()
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
	_hide_hub_pages()
	footer_label.show()
	page_title.add_theme_font_size_override("font_size",44)
	if startlist_page != null: startlist_page.hide()
	if pursuit_flow != null: pursuit_flow.hide()
	if page == 2 and selected in [0, 3, 5, 6]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	page = 1
	page_title.text = "Kies jouw wedstrijd"
	choice_page.show()
	settings_page.hide()
	records_page.hide()
	breadcrumb.text = "01  Spelvorm     /     02  Instellingen"
	if not cards.is_empty():
		cards[selected].grab_focus.call_deferred()

func select_mode(index: int) -> void:
	_hide_hub_pages()
	if page == 2 and selected in [0, 3, 5, 6]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
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
	race_settings.visible = selected in [0, 3, 5, 6]
	time_trial_settings.visible = selected == 7
	count_input.visible = selected not in [5,6]
	count_input.get_meta("caption").visible = selected not in [5,6]
	elimination_count_picker.visible = selected == 5
	laps_input.visible = selected not in [5,6]
	laps_input.get_meta("caption").visible = selected not in [5,6]
	keirin_derny.visible = selected == 6
	keirin_derny.get_meta("caption").visible = selected == 6
	if selected == 6:
		count_input.value = 6
		laps_input.min_value = 1
		laps_input.step = 1
		laps_input.value = 6
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
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 6, 7] and not bridge_seen and not bridge_unavailable
	status_label.text = "Klaar voor de start. Stel je wedstrijd in." if selected in [0, 1, 2, 3, 5, 6, 7] else "Binnenkort speelbaar. Deze spelvorm is nog in ontwikkeling."
	start_button.disabled = selected not in [0, 1, 2, 3, 5, 6, 7]
	start_button.text = "Startlijst →" if selected in [0, 3, 5, 6] else "Start wedstrijd →" if selected in [1, 2, 7] else "Binnenkort"
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
	bridge_status_text = "●  Trainer verbonden" if live else ("Trainer gevonden · wacht op gegevens" if seen else "Demo beschikbaar · geen trainer")
	if unavailable:
		bridge_status_text = "Verbinding bezet · sluit de andere spelinstantie"
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 6, 7] and not seen and not unavailable
	start_button.disabled = unavailable or selected not in [0, 1, 2, 3, 5, 6, 7]
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
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE and page in [0, 1, 6, 7, 8, 10, 11, 12, 13, 14]:
		bridge_action("B")
		get_viewport().set_input_as_handled()
		return
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
		elif page in [1, 6, 7, 11]: show_hub()
		elif page == 8: ftp_page.leave()
		elif page == 10: show_training()
		elif page == 12: derny_page.leave()
		elif page == 13: show_piste_training()
		elif page == 14: workout_play_page.leave()
		elif page == 15: exercise_page.leave()
		return
	var actions := {"LEFT": "ui_left", "RIGHT": "ui_right", "UP": "ui_up", "DOWN": "ui_down", "A": "ui_accept"}
	if not actions.has(button): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		if page == 1: cards[selected].grab_focus()
		elif page == 0: hub_button.grab_focus()
		elif page == 11: piste_page.get_child(0).grab_focus()
		elif page == 12: derny_page.stop_button.grab_focus() if derny_page.session.running() else derny_page.start_button.grab_focus()
		elif page == 6: ftp_tile.grab_focus()
		elif page == 14: workout_play_page.start_button.grab_focus()
		elif page == 15: exercise_page.start_button.grab_focus()
		elif page == 7: tournament_page.get_child(1).grab_focus()
		elif page == 8:
			if ftp_page.test.running(): ftp_page.stop_button.grab_focus()
			else: ftp_page.back_button.grab_focus()
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
	if selected not in [0, 3, 5, 6] or bridge_unavailable: return
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
