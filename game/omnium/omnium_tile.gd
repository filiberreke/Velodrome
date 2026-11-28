extends Button
## Four existing discipline postcards, sharing the game's visual language.
const Style := preload("res://menu_theme.gd")
const LocalizedText := preload("res://localized_text.gd")
const DISCIPLINE_KEYS := [
	"RACE_MENU_SCRATCH_RACE",
	"RACE_MENU_TEMPO_RACE",
	"RACE_MENU_ELIMINATION_RACE",
	"RACE_MENU_POINTS_RACE",
]
var menu
var manager

func _ready() -> void:
	name = String(TranslationServer.translate("MENU_OMNIUM"))
	custom_minimum_size = Vector2(0, 490)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, Style.panel(Style.PAPER if state == "normal" else Style.PALE, Style.LINE if state == "normal" else Style.BLUE, 20, 16))
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26; content.offset_top = 22
	content.offset_right = -26; content.offset_bottom = -22
	content.add_theme_constant_override("separation", 30)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_stretch_ratio = 0.85
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 16)
	content.add_child(copy)
	copy.add_child(menu.label("OMNIUM_FOUR_DISCIPLINES", 16, Style.MUTED))
	var title: Label = menu.label("Omnium →", 44)
	title.add_theme_font_override("font", Style.heading())
	copy.add_child(title)
	var active: Dictionary = manager.state.active
	if active.is_empty():
		var description: Label = menu.label(String(TranslationServer.translate("OMNIUM_TILE_DESCRIPTION")), 22)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(description)
		copy.add_child(menu.label("Nieuw omnium samenstellen", 22, Style.BLUE))
	else:
		var completed: int = active.results.size()
		var rider_count: int = active.riders.size()
		var progress: Label = menu.label("", 22, Style.BLUE)
		copy.add_child(progress)
		LocalizedText.bind(progress, &"text", func(): return tr("OMNIUM_TILE_PROGRESS") % [completed, rider_count])
		var next_race: Label = menu.label("", 22)
		copy.add_child(next_race)
		LocalizedText.bind(next_race, &"text", func(): return tr("OMNIUM_TILE_NEXT_RACE") % tr(DISCIPLINE_KEYS[mini(completed, DISCIPLINE_KEYS.size() - 1)]))
		if manager.deadline() > 0:
			var date := Time.get_datetime_dict_from_unix_time(manager.deadline())
			copy.add_child(menu.label(String(TranslationServer.translate("OMNIUM_END_DATE")) % [date.day, date.month, int(date.year) % 100], 22, Style.BLUE))
		else:
			copy.add_child(menu.label(String(TranslationServer.translate("OMNIUM_DEADLINE_START")), 19, Style.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.25
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	var preview_indices := [0, 8, 5, 3]
	for i in DISCIPLINE_KEYS.size():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Style.panel(Style.IVORY, Style.LINE, 8, 6))
		grid.add_child(panel)
		var column := VBoxContainer.new(); panel.add_child(column)
		var art := TextureRect.new()
		art.texture = menu.previews[preview_indices[i]].get_texture()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(220, 150)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(art)
		column.add_child(menu.label(DISCIPLINE_KEYS[i], 20))
	ignore_children(content)

func ignore_children(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_children(child)
