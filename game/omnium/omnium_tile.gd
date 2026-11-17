extends Button
## Four existing discipline postcards, sharing the game's visual language.
const Style := preload("res://menu_theme.gd")
var menu
var manager

func _ready() -> void:
	name = "Omnium"
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
	copy.add_child(menu.label("VIER DISCIPLINES · ÉÉN KLASSEMENT", 16, Style.MUTED))
	var title: Label = menu.label("Omnium →", 44)
	title.add_theme_font_override("font", Style.heading())
	copy.add_child(title)
	var description: Label = menu.label("Scratch, temporace, afvalling en puntenkoers.\nBouw je voorsprong op, van de eerste tot de laatste sprint.", 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	var active: Dictionary = manager.state.active
	if active.is_empty():
		copy.add_child(menu.label("Nieuw omnium samenstellen", 22, Style.BLUE))
	else:
		var completed: int = active.results.size()
		copy.add_child(menu.label("%d/4 wedstrijden voltooid · %d deelnemers" % [completed, active.riders.size()], 22, Style.BLUE))
		var next_name: String = ["Scratch", "Temporace", "Afvalling", "Puntenkoers"][mini(completed, 3)]
		copy.add_child(menu.label("Volgende wedstrijd: " + next_name, 22))
		if manager.deadline() > 0:
			var date := Time.get_datetime_dict_from_unix_time(manager.deadline())
			copy.add_child(menu.label("Dit omnium eindigt op %02d/%02d/%02d" % [date.day, date.month, int(date.year) % 100], 22, Style.BLUE))
		else:
			copy.add_child(menu.label("De termijn begint bij de start van de scratch.", 19, Style.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.25
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for item in [[0,"Scratch"],[8,"Temporace"],[5,"Afvalling"],[3,"Puntenkoers"]]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Style.panel(Style.IVORY, Style.LINE, 8, 6))
		grid.add_child(panel)
		var column := VBoxContainer.new(); panel.add_child(column)
		var art := TextureRect.new()
		art.texture = menu.previews[item[0]].get_texture()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(220, 150)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(art)
		column.add_child(menu.label(item[1], 20))
	ignore_children(content)

func ignore_children(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_children(child)
