extends VBoxContainer
signal back_requested
const MenuStyle := preload("res://menu_theme.gd")
const Store := preload("res://performance_records.gd")
const TimeTrials := preload("res://time_trial_records.gd")
var time_trials = TimeTrials.new()
var store = Store.new()
var mode_choice: OptionButton
var distance_choice: OptionButton
var start_choice: OptionButton
var size_choice: OptionButton
var size_box: VBoxContainer
var rows: VBoxContainer
var message: Label
var back_button: Button
var category: Label
var mode_buttons: Array[Button] = []
var distance_caption: Label
var distance_buttons: Array[Button] = []
var shown: Array[Dictionary] = []
var _last_opened_time_trial_id := ""

func _label(value: String, font: int, tint: Color = MenuStyle.INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font)
	node.add_theme_color_override("font_color", tint)
	return node

func _ready() -> void:
	theme = MenuStyle.create()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 16)
	add_child(filters)
	# Visible segmented buttons share the existing category IDs and filter state.
	mode_choice = OptionButton.new()
	mode_choice.add_item("Achtervolging", 4)
	mode_choice.add_item("Ploegenachtervolging", 5)
	mode_choice.add_item("Tijdrit", 7)
	add_child(mode_choice)
	mode_choice.hide()
	distance_choice = OptionButton.new()
	distance_choice.add_item("1 km", 1000)
	distance_choice.add_item("4 km", 4000)
	add_child(distance_choice)
	distance_choice.hide()
	for i in range(mode_choice.item_count):
		var button := Button.new()
		button.text = mode_choice.get_item_text(i)
		button.toggle_mode = true
		MenuStyle.toggle_focus(button)
		button.custom_minimum_size = Vector2([260,330,150][i], 54)
		button.pressed.connect(func() -> void: mode_choice.select(i); refresh())
		filters.add_child(button)
		mode_buttons.append(button)
	filters.add_spacer(false)
	distance_caption = _label("Afstand", 19, MenuStyle.MUTED)
	filters.add_child(distance_caption)
	for i in range(2):
		var button := Button.new()
		button.text = distance_choice.get_item_text(i)
		button.toggle_mode = true
		MenuStyle.toggle_focus(button)
		button.custom_minimum_size = Vector2(120, 54)
		button.pressed.connect(func() -> void: distance_choice.select(i); refresh())
		filters.add_child(button)
		distance_buttons.append(button)
	start_choice = OptionButton.new()
	start_choice.add_item("Staande start")
	start_choice.add_item("Vliegende start")
	start_choice.custom_minimum_size = Vector2(230, 54)
	start_choice.tooltip_text = "Startwijze tijdrit"
	filters.add_child(start_choice)
	size_box = VBoxContainer.new()
	filters.add_child(size_box)
	size_choice = OptionButton.new()
	size_choice.custom_minimum_size = Vector2(180, 54)
	size_choice.add_item("3 renners", 3)
	size_choice.add_item("4 renners", 4)
	size_choice.tooltip_text = "Ploegomvang"
	size_box.add_child(size_choice)
	for choice in [mode_choice, distance_choice, size_choice, start_choice]:
		choice.item_selected.connect(func(_index: int) -> void: refresh())
	var summary := HBoxContainer.new()
	add_child(summary)
	category = _label("", 28)
	category.add_theme_font_override("font", MenuStyle.heading())
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(category)
	summary.add_child(_label("TOP 10", 17, MenuStyle.MUTED))
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.PALE, Color.TRANSPARENT, 12, 8))
	add_child(header)
	var captions := HBoxContainer.new()
	header.add_child(captions)
	_cell(captions, "#", 1)
	_cell(captions, "Speler", 5)
	_cell(captions, "Datum / tijd", 5)
	_cell(captions, "Eindtijd", 2, true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	scroll.add_child(rows)
	message = _label("", 18, MenuStyle.MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	back_button = Button.new()
	back_button.text = "← Spelvormen"
	back_button.custom_minimum_size = Vector2(260, 52)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)

func _cell(row: HBoxContainer, value: String, weight: float, right: bool = false) -> Label:
	var label := _label(value, 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = weight
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	return label

static func time_text(seconds: float) -> String:
	var centiseconds: int = roundi(seconds * 100.0)
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func open_records() -> void:
	# A newly completed time trial should be visible without guessing its filters.
	# Keep deliberate filter changes when reopening without a newer result.
	var latest: Dictionary = {}
	for ride in time_trials.all_rides():
		if latest.is_empty() or float(ride["finished_at"]) > float(latest["finished_at"]):
			latest = ride
	if not latest.is_empty():
		var result_id: String = str(latest.get("id", "%s:%s" % [latest["finished_at"], latest["distance_m"]]))
		if result_id != _last_opened_time_trial_id:
			mode_choice.select(2)
			distance_choice.select(0 if int(latest["distance_m"]) == 500 else 1)
			start_choice.select(1 if latest.get("start_type", "standing") == "flying" else 0)
			_last_opened_time_trial_id = result_id
	refresh(true)

func refresh(import_old: bool = false) -> void:
	if import_old: store.import_saved()
	var import_error: String = store.last_error
	size_box.visible = mode_choice.get_selected_id() == 5
	var future := mode_choice.get_selected_id() == 7
	start_choice.visible = future
	# The hidden selector shares index 0/1 across disciplines, but its IDs must
	# match the visible distances. A stale 4000 ID used to reset solo 1 km to 500 m.
	distance_choice.set_item_id(0, 500 if future else 1000)
	distance_choice.set_item_id(1, 1000 if future else 4000)
	distance_choice.set_item_text(0, "500 m" if future else "1 km")
	distance_choice.set_item_text(1, "1 km" if future else "4 km")
	for i in range(mode_buttons.size()): mode_buttons[i].button_pressed = mode_choice.selected == i
	for i in range(distance_buttons.size()):
		distance_buttons[i].text = ("500 m" if i == 0 else "1 km") if future else ("1 km" if i == 0 else "4 km")
		distance_buttons[i].button_pressed = distance_choice.selected == i
		distance_buttons[i].visible = true
	distance_caption.visible = true
	category.text = "%s · %s" % [mode_choice.text, "500 m" if distance_choice.selected == 0 else "1 km"] if future else "%s · %s%s" % [mode_choice.text, distance_choice.text, " · " + size_choice.text if size_box.visible else ""]
	shown.clear()
	if future:
		var meters: int = 500 if distance_choice.selected == 0 else 1000
		var start_type := "flying" if start_choice.selected == 1 else "standing"
		category.text += " · " + start_choice.text
		var references := time_trials.references(meters, -1.0, start_type)
		shown.assign(time_trials.all_rides().filter(func(r): return int(r["distance_m"]) == meters and str(r.get("start_type", "standing")) == start_type))
		shown.sort_custom(func(a, b): return float(a["seconds"]) < float(b["seconds"]))
		shown = shown.slice(0, 10)
		message.text = "All-time: %s · Recent (60 dagen): %s · Laatste rit: %s" % [_record_time(references["alltime"]), _record_time(references["recent"]), _record_time(references["last"])]
	else: shown = store.top(mode_choice.get_selected_id(), distance_choice.get_selected_id(), size_choice.get_selected_id() if size_box.visible else 0)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for index in range(shown.size()):
		var entry: Dictionary = shown[index]
		var shell := PanelContainer.new()
		shell.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.GOLD if index == 0 else (MenuStyle.PAPER if index % 2 == 0 else MenuStyle.IVORY), Color.TRANSPARENT, 6, 4))
		rows.add_child(shell)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 26
		shell.add_child(row)
		_cell(row, str(index + 1), 1)
		_cell(row, str(entry.get("player_name", "Jij")), 5)
		_cell(row, str(entry.get("finished_local", Time.get_datetime_string_from_unix_time(int(entry["finished_at"])))), 5)
		_cell(row, time_text(float(entry["seconds"])), 2, true)
	if not future: message.text = import_error if not import_error.is_empty() else store.last_error
	if message.text.is_empty():
		message.text = "Nog geen voltooide tijdrit op deze afstand." if future else "Nog geen prestaties in deze categorie. Voltooi een rit om automatisch je tijd te registreren." if shown.is_empty() else "Snelste 10 voltooide prestaties · automatisch bewaard · beste tijd bovenaan"
		for entry in shown:
			if bool(entry.get("legacy", false)):
				message.text += "\nOude rit: spelernaam was niet opgeslagen; de datum is het toenmalige opslagmoment (UTC)."
				break

static func _record_time(ride: Dictionary) -> String:
	return time_text(float(ride["seconds"])) if not ride.is_empty() else "--"
