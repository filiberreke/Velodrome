extends PanelContainer
const MenuStyle := preload("res://menu_theme.gd")
signal selected(entry: Dictionary)
const Catalog := preload("res://rider_catalog.gd")
const Appearance := preload("res://player_appearance.gd")
var entries: Array[Dictionary] = []
var cards: Array[Control] = []
var search: LineEdit
var country_filter: OptionButton
var type_filter: OptionButton
var grid: GridContainer
var count_label: Label
var layer: CanvasLayer

func label(text: String, size: int = 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", MenuStyle.INK)
	return node

func _ready() -> void:
	theme = MenuStyle.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = MenuStyle.IVORY
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: background.set_content_margin(side, 28)
	add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label("Kies je tegenstander", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "← Terug"
	close.custom_minimum_size = Vector2(150, 48)
	close.pressed.connect(func(): layer.queue_free())
	header.add_child(close)
	column.add_child(label("Vaste kwaliteiten · afgeronde basiswaarden · dagvorm 97,5–102,5%", 18))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 16)
	column.add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = "Zoek een renner"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 46
	filters.add_child(search)
	country_filter = OptionButton.new()
	country_filter.add_item("Alle landen")
	country_filter.set_item_metadata(0, "")
	var countries: Array[String] = []
	for entry in entries:
		if entry.country not in countries: countries.append(entry.country)
	countries.sort()
	for country in countries:
		country_filter.add_item(country_name(country))
		country_filter.set_item_metadata(country_filter.item_count - 1, country)
	filters.add_child(country_filter)
	type_filter = OptionButton.new()
	type_filter.add_item("Alle specialiteiten", 0)
	for i in range(1,4): type_filter.add_item(Catalog.TYPES[i], i)
	filters.add_child(type_filter)
	count_label = label("")
	column.add_child(count_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for entry in entries: _card(entry)
	search.text_changed.connect(func(_text): apply_filter())
	country_filter.item_selected.connect(func(_index): apply_filter())
	type_filter.item_selected.connect(func(_index): apply_filter())
	resized.connect(_resize_grid)
	_resize_grid()
	apply_filter()
	search.grab_focus.call_deferred()

static func country_name(id: String) -> String:
	return "België" if id == "belgium" else String(Appearance.COUNTRY_NAMES.get(id, id.capitalize()))

func _resize_grid() -> void:
	if grid != null: grid.columns = 4 if size.x >= 1550 else (3 if size.x >= 1150 else (2 if size.x >= 760 else 1))

func _card(entry: Dictionary) -> void:
	var card = preload("res://rider_passport.gd").new()
	card.entry = entry
	grid.add_child(card)
	cards.append(card)
	card.selected.connect(func(chosen: Dictionary): selected.emit(chosen); layer.queue_free())
	card.records_requested.connect(show_records)

func apply_filter() -> void:
	var total := 0
	for i in entries.size():
		var e := entries[i]
		var country := String(country_filter.get_selected_metadata())
		var matches: bool = (search.text.is_empty() or String(e.name).to_lower().contains(search.text.to_lower())) and (country.is_empty() or e.country == country) and (type_filter.get_selected_id() == 0 or e.profile == type_filter.get_selected_id())
		cards[i].visible = matches
		if matches: total += 1
	count_label.text = "%d renner%s" % [total, "" if total == 1 else "s"]

func show_records(entry: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = entry.name + " · " + country_name(entry.country)
	var details := "ID: %s\nCP %d W · Piek %d W · W′ %d J\n\nOpgegeven records" % [entry.id, roundi(entry.cp_w), roundi(entry.max_power_w), roundi(entry.w_prime_j)]
	for distance in [250, 1000, 4000]:
		var seconds := float(entry.records.get("record_%dm_s" % distance, 0.0))
		details += "\n%d m: %s" % [distance, "%d s" % roundi(seconds) if seconds > 0 else "nog geen record"]
	for duration in [5,15,60]:
		var watts := float(entry.records.get("best_%ds_w" % duration, 0.0))
		details += "\n%d s: %s" % [duration, "%d W" % roundi(watts) if watts > 0 else "nog geen record"]
	var saved := preload("res://rider_records.gd").new().personal(entry.id)
	details += "\n\nBehaalde spelrecords (per discipline, afstand en AI-percentage)"
	if saved.is_empty(): details += "\nNog geen voltooide prestatie."
	for key in saved:
		var record: Dictionary = saved[key]
		details += "\n%s · %d m · AI %d%%: %d s · piek %d W" % ["Achtervolging" if int(record.mode) == 4 else ("Puntenkoers" if int(record.mode) == 1 else "Scratch"), int(record.distance_m), roundi(record.ai_percent), roundi(record.time_s), roundi(record.peak_w)]
		if not record.get("parameters",{}).is_empty(): details += " · CP %d W" % roundi(record.parameters.cp_w)
	dialog.dialog_text = details
	add_child(dialog)
	dialog.popup_centered(Vector2i(680, 560))
	dialog.confirmed.connect(dialog.queue_free)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	var owner_node: Node = get_parent()
	while owner_node != null:
		var mapping = owner_node.get("keyboard_mapping")
		if mapping != null:
			if mapping.enabled and mapping.action_for("menu", event) == "back":
				layer.queue_free()
				get_viewport().set_input_as_handled()
			return
		owner_node = owner_node.get_parent()

func bridge_action(button: String) -> void:
	if button == "B": layer.queue_free(); return
	var actions := {"LEFT":"ui_left", "RIGHT":"ui_right", "UP":"ui_up", "DOWN":"ui_down", "A":"ui_accept"}
	if not actions.has(button): return
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action = actions[button];event.pressed = pressed
		get_viewport().push_input(event)
