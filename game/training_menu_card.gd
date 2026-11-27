extends CenterContainer
## Shared preparation card; the existing session owns all training behaviour.
const Style := preload("res://menu_theme.gd")
var page: VBoxContainer
var host: Control
var summary: Label
var preview: Control
var overview: Label
var exercise_previews := {}
var result_presentation := false
var help_toggle: Button
var help_panel: ScrollContainer
var venue_picker: VBoxContainer

func configure(menu: Control, training: VBoxContainer, controls: Array, artwork: Control) -> void:
	host = menu
	page = training
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(self)
	page.move_child(self, 0)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 1260
	panel.add_theme_stylebox_override("panel", Style.panel(Style.PAPER, Style.LINE, 24))
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	panel.add_child(columns)
	var information := VBoxContainer.new()
	information.custom_minimum_size.x = 540
	information.add_theme_constant_override("separation", 14)
	columns.add_child(information)
	preview = artwork
	preview.custom_minimum_size = Vector2(540, 190)
	information.add_child(preview)
	summary = Label.new()
	summary.custom_minimum_size.x = 540
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 22)
	information.add_child(summary)
	help_toggle = Button.new()
	help_toggle.toggle_mode = true
	help_toggle.flat = true
	help_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_toggle.text = "TRAINING_MENU_CARD_INSTRUCTIONS_AND_CONTROLS"
	help_toggle.icon = Style.icon('<path d="m7 5 5 5 5-5M7 12l5 5 5-5"/>', Style.BLUE)
	help_toggle.tooltip_text = "TRAINING_MENU_CARD_SHOW_INSTRUCTIONS"
	help_toggle.add_theme_stylebox_override("pressed", Style.panel(Style.PALE, Style.LINE, 12, 9))
	help_toggle.add_theme_color_override("font_pressed_color", Style.INK)
	information.add_child(help_toggle)
	var help := ScrollContainer.new()
	help_panel = help
	help.custom_minimum_size = Vector2(540, 140)
	help.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	information.add_child(help)
	page.detail.reparent(help)
	page.detail.custom_minimum_size.x = 510
	page.detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.detail.add_theme_font_size_override("font_size", 19)
	help.hide()
	help_toggle.toggled.connect(func(expanded):
		help.visible = expanded
		help_toggle.icon = Style.icon('<path d="m7 12 5-5 5 5M7 19l5-5 5 5"/>' if expanded else '<path d="m7 5 5 5 5-5M7 12l5 5 5-5"/>', Style.BLUE)
		help_toggle.tooltip_text = String(TranslationServer.translate("TRAINING_MENU_CARD_HIDE_INSTRUCTIONS")) if expanded else String(TranslationServer.translate("TRAINING_MENU_CARD_SHOW_INSTRUCTIONS")))
	var options := VBoxContainer.new()
	options.custom_minimum_size.x = 570
	options.add_theme_constant_override("separation", 10)
	columns.add_child(options)
	var heading := Label.new()
	heading.text = "TRAINING_MENU_CARD_YOUR_TRAINING"
	heading.add_theme_font_override("font", Style.heading())
	heading.add_theme_font_size_override("font_size", 30)
	options.add_child(heading)
	overview = Label.new()
	overview.add_theme_font_size_override("font_size", 20)
	overview.add_theme_color_override("font_color", Style.MUTED)
	options.add_child(overview)
	overview.hide()
	for control in controls: control.reparent(options)
	venue_picker = preload("res://venues/venue_selector.gd").new()
	venue_picker.tile_size = Vector2(168, 102)
	venue_picker.selected_id = menu.venue_id
	options.add_child(venue_picker)
	venue_picker.selected.connect(menu.select_venue)
	menu.training_venue_pickers.append(venue_picker)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	page.add_child(actions)
	var upload: Button = page.get("upload_button")
	if upload != null:
		upload.reparent(actions)
		upload.text = "TRAINING_MENU_CARD_UPLOAD_TO_STRAVA"
	actions.add_spacer(false)
	var edit: Button = page.get("edit_button")
	if edit != null: edit.reparent(actions)
	page.stop_button.reparent(actions)
	page.start_button.reparent(actions)
	page.start_button.custom_minimum_size = Vector2(310, 60)
	Style.primary(page.start_button)
	menu.place_back(page.back_button, page)
	page.title.hide()
	page.result.add_theme_font_size_override("font_size", 22)
	page.result.add_theme_color_override("font_color", Style.MUTED)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if page == null: return
	var model = page.get("session") if page.get("session") != null else page.get("test")
	var activity = page.get("selected_activity")
	var has_result: bool = activity is Dictionary and not activity.is_empty()
	if has_result and page.is_visible_in_tree(): host.page_title.text = String(tr(page.title.text)) + tr("TRAINING_MENU_CARD_RESULT")
	if has_result != result_presentation:
		result_presentation = has_result
		if has_result:
			page.result.add_theme_stylebox_override("normal", Style.panel(Style.PAPER, Style.LINE, 18))
			page.result.add_theme_font_size_override("font_size", 26)
			page.result.add_theme_color_override("font_color", Style.INK)
		else:
			page.result.remove_theme_stylebox_override("normal")
			page.result.add_theme_font_size_override("font_size", 22)
			page.result.add_theme_color_override("font_color", Style.MUTED)
	visible = not model.running() and not has_result and model.phase != "RESULT"
	summary.text = String(tr(page.detail.text)).get_slice("\n", 0)
	page.title.hide()
	if preview is TextureRect and not exercise_previews.is_empty():
		preview.texture = exercise_previews.get(page.get("kind"), preview.texture)
		overview.visible = page.get("kind") != "take_lap"
		overview.text = "TRAINING_DURATION_FREE_WITHOUT_A_TIME_LIMIT_PACERS_30_35_40_45_KM_H_RECORDING_T" if page.get("kind") == "free_ride" else "TRAINING_START_30_KM_H_AT_THE_BOTTOM_OF_THE_TRACK_PREPARATION_ONE_LAP_GOAL_HIGH"

static func chart(blocks: Array = []) -> Control:
	var node := preload("res://training_tile_art.gd").new()
	if not blocks.is_empty(): node.set_workout(blocks)
	return node

static func picture(texture: Texture2D) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return node
