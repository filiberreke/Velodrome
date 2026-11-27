extends Control
signal start_requested
signal difficulty_changed(value: float)
signal training_environment_requested(active: bool)
signal workout_environment_requested(active: bool)
signal piste_environment_requested(active: bool)
signal exercise_environment_requested(active: bool)
signal madison_environment_requested(active: bool)
signal training_upload_requested(activity: Dictionary)
const LocalizedText := preload("res://localized_text.gd")
const MenuStyle := preload("res://menu_theme.gd")
const Preview := preload("res://mode_preview.gd")
const Records := preload("res://pursuit_records.gd")
var keyboard_mapping: RefCounted = preload("res://keyboard_mapping.gd").new()
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
var bridge_status_text := "MENU_DEMO_AVAILABLE"
var bridge_seen := false
var bridge_live := false
var bridge_unavailable := false
const MODES := [
	{"key": "scratch", "title": "RACE_MENU_SCRATCH_RACE", "hint": "RACE_MENU_ONE_PELOTON_ONE_FINISH", "detail": "RACE_MENU_START_WITH_ONE_NEUTRALISED_LAP_STAY_SHELTERED_CHOOSE_YOUR_MOMENT_", "race_id": 0},
	{"key": "pursuit", "title": "RACE_MENU_INDIVIDUAL_PURSUIT", "hint": "RACE_MENU_YOU_YOUR_OPPONENT_AND_THE_CLOCK", "detail": "RACE_MENU_TWO_RIDERS_START_OPPOSITE_EACH_OTHER_CHASE_THE_FASTEST_TIME_OR_CA", "race_id": 4},
	{"key": "team_pursuit", "title": "RACE_MENU_TEAM_PURSUIT", "hint": "RACE_MENU_CHASE_THE_FASTEST_TIME_TOGETHER", "detail": "RACE_MENU_SET_THE_PACE_STEER_RIGHT_WHILE_LEADING_FOR_AN_AUTOMATIC_CHANGEOVE", "race_id": 5},
	{"key": "points", "title": "RACE_MENU_POINTS_RACE", "hint": "RACE_MENU_EVERY_SPRINT_IS_ANOTHER_CHANCE", "detail": "RACE_MENU_START_WITH_ONE_NEUTRALISED_LAP_EVERY_10_LAPS_5_3_2_1_POINTS_DOUBL", "race_id": 1},
	{"key": "madison", "title": "RACE_MENU_MADISON", "hint": "RACE_MENU_TAKE_TURNS_STAY_IN_THE_RACE", "detail": "RACE_MENU_RIDE_AS_A_PAIR_EXCHANGE_TURNS_AND_COMPETE_FOR_POINTS_AND_LAPS_TOG", "race_id": 6},
	{"key": "elimination", "title": "RACE_MENU_ELIMINATION_RACE", "hint": "RACE_MENU_THE_LAST_RIDER_IS_ELIMINATED_EVERY_TWO_LAPS", "detail": "RACE_MENU_START_WITH_ONE_NEUTRALISED_LAP_EVERY_TWO_LAPS_THE_LAST_RIDER_ACRO", "race_id": 2},
	{"key": "keirin", "title": "MENU_KEIRIN", "hint": "RACE_MENU_FOLLOW_THE_PACE_UNLEASH_YOUR_SPRINT", "detail": "RACE_MENU_SIX_RIDERS_RANDOMLY_DRAWN_STARTING_POSITIONS_THREE_LAPS_BEHIND_TH", "race_id": 3},
	{"key": "time_trial", "title": "RACE_MENU_TIME_TRIAL", "hint": "RACE_MENU_YOU_AGAINST_THE_CLOCK", "detail": "RACE_MENU_500_M_OR_1_KM_WITH_A_STANDING_OR_FLYING_START_AND_COMPARISONS_EVE", "race_id": 7},
	{"key": "tempo", "title": "RACE_MENU_TEMPO_RACE", "hint": "RACE_MENU_KEEP_THE_PACE_HIGH", "detail": "RACE_MENU_40_LAPS_FROM_LAP_5_THE_FIRST_RIDER_ACROSS_THE_LINE_EARNS_ONE_POIN", "race_id": 8},
	{"key": "records", "title": "MENU_RECORDS", "hint": "MENU_YOUR_FASTEST_TIMES_EVER", "detail": "MENU_TOP_10_INDIVIDUAL_AND_TEAM_PURSUIT", "race_id": -1}
]
const INK := MenuStyle.INK
const MUTED := MenuStyle.MUTED
const ACCENT := MenuStyle.BLUE
const RECORDS_INDEX := 9
const PLAYABLE := [0, 1, 2, 3, 5, 6, 7, 8]
const DISPLAY_ORDER := [0, 1, 2, 3, 5, 4, 6, 7, 8, 9]
var gallery_grid: GridContainer
var page := 1
var venue_id := "velodrome"
var venue_picker: VBoxContainer
var selected := 0
var field_settings := {0: [8, 10], 3: [16, 40], 5: [12, 22], 6: [6, 6], 8: [16, 40]}
var cards: Array[Button] = []
var previews: Array[SubViewport] = []
var choice_page: VBoxContainer
var settings_page: ScrollContainer
var breadcrumb: Label
var page_title: Label
var page_header: HBoxContainer
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
var difficulty_preferences := ConfigFile.new()
var difficulty_preferences_path := "user://config/race_difficulty.cfg"

var race_settings: VBoxContainer
var hub_page: VBoxContainer
var training_page: VBoxContainer
var piste_page: VBoxContainer
var piste_tiles := {}
var derny_page: VBoxContainer
var exercise_page: VBoxContainer
var madison_page: VBoxContainer
var training_history_page: VBoxContainer
var erg_history_page: VBoxContainer
var training_store = preload("res://training_store.gd").new()
var tournament_page: VBoxContainer
var tournament_back: Button
var ftp_page
var workout_editor_page: VBoxContainer
var workout_play_page: VBoxContainer
var workout_library = preload("res://workout_library.gd").new()
var workout_grid: GridContainer
var fixed_workout_grid: GridContainer
var custom_workout_empty: Label
var custom_duration_filter: OptionButton
var custom_intensity_filter: OptionButton
var ftp_tile: Button
var editor_tile: Button
var saved_workout_tiles: Array[Button] = []
var hub_button: Button
var races_back: Button
var menu_margin: MarginContainer
var menu_layout: VBoxContainer
var menu_tint: ColorRect
var session_panel: PanelContainer
var ftp_ramp_hud: Control

static func panel_style(colour: Color, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	return style

func place_back(button: Button, screen: Control) -> void:
	button.reparent(page_header)
	page_header.move_child(button, 0)
	button.custom_minimum_size = Vector2(210, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.primary(button)
	screen.visibility_changed.connect(func(): button.visible = screen.visible)
	button.visible = screen.visible

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
	page_header = title_row
	title_row.add_theme_constant_override("separation", 20)
	layout.add_child(title_row)
	page_title = label("RACE_MENU_CHOOSE_YOUR_RACE", 44)
	page_title.add_theme_font_override("font", MenuStyle.heading())
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(page_title)
	breadcrumb = label("MENU_01_RACE_MODE_02_SETTINGS", 18, MUTED)
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
		var mode_title := label("RACE_TEAM_PURSUIT_TILE" if i == 2 else MODES[i]["title"], 26)
		mode_title.add_theme_font_override("font", MenuStyle.heading())
		mode_title.custom_minimum_size.y = 62
		mode_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mode_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(mode_title)
		var status := label("TOP 10" if i == RECORDS_INDEX else (String(TranslationServer.translate("MENU_PLAY")) if i in PLAYABLE else String(TranslationServer.translate("MENU_COMING_SOON"))), 13, MUTED)
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
	place_back(records_page.back_button, records_page)
	records_page.back_requested.connect(show_choices)
	footer_label = label("MENU_ARROW_KEYS_SELECT_A_CONFIRM_B_BACK_Z_F10_SETTINGS", 17, MUTED)
	layout.add_child(footer_label)
	_build_hub(layout)
	show_hub()

func _hub_button(parent: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 90
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _hub_tile(parent: Container, caption: String, description: String, preview_indices: Array[int], action: Callable, custom_preview: Texture2D = null) -> Button:
	var button := Button.new()
	button.name = caption
	button.custom_minimum_size.y = 200
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	LocalizedText.bind(button, &"tooltip_text", func(): return "%s · %s" % [tr(caption), tr(description)])
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
	var title := label(caption, 34)
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
	if preview_indices.is_empty() and custom_preview == null:
		var chart := preload("res://training_tile_art.gd").new()
		chart.custom_minimum_size.x = 280
		chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		images.add_child(chart)
	var textures: Array[Texture2D] = []
	if custom_preview != null: textures.append(custom_preview)
	for index in preview_indices: textures.append(previews[index].get_texture())
	for texture in textures:
		var image := TextureRect.new(); image.texture = texture
		image.custom_minimum_size.x = 260
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		images.add_child(image)
	button.pressed.connect(action)
	return button

func _personal_hub_tile(parent: Container, caption: String, description: String, art_kind: String, available: bool) -> void:
	var tile := _hub_tile(parent, caption, description, [], show_training_history if available else _personal_coming_soon.bind(caption))
	var images: HBoxContainer = tile.get_child(0).get_child(1)
	for child in images.get_children():
		images.remove_child(child)
		child.queue_free()
	var art := preload("res://personal_tile_art.gd").new()
	art.kind = art_kind
	art.custom_minimum_size = Vector2(180, 130)
	images.add_child(art)
	if not available:
		LocalizedText.bind(tile, &"tooltip_text", func(): return String(tr(caption)) + tr("MENU_COMING_SOON_2"))

func _personal_coming_soon(_caption: String) -> void:
	pass

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
	hub_button = _hub_tile(first_row, "MENU_RACES", "MENU_CHOOSE_YOUR_DISCIPLINE_AND_RACE_TO_WIN", [0], show_choices)
	_hub_tile(first_row, "MENU_TOURNAMENTS", "MENU_MULTIPLE_RACES_ONE_SET_OF_STANDINGS", [0], show_tournaments)
	var second_row := HBoxContainer.new()
	second_row.name = "ErgEnPistetraining"
	second_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	second_row.add_theme_constant_override("separation", 16)
	hub_page.add_child(second_row)
	_hub_tile(second_row, "MENU_ERG_TRAINING", "MENU_POWER_BASED_WORKOUTS_AND_FTP_TESTS", [], show_training)
	_hub_tile(second_row, "MENU_TRACK_TRAINING", "MENU_FREE_RIDING_DERNY_AND_SPECIFIC_TRACK_SESSIONS", [7], show_piste_training)
	var personal_row := HBoxContainer.new()
	personal_row.name = "Persoonlijk"
	personal_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	personal_row.add_theme_constant_override("separation", 16)
	hub_page.add_child(personal_row)
	_personal_hub_tile(personal_row, "MENU_MY_RIDER", "MENU_CUSTOMISE_YOUR_RIDER_COMING_SOON", "rider", false)
	_personal_hub_tile(personal_row, "MENU_PALMARE_S", "MENU_RECORDS_AND_ACHIEVEMENTS_COMING_SOON", "palmares", false)
	_personal_hub_tile(personal_row, "MENU_MY_RIDES", "MENU_ALL_SAVED_ACTIVITIES", "rides", true)
	for tile_row in [first_row, second_row, personal_row]:
		for tile in tile_row.get_children():
			var artwork: Control = tile.get_child(0).get_child(1)
			artwork.custom_minimum_size = Vector2(280, 200)
			artwork.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for preview in artwork.get_children():
				preview.custom_minimum_size = Vector2(280, 200)
	var gent_design := Button.new()
	gent_design.name = "GentVenuePreview"
	gent_design.text = "GENT_OPEN_PREVIEW"
	gent_design.custom_minimum_size.y = 40
	gent_design.pressed.connect(func(): get_tree().change_scene_to_file("res://venues/gent/gent_preview.tscn"))
	hub_page.add_child(gent_design)
	races_back = _hub_button(choice_page, "RACE_MENU_MAIN_MENU", show_hub)
	races_back.reparent(page_header)
	page_header.move_child(races_back, 0)
	races_back.custom_minimum_size = Vector2(190, 48)
	races_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.primary(races_back)
	choice_page.visibility_changed.connect(func(): races_back.visible = choice_page.visible)
	races_back.visible = choice_page.visible
	training_page = VBoxContainer.new()
	training_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(training_page)
	var workout_scroll := ScrollContainer.new()
	workout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	training_page.add_child(workout_scroll)
	var workout_margin := MarginContainer.new()
	workout_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: workout_margin.add_theme_constant_override("margin_" + side, 8)
	workout_scroll.add_child(workout_margin)
	var workout_sections := VBoxContainer.new()
	workout_sections.add_theme_constant_override("separation", 20)
	workout_margin.add_child(workout_sections)
	fixed_workout_grid = GridContainer.new()
	fixed_workout_grid.name = "VasteTestsEnEditor"
	fixed_workout_grid.columns = 4
	fixed_workout_grid.add_theme_constant_override("h_separation", 16)
	workout_sections.add_child(fixed_workout_grid)
	var custom_header := HBoxContainer.new()
	custom_header.add_theme_constant_override("separation", 18)
	workout_sections.add_child(custom_header)
	var custom_title := label("MENU_CUSTOM_WORKOUTS", 27)
	custom_title.add_theme_font_override("font", MenuStyle.heading())
	custom_header.add_child(custom_title)
	var divider := HSeparator.new()
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_header.add_child(divider)
	var import_button := Button.new()
	import_button.text = "MENU_IMPORT_ZWO"
	import_button.custom_minimum_size = Vector2(190, 48)
	import_button.pressed.connect(func(): show_workout_editor(); workout_editor_page._open())
	custom_header.add_child(import_button)
	var custom_filters := HBoxContainer.new()
	custom_filters.add_theme_constant_override("separation", 16)
	workout_sections.add_child(custom_filters)
	custom_filters.add_child(label("MENU_DURATION", 19, MUTED))
	custom_duration_filter = OptionButton.new()
	for caption in [String(TranslationServer.translate("MENU_ALL_DURATIONS")), String(TranslationServer.translate("MENU_UNDER_30_MIN")), String(TranslationServer.translate("MENU_30_60_MIN")), String(TranslationServer.translate("MENU_OVER_60_MIN"))]: custom_duration_filter.add_item(caption)
	custom_filters.add_child(custom_duration_filter)
	custom_filters.add_child(label("MENU_INTENSITY", 19, MUTED))
	custom_intensity_filter = OptionButton.new()
	custom_intensity_filter.add_item("MENU_ALL_INTENSITIES")
	var intensity_art := preload("res://workout_intensity.gd")
	for level in range(1, 6):
		custom_intensity_filter.add_icon_item(intensity_art.filter_icon(level), intensity_art.LABELS[level])
	custom_intensity_filter.add_item("MENU_FREE_RIDING_ONLY")
	custom_intensity_filter.tooltip_text = "MENU_AVERAGE_PLANNED_TARGET_POWER_AS_A_PERCENTAGE_OF_FTP_WEIGHTED_BY_DURATI"
	custom_filters.add_child(custom_intensity_filter)
	for filter in [custom_duration_filter, custom_intensity_filter]: filter.item_selected.connect(func(_index): apply_workout_filters())
	custom_workout_empty = label("MENU_NO_CUSTOM_WORKOUTS_YET_CREATE_A_WORKOUT_IN_THE_EDITOR_OR_IMPORT_A_ZWO_", 20, MUTED)
	custom_workout_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workout_sections.add_child(custom_workout_empty)
	workout_grid = GridContainer.new()
	workout_grid.columns = 3
	workout_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workout_grid.add_theme_constant_override("h_separation",16)
	workout_grid.add_theme_constant_override("v_separation",16)
	workout_sections.add_child(workout_grid)
	var training_back := _hub_button(training_page,"RACE_MENU_MAIN_MENU",show_hub)
	place_back(training_back, training_page)
	piste_page = VBoxContainer.new()
	piste_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(piste_page)
	var piste_grid := GridContainer.new()
	piste_grid.columns = 3
	piste_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	piste_grid.add_theme_constant_override("h_separation", 16)
	piste_grid.add_theme_constant_override("v_separation", 16)
	piste_page.add_child(piste_grid)
	piste_tiles["free_ride"] = _hub_tile(piste_grid,"RACE_MENU_FREE_TRAINING","MENU_FREE_RIDING_LAP_TIMES_AND_FOUR_COLOURED_PACERS",[],show_piste_exercise.bind("free_ride"),Preview.make(self,"free_training").get_texture())
	piste_tiles["derny"] = _hub_tile(piste_grid,"TRAINING_HISTORY_DERNY_TRAINING","MENU_FOLLOW_THE_PACER_AND_INCREASE_THE_PACE_TOGETHER",[],show_derny,Preview.make(self,"derny_training").get_texture())
	piste_tiles["flying_start"] = _hub_tile(piste_grid,"RACE_MENU_FLYING_START","MENU_USE_THE_BANKING_AND_IMPROVE_YOUR_SPEED_AT_THE_LINE",[],show_piste_exercise.bind("flying_start"),Preview.make(self,"flying_training").get_texture())
	piste_tiles["take_lap"] = _hub_tile(piste_grid,"RACE_MENU_GAIN_A_LAP","MENU_GAIN_A_LAP_ON_A_PELOTON_RIDING_AT_A_CONSTANT_PACE",[0],show_piste_exercise.bind("take_lap"))
	piste_tiles["madison"] = _hub_tile(piste_grid,"MENU_MADISON_EXCHANGE_TRAINING","MENU_PRACTISE_10_OR_20_HAND_SLING_EXCHANGES_WITH_YOUR_TEAMMATE",[4],show_madison_training)
	var history_tile := _hub_tile(piste_grid,"RACE_MENU_SAVED_TRAINING_SESSIONS","MENU_VIEW_YOUR_PREVIOUS_TRAINING_SESSIONS_AND_PERFORMANCES",[],show_training_history)
	var history_images: HBoxContainer = history_tile.get_child(0).get_child(1)
	var old_history_art := history_images.get_child(0)
	history_images.remove_child(old_history_art)
	old_history_art.queue_free()
	history_images.add_child(preload("res://training_history_art.gd").new())
	for tile in piste_grid.get_children():
		var old_content: HBoxContainer = tile.get_child(0)
		var copy: VBoxContainer = old_content.get_child(0)
		var images: HBoxContainer = old_content.get_child(1)
		var gallery := VBoxContainer.new()
		gallery.name = "PisteTileContent"
		gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gallery.offset_left = 12; gallery.offset_right = -12
		gallery.offset_top = 12; gallery.offset_bottom = -12
		gallery.add_theme_constant_override("separation", 10)
		gallery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(gallery)
		images.reparent(gallery)
		images.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		images.size_flags_vertical = Control.SIZE_EXPAND_FILL
		copy.reparent(gallery)
		copy.size_flags_vertical = Control.SIZE_SHRINK_END
		var title: Label = copy.get_child(0)
		title.text = tile.name
		title.add_theme_font_size_override("font_size", 26)
		title.custom_minimum_size.y = 62
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.get_child(1).hide()
		for artwork in images.get_children():
			if artwork is TextureRect:
				tile.set_meta("preview_texture", artwork.texture)
				artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			artwork.custom_minimum_size = Vector2(0, 180)
			artwork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
		old_content.free()
	var piste_back := _hub_button(piste_page,"RACE_MENU_MAIN_MENU",show_hub)
	place_back(piste_back, piste_page)
	derny_page = preload("res://derny_training.gd").new()
	layout.add_child(derny_page)
	var derny_card := preload("res://training_menu_card.gd").new()
	derny_card.configure(self, derny_page, [derny_page.motor_picker, derny_page.start_speed_row], derny_card.picture(piste_tiles["derny"].get_meta("preview_texture")))
	derny_page.back_requested.connect(_piste_back_requested.bind(derny_page))
	derny_page.environment_requested.connect(_piste_environment)
	derny_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	exercise_page = preload("res://piste_exercise_page.gd").new()
	exercise_page.records_store = training_store
	layout.add_child(exercise_page)
	var exercise_card := preload("res://training_menu_card.gd").new()
	var exercise_art: Texture2D = piste_tiles["flying_start"].get_meta("preview_texture")
	exercise_card.configure(self, exercise_page, [exercise_page.tempo_row, exercise_page.limit_row], exercise_card.picture(exercise_art))
	for kind in ["free_ride", "flying_start", "take_lap"]:
		exercise_card.exercise_previews[kind] = piste_tiles[kind].get_meta("preview_texture")
	exercise_page.back_requested.connect(_piste_back_requested.bind(exercise_page))
	exercise_page.environment_requested.connect(_exercise_environment)
	exercise_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	madison_page = preload("res://madison_training.gd").new()
	layout.add_child(madison_page)
	var madison_card := preload("res://training_menu_card.gd").new()
	madison_card.configure(self, madison_page, [madison_page.difficulty, madison_page.count, madison_page.unlock_label], madison_card.picture(piste_tiles["madison"].get_meta("preview_texture")))
	madison_page.back_requested.connect(_piste_back_requested.bind(madison_page))
	madison_page.environment_requested.connect(_madison_environment)
	madison_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	erg_history_page = preload("res://erg_history.gd").new()
	erg_history_page.menu = self
	layout.add_child(erg_history_page)
	place_back(erg_history_page.back_button, erg_history_page)
	training_history_page = preload("res://training_history.gd").new()
	training_history_page.menu = self
	layout.add_child(training_history_page)
	place_back(training_history_page.back_button, training_history_page)
	tournament_page = preload("res://omnium/omnium_page.gd").new()
	tournament_page.menu = self
	layout.add_child(tournament_page)
	tournament_back = tournament_page.back_button
	place_back(tournament_back, tournament_page)
	workout_editor_page = preload("res://workout_editor.gd").new()
	workout_editor_page.library = workout_library
	layout.add_child(workout_editor_page)
	place_back(workout_editor_page.back_button, workout_editor_page)
	workout_editor_page.workout_saved.connect(func(_id): refresh_workout_tiles())
	workout_editor_page.workout_deleted.connect(func(_id): refresh_workout_tiles())
	workout_editor_page.back_requested.connect(show_training)
	ftp_page = preload("res://ftp_training.gd").new()
	layout.add_child(ftp_page)
	var ftp_card := preload("res://training_menu_card.gd").new()
	ftp_page.set_meta("preparation_card", ftp_card)
	ftp_card.configure(self, ftp_page, [ftp_page.warmup_hint], ftp_card.chart(preload("res://ftp_ramp.gd").preview_blocks(ftp_page.player_profile.ftp())))
	ftp_page.back_requested.connect(show_training)
	ftp_page.upload_requested.connect(func(activity): training_upload_requested.emit(activity))
	ftp_page.environment_requested.connect(_training_environment)
	workout_play_page = preload("res://workout_training.gd").new()
	workout_play_page.menu = self
	layout.add_child(workout_play_page)
	var workout_card := preload("res://training_menu_card.gd").new()
	workout_card.configure(self, workout_play_page, [workout_play_page.ftp_caption, workout_play_page.ftp_input], workout_card.chart())
	workout_play_page.set_meta("preparation_card", workout_card)
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
	ftp_ramp_hud = preload("res://ftp_ramp_hud.gd").new()
	add_child(ftp_ramp_hud)
	ftp_ramp_hud.hide()

func _process(_delta: float) -> void:
	if ftp_ramp_hud != null and ftp_ramp_hud.visible and ftp_page != null:
		if workout_play_page.active_environment: ftp_ramp_hud.update_workout(workout_play_page)
		else: ftp_ramp_hud.update_ftp(ftp_page)

func _training_environment(active: bool) -> void:
	if active:
		ftp_ramp_hud.reset_for_session()
		if ftp_page.get_parent() != session_panel: ftp_page.reparent(session_panel)
		menu_margin.hide()
		menu_tint.hide()
		# Keep the session controller processing offscreen, never draw its menu layout
		# over the velodrome. The race-style HUD owns all visible training widgets.
		session_panel.position = Vector2(-3000, -3000)
		session_panel.show()
		ftp_ramp_hud.show()
	else:
		ftp_ramp_hud.hide()
		if ftp_page.get_parent() != menu_layout: ftp_page.reparent(menu_layout)
		session_panel.hide()
		session_panel.position = Vector2(30, 30)
		menu_margin.show()
		menu_tint.show()
	training_environment_requested.emit(active)

func _hide_hub_pages() -> void:
	if hub_page == null: return
	# A finished FTP session must never leave its floating session panel over races or menus.
	if ftp_ramp_hud != null: ftp_ramp_hud.hide()
	if session_panel != null:
		session_panel.hide()
		if ftp_page != null and ftp_page.get_parent() == session_panel:
			ftp_page.reparent(menu_layout)
		if workout_play_page != null and workout_play_page.get_parent() == session_panel:
			workout_play_page.reparent(menu_layout)
	menu_margin.show()
	menu_tint.show()
	for node in [hub_page, training_page, piste_page, derny_page, exercise_page, madison_page, training_history_page, erg_history_page, tournament_page, ftp_page, workout_editor_page, workout_play_page]: node.hide()

func _show_section(index: int, caption: String, node: Control) -> void:
	if madison_page.scene != null and madison_page.scene.active: _madison_environment(false)
	if derny_page.scene != null and derny_page.scene.active: _piste_environment(false)
	if exercise_page.scene != null and exercise_page.scene.active: _exercise_environment(false)
	if workout_play_page.test.running(): workout_play_page.finish(String(TranslationServer.translate("MAIN_LEAVE_TRAINING")))
	if ftp_page.test.running() or ftp_page.twenty_warmup: ftp_page.finish(String(TranslationServer.translate("MENU_EXIT_TEST")))
	_hide_hub_pages()
	for child in [choice_page, settings_page, records_page, pursuit_flow, startlist_page]: child.hide()
	page = index
	page_title.add_theme_font_size_override("font_size", 44)
	page_title.text = caption
	breadcrumb.text = "Velodrome v0.2"
	footer_label.show()
	node.show()
	var candidates: Array[Control] = preload("res://ride_navigation.gd").controls(node)
	if candidates.is_empty(): candidates = preload("res://ride_navigation.gd").controls(page_header)
	var focus: Control = candidates[0] if not candidates.is_empty() else null
	if node == hub_page: focus = hub_button
	if node == training_page: focus = ftp_tile
	if node == piste_page: focus = piste_tiles["free_ride"]
	if node == derny_page: focus = derny_page.derny_motor_button if derny_page.selected_activity.is_empty() else derny_page.start_button
	if node == exercise_page: focus = exercise_page.tempo_input.get_line_edit() if exercise_page.kind == "take_lap" else exercise_page.start_button
	if node == madison_page: focus = madison_page.difficulty if madison_page.selected_activity.is_empty() else madison_page.start_button
	if node == training_history_page: focus = training_history_page.back_button
	if node == erg_history_page: focus = erg_history_page.back_button
	if node == workout_editor_page: focus = workout_editor_page.name_edit
	if node == workout_play_page: focus = workout_play_page.start_button
	if node == ftp_page: focus = ftp_page.start_button if not ftp_page.start_button.disabled else ftp_page.back_button
	if focus != null: focus.grab_focus.call_deferred()

func show_hub() -> void:
	_show_section(0, "MENU_WELCOME_TO_VELODROME", hub_page)

func show_training() -> void:
	refresh_workout_tiles()
	_show_section(6, "MENU_ERG_TRAINING", training_page)

func _piste_back_requested(training) -> void:
	if training == exercise_page and not exercise_page.omnium_origin.is_empty():
		exercise_page.omnium_origin = ""
		tournament_page.opened = true
		tournament_page.editing = false
		tournament_page.refresh()
		_show_section(7, "MENU_OMNIUM", tournament_page)
		tournament_back.grab_focus.call_deferred()
		return
	if training.return_to_history: show_training_history()
	else: show_piste_training()

func show_piste_training() -> void:
	_show_section(11, "MENU_TRACK_TRAINING", piste_page)

func show_madison_training(new_training: bool = true) -> void:
	if new_training: madison_page.prepare_new_training()
	_show_section(16,"MENU_MADISON_EXCHANGE_TRAINING",madison_page)

func _madison_environment(active: bool) -> void:
	madison_environment_requested.emit(active)
	if active and not madison_page.session.running(): return
	session_panel.hide()
	menu_margin.visible = not active
	menu_tint.visible = not active

func show_derny(new_training: bool = true) -> void:
	if new_training: derny_page.prepare_new_training()
	_show_section(12, "TRAINING_HISTORY_DERNY_TRAINING", derny_page)

func show_piste_exercise(kind: String, new_training: bool = true) -> void:
	# Opening the result of the same ride must preserve its return destination.
	if new_training: exercise_page.omnium_origin = ""
	if new_training: exercise_page.prepare_new_training()
	exercise_page.configure(kind)
	_show_section(15,preload("res://piste_exercise_session.gd").title(kind),exercise_page)
func _exercise_environment(active: bool) -> void:
	exercise_environment_requested.emit(active)
	if active and not exercise_page.session.running(): return
	session_panel.hide()
	menu_margin.visible = not active
	menu_tint.visible = not active

func show_erg_history() -> void:
	erg_history_page.refresh()
	_show_section(17,"MENU_HISTORY_ERG_TRAINING",erg_history_page)

func show_training_history() -> void:
	training_history_page.refresh()
	_show_section(13,"RACE_MENU_SAVED_TRAINING_SESSIONS",training_history_page)

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
	tournament_page.result_index = -1
	tournament_page.archived_tournament = {}; tournament_page.archive_list = false
	tournament_page.opened = false
	tournament_page.editing = false
	tournament_page.choosing_startlist = false
	tournament_page.refresh()
	_show_section(7, "MENU_TOURNAMENTS", tournament_page)
	tournament_back.grab_focus.call_deferred()

func _workout_tile(caption: String, description: String, action: Callable, workout_blocks: Array = [], destination: GridContainer = null, badge_text: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0,210)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,MenuStyle.panel(MenuStyle.PAPER if state == "normal" else MenuStyle.PALE,MenuStyle.LINE if state == "normal" else MenuStyle.BLUE,0,12))
	(workout_grid if destination == null else destination).add_child(button)
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
	if not badge_text.is_empty():
		var badge := label(badge_text, 13, MenuStyle.BLUE)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.add_theme_stylebox_override("normal", MenuStyle.panel(MenuStyle.PALE, Color.TRANSPARENT, 6, 6))
		content.add_child(badge)
	var detail := label(description,18,MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	button.pressed.connect(action)
	return button
func refresh_workout_tiles() -> void:
	for child in workout_grid.get_children(): workout_grid.remove_child(child); child.queue_free()
	for child in fixed_workout_grid.get_children(): fixed_workout_grid.remove_child(child); child.queue_free()
	ftp_tile = _workout_tile("MENU_FTP_RAMP_TEST","MENU_DETERMINE_YOUR_FTP_AND_SAVE_IT_IN_YOUR_PROFILE",show_ftp,preload("res://ftp_ramp.gd").preview_blocks(preload("res://player_profile.gd").new().ftp()),fixed_workout_grid,"MENU_STANDARD_VELODROME_TEST")
	_workout_tile("MENU_20_MINUTE_FTP_TEST","MENU_5_MINUTES_OF_WARM_UP_20_MINUTES_OF_SELF_PACED_POWER_FTP_95_OF_AVERAGE_",show_ftp_twenty,_twenty_ftp_preview(),fixed_workout_grid,"MENU_STANDARD_TEST")
	editor_tile = _workout_tile("MENU_WORKOUT_EDITOR","MENU_CREATE_A_CUSTOM_WORKOUT_OR_EDIT_AN_EXISTING_ONE",show_workout_editor,[],fixed_workout_grid,"MENU_EDITOR")
	_workout_tile("MENU_HISTORY","MENU_ALL_COMPLETED_ERG_SESSIONS_AND_FTP_TESTS",show_erg_history,[],fixed_workout_grid,"MENU_RESULTS")
	saved_workout_tiles.clear()
	for item in workout_library.all_workouts():
		var seconds: float = workout_library.total_seconds(item.blocks)
		var intensity: float = workout_library.average_target(item.blocks)
		var intensity_text := String(TranslationServer.translate("MENU_FREE_RIDING")) if intensity < 0 else String(TranslationServer.translate("MENU_AVG_D_FTP")) % roundi(intensity * 100)
		var tile := _workout_tile(item.name,String(TranslationServer.translate("MENU_D_S_D_MINUTES_S")) % [item.blocks.size(),"blok" if item.blocks.size() == 1 else "blokken",int(ceil(seconds/60)),intensity_text],show_workout.bind(str(item.id)),item.blocks)
		var intensity_badge := preload("res://workout_intensity.gd").new()
		intensity_badge.configure(intensity)
		tile.get_child(0).add_child(intensity_badge)
		tile.tooltip_text += "\n" + intensity_badge.tooltip_text
		tile.set_meta("duration_s", seconds)
		tile.set_meta("intensity", intensity)
		saved_workout_tiles.append(tile)
	apply_workout_filters()

func apply_workout_filters() -> void:
	var visible_count := 0
	for tile in saved_workout_tiles:
		var seconds: float = tile.get_meta("duration_s")
		var intensity: float = tile.get_meta("intensity")
		var duration_matches: bool = [true, seconds < 1800, seconds >= 1800 and seconds <= 3600, seconds > 3600][custom_duration_filter.selected]
		var level: int = workout_library.intensity_level(intensity)
		var selected_level := custom_intensity_filter.selected
		var intensity_matches: bool = selected_level == 0 or (level == selected_level if selected_level < 6 else level == 0)
		tile.visible = duration_matches and intensity_matches
		if tile.visible: visible_count += 1
	custom_workout_empty.visible = visible_count == 0
	custom_workout_empty.text = "MENU_NO_CUSTOM_WORKOUTS_YET_CREATE_A_WORKOUT_IN_THE_EDITOR_OR_IMPORT_A_ZWO_" if saved_workout_tiles.is_empty() else "MENU_NO_CUSTOM_WORKOUTS_MATCH_THESE_FILTERS_CHOOSE_ANOTHER_DURATION_OR_INTE"
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
		ftp_ramp_hud.reset_for_session()
		session_panel.position = Vector2(-3000,-3000)
		ftp_ramp_hud.show()
		if workout_play_page.get_parent() != session_panel: workout_play_page.reparent(session_panel)
		menu_margin.hide(); menu_tint.hide(); session_panel.show()
	else:
		ftp_ramp_hud.hide()
		session_panel.position = Vector2(30,30)
		if workout_play_page.get_parent() != menu_layout: workout_play_page.reparent(menu_layout)
		session_panel.hide(); menu_margin.show(); menu_tint.show()
	workout_environment_requested.emit(active)

func show_workout_editor() -> void:
	workout_editor_page.refresh_workout_choices()
	_show_section(10, String(TranslationServer.translate("MENU_WORKOUT_EDITOR")), workout_editor_page)

func show_ftp() -> void:
	ftp_page.select_test(false)
	ftp_page.get_meta("preparation_card").preview.set_workout(preload("res://ftp_ramp.gd").preview_blocks(ftp_page.player_profile.ftp()))
	_show_section(8, "MENU_FTP_RAMP_TEST_2", ftp_page)

# Five minutes of free warmup followed by a 20-minute voluntary target at 95% of current FTP.
func _twenty_ftp_preview() -> Array:
	return [
		{"kind":"FreeRide","duration":300.0,"power_low":0.0,"power_high":0.0},
		{"kind":"SteadyState","duration":1200.0,"power_low":0.95,"power_high":0.95}
	]

func show_ftp_twenty() -> void:
	ftp_page.select_test(true)
	ftp_page.get_meta("preparation_card").preview.set_workout(_twenty_ftp_preview())
	_show_section(8, "MENU_20_MINUTE_FTP_TEST", ftp_page)

func _build_settings(layout: VBoxContainer) -> void:
	settings_page = ScrollContainer.new()
	settings_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(settings_page)
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(1260, 0)
	shell.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.PAPER, MenuStyle.LINE, 22))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_page.add_child(center)
	center.add_child(shell)
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
	venue_picker = preload("res://venues/venue_selector.gd").new()
	info.add_child(venue_picker)
	venue_picker.selected.connect(select_venue)
	var options := VBoxContainer.new()
	options.custom_minimum_size.x = 570
	options.add_theme_constant_override("separation", 18)
	row.add_child(options)
	options.add_child(label("RACE_MENU_YOUR_RACE", 30))
	status_label = label("", 21, ACCENT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(status_label)
	race_settings = VBoxContainer.new()
	race_settings.add_theme_constant_override("separation", 16)
	options.add_child(race_settings)
	count_input = _number(race_settings, String(TranslationServer.translate("MENU_RIDERS_INCLUDING_YOU")), 6, 12, 8)
	elimination_count_picker = OptionButton.new()
	for amount in [4, 12, 16]: elimination_count_picker.add_item(String(TranslationServer.translate("OMNIUM_OMNIUM_DETAILS_D_RIDERS")) % amount, amount)
	elimination_count_picker.select(1)
	race_settings.add_child(elimination_count_picker)
	elimination_count_picker.visible = false
	laps_input = _number(race_settings, String(TranslationServer.translate("MENU_LAPS_250_METRES_PER_LAP")), 1, 30, 10)
	difficulty_preferences.load(difficulty_preferences_path)
	keirin_derny = _number(race_settings, String(TranslationServer.translate("MENU_DERNY_PACE_70_45_KM_H_100_50_KM_H")), 40, 120, 80)
	keirin_derny.step = 5
	keirin_derny.value = clampf(snappedf(float(difficulty_preferences.get_value("race", "derny", 80.0)), 5.0), 40.0, 120.0)
	keirin_derny.value_changed.connect(func(value: float): _save_difficulty("derny", value))
	difficulty_label = label(tr("RACE_AI_STRENGTH") % 80, 22)
	race_settings.add_child(difficulty_label)
	difficulty_slider = HSlider.new()
	difficulty_slider.min_value = 40
	difficulty_slider.max_value = 120
	difficulty_slider.step = 5
	difficulty_slider.value = clampf(snappedf(float(difficulty_preferences.get_value("race", "ai", 80.0)), 5.0), 40.0, 120.0)
	LocalizedText.bind(difficulty_label, &"text", func(): return tr("RACE_AI_STRENGTH") % int(difficulty_slider.value))
	difficulty_slider.custom_minimum_size.y = 36
	race_settings.add_child(difficulty_slider)
	difficulty_slider.value_changed.connect(func(value: float) -> void:
		difficulty_label.text = String(TranslationServer.translate("RACE_AI_STRENGTH")) % int(value)
		_save_difficulty("ai", value)
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
	time_trial_settings.add_child(label("MENU_START_TYPE", 22))
	time_trial_start = OptionButton.new()
	time_trial_start.add_item("RACE_MENU_STANDING_START")
	time_trial_start.add_item("MENU_FLYING_START_1_LEAD_IN_LAP")
	time_trial_settings.add_child(time_trial_start)
	time_trial_settings.add_child(label("RECORDS_PAGE_DISTANCE", 22))
	time_trial_distance = OptionButton.new()
	time_trial_distance.add_item("MENU_500_METRES_2_LAPS", 500)
	time_trial_distance.add_item("MENU_1_KILOMETRE_4_LAPS", 1000)
	time_trial_distance.select(1)
	time_trial_settings.add_child(time_trial_distance)
	time_trial_settings.add_child(label("RACE_MENU_COMPARE_WITH", 22))
	time_trial_reference = OptionButton.new()
	for item in [String(TranslationServer.translate("RACE_MENU_LAST_RIDE")), String(TranslationServer.translate("MENU_RECENT_PB_60_DAYS")), String(TranslationServer.translate("MENU_ALL_TIME_PB")), String(TranslationServer.translate("RACE_MENU_NO_COMPARISON"))]:
		time_trial_reference.add_item(item)
	time_trial_settings.add_child(time_trial_reference)
	demo_settings = VBoxContainer.new()
	demo_settings.add_theme_constant_override("separation", 8)
	options.add_child(demo_settings)
	demo_power_input = _number(demo_settings, String(TranslationServer.translate("MENU_DEMO_STARTING_POWER_WITHOUT_TRAINER_W")), 0, 900, 300)
	demo_power_input.step = 25
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 14)
	options.add_child(navigation)
	back_button = Button.new()
	back_button.text = "MENU_RACE_MODES"
	back_button.custom_minimum_size = Vector2(210, 60)
	back_button.add_theme_font_size_override("font_size", 21)
	back_button.pressed.connect(show_choices)
	navigation.add_child(back_button)
	place_back(back_button, settings_page)
	navigation.add_spacer(false)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(310, 60)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", panel_style(ACCENT))
	start_button.add_theme_stylebox_override("hover", panel_style(MenuStyle.BLUE.lightened(.10)))
	MenuStyle.primary(start_button)
	start_button.pressed.connect(func() -> void:
		if not start_button.disabled and (selected in [0, 3, 5, 6, 7, 8] or (selected in [1, 2] and (pursuit_options if selected == 1 else team_options).can_start())):
			if selected in [0, 3, 5, 6, 8]: show_startlist()
			else: start_requested.emit())
	navigation.add_child(start_button)
	select_venue(String(difficulty_preferences.get_value("race", "venue_id", "velodrome")))

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
	if page == 2 and selected in [0, 3, 5, 6, 8]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	page = 1
	page_title.text = "RACE_MENU_CHOOSE_YOUR_RACE"
	choice_page.show()
	settings_page.hide()
	records_page.hide()
	breadcrumb.text = "MENU_01_RACE_MODE_02_SETTINGS"
	if not cards.is_empty():
		cards[selected].grab_focus.call_deferred()

func select_mode(index: int) -> void:
	_hide_hub_pages()
	if page == 2 and selected in [0, 3, 5, 6, 8]: field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
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
	page_title.text = "RACE_MENU_CONFIGURE_YOUR_RACE"
	choice_page.hide()
	settings_page.show()
	breadcrumb.text = "MENU_01_RACE_MODE_02_SETTINGS"
	selected_title.text = MODES[selected]["title"]
	selected_description.text = MODES[selected]["detail"]
	selected_art.texture = previews[selected].get_texture()
	race_settings.visible = selected in [0, 3, 5, 6, 8]
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
	if selected in [0, 3, 8]:
		count_input.max_value = 16 if selected in [3, 8] else 12
		laps_input.max_value = 120 if selected in [3, 8] else 30
		laps_input.min_value = 10 if selected in [3, 8] else 1
		laps_input.step = 10 if selected in [3, 8] else 1
		count_input.value = field_settings[selected][0]
		laps_input.value = field_settings[selected][1]
	if selected == 5:
		for idx in range(elimination_count_picker.item_count):
			if elimination_count_picker.get_item_id(idx) == field_settings[5][0]: elimination_count_picker.select(idx)
	pursuit_options.visible = selected == 1
	team_options.visible = selected == 2
	team_scroll.visible = selected == 2
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 6, 7, 8] and not bridge_seen and not bridge_unavailable
	status_label.text = "MENU_READY_TO_START_CONFIGURE_YOUR_RACE" if selected in [0, 1, 2, 3, 5, 6, 7, 8] else "MENU_PLAYABLE_SOON_THIS_RACE_MODE_IS_STILL_IN_DEVELOPMENT"
	start_button.disabled = selected not in [0, 1, 2, 3, 5, 6, 7, 8]
	start_button.text = "RACE_OPEN_START_LIST" if selected in [0, 3, 5, 6, 8] else "RACE_MENU_START_RACE" if selected in [1, 2, 7] else "MENU_COMING_SOON_3"
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
	bridge_status_text = String(TranslationServer.translate("MENU_TRAINER_CONNECTED")) if live else (String(TranslationServer.translate("MENU_TRAINER_FOUND_WAITING_FOR_DATA")) if seen else String(TranslationServer.translate("MENU_DEMO_AVAILABLE_NO_TRAINER")))
	if unavailable:
		bridge_status_text = String(TranslationServer.translate("MENU_CONNECTION_BUSY_CLOSE_THE_OTHER_GAME_INSTANCE"))
	demo_settings.visible = selected in [0, 1, 2, 3, 5, 6, 7, 8] and not seen and not unavailable
	start_button.disabled = unavailable or selected not in [0, 1, 2, 3, 5, 6, 7, 8]
	if selected in [1, 2]:
		start_button.disabled = start_button.disabled or not (pursuit_options if selected == 1 else team_options).can_start()
	if pursuit_flow != null and pursuit_flow.visible: pursuit_flow.update_bridge()
	if startlist_page != null and startlist_page.visible: startlist_page.update_bridge()

func _pursuit_changed() -> void:
	if selected not in [1, 2] or start_button == null:
		return
	var current = pursuit_options if selected == 1 else team_options
	start_button.disabled = bridge_unavailable or not current.can_start()
	status_label.text = "MENU_CHOOSE_YOUR_DISTANCE_AND_OPPONENT" if current.can_start() else "MENU_NO_SAVED_RIDE_AT_THIS_DISTANCE_YET_RACE_AGAINST_THE_AI_FIRST_AND_SAVE_"

func _unhandled_key_input(event: InputEvent) -> void:
	if keyboard_mapping == null or not keyboard_mapping.enabled: return
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and keyboard_mapping.action_for("menu", event) == "back" and page in [0, 1, 6, 7, 8, 10, 11, 12, 13, 14, 17]:
		bridge_action("B")
		get_viewport().set_input_as_handled()
		return
	if visible and page in [2, 3, 4, 5] and event is InputEventKey and event.is_pressed() and keyboard_mapping.action_for("menu", event) == "back":
		if page == 5: startlist_page.back()
		elif selected in [1,2] and pursuit_flow.visible: pursuit_flow.back()
		else: show_choices()
		get_viewport().set_input_as_handled()

func bridge_action(button: String) -> void:
	if not visible:
		return
	if page == 7 and tournament_page.handle_navigation(button): return
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
		elif page == 16: madison_page.leave()
		elif page == 17:
			if erg_history_page.detail.visible: erg_history_page.detail_back.pressed.emit()
			else: show_training()
		return
	var actions := {"LEFT": "ui_left", "RIGHT": "ui_right", "UP": "ui_up", "DOWN": "ui_down", "A": "ui_accept"}
	if not actions.has(button): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var available := preload("res://ride_navigation.gd").controls(self)
	if not available.has(focused):
		# Results can hide the preparation control that previously had focus.
		# Recover using the visible, enabled controls of the current screen.
		if available.is_empty(): return
		available[0].grab_focus()
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = actions[button]
		event.pressed = pressed
		get_viewport().push_input(event)

func show_records() -> void:
	_hide_hub_pages()
	footer_label.hide()
	page_title.add_theme_font_size_override("font_size",44)
	if startlist_page != null: startlist_page.hide()
	if pursuit_flow != null: pursuit_flow.hide()
	page = 3
	page_title.text = "MENU_RECORDS"
	breadcrumb.text = "MENU_YOUR_FASTEST_TIMES_ON_THE_TRACK"
	choice_page.hide(); settings_page.hide(); records_page.show()
	records_page.open_records()
	records_page.back_button.grab_focus.call_deferred()

func show_startlist() -> void:
	if selected not in [0, 3, 5, 6, 8] or bridge_unavailable: return
	field_settings[selected] = [elimination_count_picker.get_selected_id() if selected == 5 else int(count_input.value), int(laps_input.value)]
	page = 5
	choice_page.hide()
	settings_page.hide()
	pursuit_flow.hide()
	records_page.hide()
	footer_label.hide()
	page_title.text = "RACE_MENU_YOUR_START_LIST"
	breadcrumb.text = "MENU_01_RACE_SETTINGS_02_START_LIST"
	startlist_page.begin()

func _save_difficulty(key: String, value: Variant) -> void:
	difficulty_preferences.set_value("race", key, value)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(difficulty_preferences_path.get_base_dir()))
	difficulty_preferences.save(difficulty_preferences_path)

func start_omnium_warmup() -> void:
	if tournament_page.manager.state.active.is_empty(): return
	show_piste_exercise("free_ride")
	exercise_page.omnium_origin = String(tournament_page.manager.state.active.id)
	exercise_page.begin()
	exercise_page.back_button.text = "RACE_MENU_OMNIUM"

func start_omnium_scratch() -> void:
	_start_omnium_race(preload("res://omnium/omnium_scratch_controller.gd").new(), String(TranslationServer.translate("RACE_MENU_SCRATCH_RACE")))

func start_omnium_tempo() -> void:
	_start_omnium_race(preload("res://omnium/omnium_tempo_controller.gd").new(), String(TranslationServer.translate("RACE_MENU_TEMPO_RACE")))

func start_omnium_points() -> void:
	_start_omnium_race(preload("res://omnium/omnium_points_controller.gd").new(), String(TranslationServer.translate("RACE_MENU_POINTS_RACE")))

func start_omnium_elimination() -> void:
	_start_omnium_race(preload("res://omnium/omnium_elimination_controller.gd").new(), String(TranslationServer.translate("RACE_MENU_ELIMINATION_RACE")))

func _start_omnium_race(controller: RefCounted, caption: String) -> void:
	var game: Node = self
	while game != null and not game.has_method("_configure_peloton"): game = game.get_parent()
	if game == null or game.omnium_race.enabled(): return
	game.omnium_race = controller
	if not controller.start(game, tournament_page.manager):
		var dialog := AcceptDialog.new()
		dialog.dialog_text = caption + String(TranslationServer.translate("MENU_COULD_NOT_BE_STARTED")) + controller.error
		dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free)
		add_child(dialog); dialog.popup_centered()

func show_omnium_details() -> void:
	tournament_page.result_index = -1
	tournament_page.archived_tournament = {}; tournament_page.archive_list = false
	tournament_page.opened = true; tournament_page.editing = false
	tournament_page.refresh()
	_show_section(7, "MENU_OMNIUM", tournament_page)
	tournament_back.grab_focus.call_deferred()

func show_omnium_archive(tournament: Dictionary) -> void:
	tournament_page.open_archive(tournament)
	_show_section(7,"MENU_OMNIUM_RESULTS",tournament_page)
	tournament_back.grab_focus.call_deferred()

func distance_caption(metres: int) -> String:
	var profile = preload("res://venues/venue_catalog.gd").resolved(venue_id)
	var distance := "%d m" % metres if metres < 1000 else "%d km" % (metres / 1000)
	return tr("VENUE_DISTANCE_LAPS") % [distance, roundi(float(metres) / profile.lap_length_m)]

func select_venue(id: String) -> void:
	venue_id = preload("res://venues/venue_catalog.gd").resolved(id).id
	if is_instance_valid(venue_picker): venue_picker.select(venue_id, false)
	library.venue_id = venue_id
	records_store.venue_id = venue_id
	if is_instance_valid(pursuit_options): pursuit_options.library.venue_id = venue_id
	if is_instance_valid(team_options): team_options.library.venue_id = venue_id
	if is_instance_valid(laps_input):
		var lap_length: float = preload("res://venues/venue_catalog.gd").resolved(venue_id).lap_length_m
		var length_label := "166⅔" if is_equal_approx(lap_length, 500.0 / 3.0) else str(roundi(lap_length))
		laps_input.get_meta("caption").text = tr("VENUE_LAPS_CAPTION") % length_label
	if is_instance_valid(time_trial_distance):
		for i in time_trial_distance.item_count: time_trial_distance.set_item_text(i, distance_caption(time_trial_distance.get_item_id(i)))
	if is_instance_valid(pursuit_flow): pursuit_flow.venue_changed()
	_save_difficulty("venue_id", venue_id)
