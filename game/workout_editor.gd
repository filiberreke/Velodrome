extends VBoxContainer
## Standalone ZWO workout editor, embedded in the training menu.
signal back_requested
signal workout_saved(id: String)
signal workout_deleted(id: String)
var library = preload("res://workout_library.gd").new()
var current_id := ""
var workout_choice: OptionButton
var delete_workout_button: Button
var delete_dialog: ConfirmationDialog
var pending_delete_id := ""
const Workout := preload("res://zwo_workout.gd")
const MenuStyle := preload("res://menu_theme.gd")
const PANEL := MenuStyle.PAPER
const BLUE := MenuStyle.BLUE
var blocks: Array[Dictionary] = []
var selected := -1
var name_edit: LineEdit
var block_buttons: Array[Button] = []
var action_buttons: Array[Button] = []
var graph: Control
var inspector: VBoxContainer
var duration_spin: SpinBox
var power_spin: SpinBox
var high_spin: SpinBox
var message_edit: LineEdit
var offset_spin: SpinBox
var status: Label
var summary: Label
var open_dialog: FileDialog
var save_dialog: FileDialog
var back_button: Button

func _ready() -> void:
	theme = MenuStyle.create()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var selection := HBoxContainer.new()
	add_child(selection)
	workout_choice = OptionButton.new()
	workout_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.add_child(workout_choice)
	workout_choice.item_selected.connect(func(index):
		var id := str(workout_choice.get_item_metadata(index))
		if id.is_empty(): new_workout()
		else: load_workout(id)
	)
	_button(selection,"Nieuwe workout",new_workout)
	MenuStyle.primary(_button(selection,"Opslaan",save_workout))
	delete_workout_button = _button(selection,"Workout verwijderen",request_delete_workout)
	MenuStyle.destructive(delete_workout_button)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Workout verwijderen?"
	delete_dialog.get_ok_button().text = "Verwijderen"
	MenuStyle.destructive(delete_dialog.get_ok_button())
	delete_dialog.get_cancel_button().text = "Annuleren"
	delete_dialog.confirmed.connect(_confirm_delete_workout)
	delete_dialog.canceled.connect(func(): pending_delete_id = "")
	add_child(delete_dialog)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	name_edit = LineEdit.new()
	name_edit.text = "Nieuwe training"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(name_edit)
	_button(toolbar, "Importeer .zwo", _open)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	var library := _panel(columns, 235)
	library.add_child(_label("BOUWSTENEN", 23))
	for kind in ["Warmup", "SteadyState", "Recovery", "IntervalsT", "FreeRide", "Cooldown"]:
		_button(library, _display(kind) + "  +", func(): _add(kind))
	var middle := _panel(columns, 660)
	middle.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_label("WORKOUT", 23))
	middle.add_child(_label("Klik op een blok om de details rechts te bewerken.", 17))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	graph = Control.new()
	graph.name = "WorkoutTimeline"
	graph.custom_minimum_size = Vector2(600, 280)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.draw.connect(_draw_graph)
	graph.resized.connect(_layout_blocks)
	scroll.add_child(graph)
	var controls := HBoxContainer.new()
	middle.add_child(controls)
	action_buttons.append(_button(controls, "← Links", func(): _move(-1)))
	action_buttons.append(_button(controls, "Rechts →", func(): _move(1)))
	action_buttons.append(_button(controls, "Dupliceren", _duplicate))
	action_buttons.append(_button(controls, "Verwijderen", _remove))
	var right := _panel(columns, 270)
	right.add_child(_label("GESELECTEERD BLOK", 22))
	inspector = VBoxContainer.new()
	right.add_child(inspector)
	var footer := HBoxContainer.new()
	add_child(footer)
	summary = _label("", 18)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(summary)
	status = _label("", 15)
	footer.add_child(status)
	back_button = _button(footer, "← ERG-training", func(): back_requested.emit())
	_button(footer, "Exporteer .zwo", _export)
	open_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE)
	save_dialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE)
	open_dialog.file_selected.connect(_load_file)
	save_dialog.file_selected.connect(_save_file)
	new_workout()

func refresh_workout_choices() -> void:
	delete_workout_button.visible = not current_id.is_empty()
	workout_choice.clear()
	workout_choice.add_item("Nieuwe workout")
	workout_choice.set_item_metadata(0,"")
	for item in library.all_workouts():
		workout_choice.add_item(item.name)
		workout_choice.set_item_metadata(workout_choice.item_count-1,item.id)
		if item.id == current_id: workout_choice.select(workout_choice.item_count-1)
func new_workout() -> void:
	pending_delete_id = ""
	delete_dialog.hide()
	current_id = ""
	name_edit.text = "Nieuwe training"
	blocks.clear()
	for kind in ["Warmup","SteadyState","Recovery","Cooldown"]: blocks.append(_new_block(kind))
	_select(0)
	refresh_workout_choices()
	status.text = "Nieuwe workout"
func load_workout(id: String) -> void:
	var item: Dictionary = library.get_workout(id)
	if item.is_empty(): status.text = "Workout niet gevonden"; return
	current_id = id
	name_edit.text = item.name
	blocks.clear()
	for block in item.blocks: blocks.append(block.duplicate(true))
	_select(0)
	refresh_workout_choices()
	status.text = "Workout geopend"
func save_workout() -> void:
	var id: String = library.save_workout(current_id,name_edit.text,blocks)
	if id.is_empty(): status.text = library.error; return
	current_id = id
	refresh_workout_choices()
	status.text = "Workout opgeslagen"
	workout_saved.emit(id)

func request_delete_workout() -> void:
	var item: Dictionary = library.get_workout(current_id)
	if item.is_empty(): return
	pending_delete_id = current_id
	delete_dialog.dialog_text = 'Wil je "%s" definitief verwijderen?\nDit kan niet ongedaan worden gemaakt.' % str(item.name)
	delete_dialog.popup_centered(Vector2i(540,180))
	delete_dialog.get_cancel_button().grab_focus.call_deferred()
func _confirm_delete_workout() -> void:
	var id := pending_delete_id
	pending_delete_id = ""
	if id.is_empty() or id != current_id: return
	if not library.delete_workout(id): status.text = library.error; return
	new_workout()
	status.text = "Workout verwijderd"
	workout_deleted.emit(id)

func _panel(parent: Node, min_width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func _style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	return s

func _label(value: String, size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MenuStyle.INK)
	return l

func _button(parent: Node, title: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _display(kind: String) -> String:
	match kind:
		"Warmup": return "Opwarming"
		"Recovery": return "Herstel"
		"SteadyState": return "Constant vermogen"
		"IntervalsT": return "Interval"
		"FreeRide": return "Free Ride"
		"Cooldown": return "Cooldown"
	return kind

func _new_block(kind: String) -> Dictionary:
	var power := 0.55 if kind == "Recovery" else 0.88
	if kind == "Warmup" or kind == "Cooldown": power = 0.5
	return {"kind":kind, "duration":600.0 if kind in ["Warmup", "Cooldown"] else 180.0,
		"power_low":power, "power_high":0.75 if kind == "Warmup" else power,
		"events":[], "repeat":3, "on_duration":60.0, "off_duration":60.0,
		"on_power":1.1, "off_power":0.55}

func _add(kind: String) -> void:
	blocks.append(_new_block(kind))
	_select(blocks.size() - 1)

func _select(index: int) -> void:
	selected = index
	_refresh()

func _refresh() -> void:
	var restore_focus := graph.is_ancestor_of(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner() != null else false
	for button in block_buttons:
		graph.remove_child(button)
		button.queue_free()
	block_buttons.clear()
	for i in range(blocks.size()):
		var button := Button.new()
		button.name = "Block_%d" % i
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", MenuStyle.panel(Color(1, 1, 1, .16), BLUE, 0, 2))
		button.add_theme_stylebox_override("pressed", MenuStyle.panel(Color(1, 1, 1, .25), BLUE, 0, 2))
		button.add_theme_stylebox_override("focus", MenuStyle.focus_ring(2))
		button.pressed.connect(_select.bind(i))
		graph.add_child(button)
		block_buttons.append(button)
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if selected >= 0 and selected < blocks.size(): _build_inspector()
	else: inspector.add_child(_label("Voeg links een bouwsteen toe.", 16))
	_update_timeline()
	if restore_focus and selected >= 0: block_buttons[selected].grab_focus.call_deferred()

func _update_timeline() -> void:
	var total := 0.0
	for block in blocks: total += _duration(block)
	summary.text = "%d blokken  ·  %s totaal" % [blocks.size(), _clock(total)]
	action_buttons[0].disabled = selected <= 0
	action_buttons[1].disabled = selected < 0 or selected >= blocks.size() - 1
	for i in [2, 3]: action_buttons[i].disabled = selected < 0
	var width := 0.0
	for block in blocks: width += maxf(72.0, 600.0 * _duration(block) / maxf(total, 1.0))
	graph.custom_minimum_size.x = width
	_layout_blocks()

func _block_widths() -> Array[float]:
	var total := 0.0
	for block in blocks: total += _duration(block)
	var widths: Array[float] = []
	var used := 0.0
	for block in blocks:
		var width := maxf(72.0, 600.0 * _duration(block) / maxf(total, 1.0))
		widths.append(width)
		used += width
	for i in range(widths.size()): widths[i] *= graph.size.x / maxf(used, 1.0)
	return widths

func _layout_blocks() -> void:
	var x := 0.0
	var widths := _block_widths()
	for i in range(block_buttons.size()):
		block_buttons[i].position = Vector2(x, 0)
		block_buttons[i].size = Vector2(widths[i], graph.size.y)
		block_buttons[i].tooltip_text = "%d · %s · %s" % [i + 1, _display(blocks[i].kind), _clock(_duration(blocks[i]))]
		x += widths[i]
	graph.queue_redraw()

func _duration(block: Dictionary) -> float:
	if block.kind == "IntervalsT":
		return float(block.repeat) * (float(block.on_duration) + float(block.off_duration))
	return float(block.duration)

func _clock(seconds: float) -> String:
	var t := roundi(seconds)
	return "%d:%02d" % [t / 60, t % 60]

func _spin(parent: Node, caption: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
	parent.add_child(_label(caption, 16))
	var s := SpinBox.new()
	s.min_value = minimum
	s.max_value = maximum
	s.step = step
	s.value = value
	s.value_changed.connect(callback)
	parent.add_child(s)
	return s

func _build_inspector() -> void:
	var block := blocks[selected]
	inspector.add_child(_label(_display(block.kind), 20))
	if block.kind == "IntervalsT":
		_spin(inspector, "Herhalingen", block.repeat, 1, 100, 1, func(v): _set_block_value("repeat", int(v)))
		for key in ["on_duration", "off_duration"]:
			_spin(inspector, ("Inspanning" if key == "on_duration" else "Herstel") + " (seconden)", block[key], 1, 3600, 1, func(v): _set_block_value(key, v))
		for key in ["on_power", "off_power"]:
			_spin(inspector, ("Inspanning" if key == "on_power" else "Herstel") + " (% FTP)", float(block[key]) * 100, 0, 300, 1, func(v): _set_block_value(key, v / 100.0))
	else:
		_spin(inspector, "Duur (seconden)", block.duration, 1, 86400, 1, func(v): _set_block_value("duration", v))
		if block.kind != "FreeRide":
			_spin(inspector, "Startvermogen (% FTP)", float(block.power_low) * 100, 0, 300, 1, func(v): _set_block_value("power_low", v / 100.0))
			if block.kind in ["Warmup", "Cooldown", "Ramp"]:
				_spin(inspector, "Eindvermogen (% FTP)", float(block.power_high) * 100, 0, 300, 1, func(v): _set_block_value("power_high", v / 100.0))
	inspector.add_child(_label("Tekstbericht", 18))
	message_edit = LineEdit.new()
	message_edit.placeholder_text = "Instructie voor de renner"
	if not block.events.is_empty(): message_edit.text = str(block.events[0].message)
	inspector.add_child(message_edit)
	offset_spin = _spin(inspector, "Na seconden", float(block.events[0].time) if not block.events.is_empty() else 0.0, 0, _duration(block), 1, func(_v): pass)
	_button(inspector, "Bericht bewaren", _save_message)

func _set_block_value(key: String, value: Variant) -> void:
	if selected < 0: return
	blocks[selected][key] = value
	# Keep focus and pending instruction text while refreshing the chart.
	_update_timeline()
	if is_instance_valid(offset_spin): offset_spin.max_value = _duration(blocks[selected])

func _save_message() -> void:
	if selected < 0: return
	var message := message_edit.text.strip_edges()
	blocks[selected].events = [] if message.is_empty() else [{"time":offset_spin.value, "message":message}]
	_refresh()

func _move(direction: int) -> void:
	var target := selected + direction
	if selected < 0 or target < 0 or target >= blocks.size(): return
	var item := blocks[selected]
	blocks.remove_at(selected)
	blocks.insert(target, item)
	_select(target)

func _duplicate() -> void:
	if selected < 0: return
	blocks.insert(selected + 1, blocks[selected].duplicate(true))
	_select(selected + 1)

func _remove() -> void:
	if selected < 0: return
	blocks.remove_at(selected)
	_select(mini(selected, blocks.size() - 1))

func _draw_graph() -> void:
	var h := graph.size.y - 54.0
	var widths := _block_widths()
	var peak := 1.5
	for block in blocks:
		peak = maxf(peak, maxf(float(block.get("on_power", 0)), maxf(float(block.power_low), float(block.power_high))))
	for level in [0.5, 1.0, 1.5]:
		var y: float = h - float(level) / peak * (h - 28)
		graph.draw_line(Vector2(0, y), Vector2(graph.size.x, y), MenuStyle.LINE, 1)
	var x := 0.0
	var font := get_theme_default_font()
	for i in range(blocks.size()):
		var block := blocks[i]
		var width := widths[i]
		var low := float(block.power_low)
		var high := float(block.power_high) if block.kind in ["Warmup", "Cooldown", "Ramp"] else low
		var color := Color("54b87a") if block.kind == "Warmup" else Color("439ee9")
		if block.kind == "Recovery": color = Color("9aaab9")
		if block.kind == "Cooldown": color = Color("56b7e8")
		if block.kind == "FreeRide": color = Color("bc8a43"); low = .45; high = .45
		if block.kind == "IntervalsT":
			color = Color("e5767b")
			var duration := _duration(block)
			var cursor := x
			for rep in range(int(block.repeat)):
				for pair in [[block.on_duration, block.on_power], [block.off_duration, block.off_power]]:
					var part := width * float(pair[0]) / duration
					var height := float(pair[1]) / peak * (h - 28)
					graph.draw_rect(Rect2(cursor, h - height, part, height), color)
					cursor += part
		else:
			graph.draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x, h - low / peak * (h - 28)), Vector2(x + width, h - high / peak * (h - 28)), Vector2(x + width, h)]), color)
		graph.draw_line(Vector2(x, 0), Vector2(x, graph.size.y), MenuStyle.LINE, 1)
		if i == selected: graph.draw_rect(Rect2(x + 2, 2, width - 4, graph.size.y - 4), BLUE, false, 3)
		graph.draw_string(font, Vector2(x + 8, h + 22), "%d · %s" % [i + 1, _display(block.kind)], HORIZONTAL_ALIGNMENT_LEFT, width - 16, 14, MenuStyle.INK)
		graph.draw_string(font, Vector2(x + 8, h + 42), _clock(_duration(block)), HORIZONTAL_ALIGNMENT_LEFT, width - 16, 14, MenuStyle.MUTED)
		x += width
	if blocks.is_empty(): graph.draw_string(font, Vector2(20, 60), "Voeg links een bouwsteen toe.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MenuStyle.MUTED)

func _dialog(mode: FileDialog.FileMode) -> FileDialog:
	var d := FileDialog.new()
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.file_mode = mode
	d.title = "Importeer workout" if mode == FileDialog.FILE_MODE_OPEN_FILE else "Exporteer workout"
	d.get_ok_button().text = "Importeren" if mode == FileDialog.FILE_MODE_OPEN_FILE else "Exporteren"
	d.get_cancel_button().text = "Annuleren"
	MenuStyle.primary(d.get_ok_button())
	d.add_filter("*.zwo", "Zwift Workout")
	add_child(d)
	return d

func _open() -> void:
	open_dialog.popup_centered_ratio(0.75)

func _export() -> void:
	save_dialog.popup_centered_ratio(0.75)

func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status.text = "Openen mislukt"
		return
	var workout := Workout.new()
	if not workout.parse(file.get_as_text()):
		status.text = workout.error
		return
	current_id = ""
	name_edit.text = workout.name
	blocks = workout.blocks.duplicate(true)
	_select(0)
	refresh_workout_choices()
	status.text = "ZWO geïmporteerd"

func _escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;")

func _save_file(path: String) -> void:
	if not path.to_lower().ends_with(".zwo"): path += ".zwo"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Opslaan mislukt"
		return
	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line("<workout_file><author>Velodrome</author><name>%s</name><description></description><sportType>bike</sportType><workout>" % _escape(name_edit.text))
	for block in blocks:
		var kind := str(block.kind)
		if kind == "Recovery": kind = "SteadyState"
		var attrs := ""
		if kind == "IntervalsT":
			attrs = ' Repeat="%d" OnDuration="%s" OffDuration="%s" OnPower="%s" OffPower="%s"' % [block.repeat, block.on_duration, block.off_duration, block.on_power, block.off_power]
		elif kind in ["Warmup", "Cooldown", "Ramp"]:
			attrs = ' Duration="%s" PowerLow="%s" PowerHigh="%s"' % [block.duration, block.power_low, block.power_high]
		elif kind == "FreeRide":
			attrs = ' Duration="%s"' % block.duration
		else:
			attrs = ' Duration="%s" Power="%s"' % [block.duration, block.power_low]
		file.store_line("<%s%s>" % [kind, attrs])
		for event in block.events:
			file.store_line('<textevent timeoffset="%s" message="%s"/>' % [event.time, _escape(str(event.message))])
		file.store_line("</%s>" % kind)
	file.store_line("</workout></workout_file>")
	file.close()
	save_workout()
	if not current_id.is_empty(): status.text = "Opgeslagen: " + path.get_file()
