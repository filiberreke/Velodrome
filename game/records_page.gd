extends VBoxContainer
signal back_requested
const Store := preload("res://performance_records.gd")
var store = Store.new()
var mode_choice: OptionButton
var distance_choice: OptionButton
var size_choice: OptionButton
var size_box: VBoxContainer
var rows: VBoxContainer
var message: Label
var back_button: Button
var shown: Array[Dictionary] = []

func _label(value: String, font: int, tint: Color = Color("f3f5fa")) -> Label:
	var node := Label.new(); node.text = value
	node.add_theme_font_size_override("font_size", font)
	node.add_theme_color_override("font_color", tint)
	return node

func _choice(parent: HBoxContainer, title: String) -> OptionButton:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box); box.add_child(_label(title, 17, Color("a8bdce")))
	var node := OptionButton.new(); node.custom_minimum_size.y = 48
	node.add_theme_font_size_override("font_size", 21); box.add_child(node)
	return node

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	var filters := HBoxContainer.new(); filters.add_theme_constant_override("separation", 20); add_child(filters)
	mode_choice = _choice(filters, "Spelvorm")
	mode_choice.add_item("Achtervolging", 4); mode_choice.add_item("Ploegenachtervolging", 5)
	distance_choice = _choice(filters, "Afstand")
	distance_choice.add_item("1 km", 1000); distance_choice.add_item("4 km", 4000)
	size_choice = _choice(filters, "Ploegomvang")
	size_choice.add_item("3 renners", 3); size_choice.add_item("4 renners", 4)
	size_box = size_choice.get_parent()
	for item in [mode_choice, distance_choice, size_choice]: item.item_selected.connect(func(_index: int) -> void: refresh())
	var header := HBoxContainer.new(); add_child(header)
	_cell(header, "#", 55); _cell(header, "SPELER", 330); _cell(header, "DATUM / TIJD", 440); _cell(header, "EINDTIJD", 200)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	rows = VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8); scroll.add_child(rows)
	message = _label("", 19, Color("a8bdce")); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(message)
	back_button = Button.new(); back_button.text = "← Spelvormen"; back_button.custom_minimum_size = Vector2(260, 52)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; back_button.add_theme_font_size_override("font_size", 22)
	back_button.pressed.connect(func() -> void: back_requested.emit()); add_child(back_button)

func _cell(row: HBoxContainer, value: String, width: float) -> Label:
	var label := _label(value, 22)
	label.custom_minimum_size.x = width
	label.clip_text = true; label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = value; row.add_child(label); return label

static func time_text(seconds: float) -> String:
	var centiseconds: int = roundi(seconds * 100.0)
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func refresh(import_old: bool = false) -> void:
	if import_old: store.import_saved()
	var import_error: String = store.last_error
	size_box.visible = mode_choice.get_selected_id() == 5
	shown = store.top(mode_choice.get_selected_id(), distance_choice.get_selected_id(), size_choice.get_selected_id() if size_box.visible else 0)
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	for index in range(shown.size()):
		var entry: Dictionary = shown[index]
		var shell := PanelContainer.new()
		var style := StyleBoxFlat.new(); style.bg_color = Color(0.12, 0.17, 0.21, 0.82)
		style.set_corner_radius_all(10); style.set_content_margin_all(10)
		shell.add_theme_stylebox_override("panel", style); rows.add_child(shell)
		var row := HBoxContainer.new(); row.custom_minimum_size.y = 30; shell.add_child(row)
		_cell(row, str(index + 1), 55).add_theme_color_override("font_color", Color("f4d46a") if index == 0 else Color("a8bdce"))
		_cell(row, str(entry["player_name"]), 330)
		_cell(row, str(entry["finished_local"]), 440)
		_cell(row, time_text(float(entry["seconds"])), 200)
	message.text = import_error if not import_error.is_empty() else store.last_error
	if message.text.is_empty():
		message.text = "Nog geen prestaties in deze categorie. Voltooi een rit om automatisch je tijd te registreren." if shown.is_empty() else "Snelste 10 voltooide prestaties · automatisch bewaard · beste tijd bovenaan"
		for entry in shown:
			if bool(entry.get("legacy", false)):
				message.text += "\nOude rit: spelernaam was niet opgeslagen; de datum is het toenmalige opslagmoment (UTC)."
				break
