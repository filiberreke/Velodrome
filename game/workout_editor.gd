extends VBoxContainer
## Standalone ZWO workout editor, embedded in the training menu.
signal back_requested
const Workout := preload("res://zwo_workout.gd")
const BG := Color("#102538")
const PANEL := Color("#1a3449")
const BLUE := Color("#43a5ed")
var blocks: Array[Dictionary] = []
var selected := -1
var name_edit: LineEdit
var list_box: VBoxContainer
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

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	name_edit = LineEdit.new()
	name_edit.text = "Nieuwe training"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(name_edit)
	_button(toolbar, "Openen (.zwo)", _open)
	_button(toolbar, "Exporteren (.zwo)", _export)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	var library := _panel(columns, 235)
	library.add_child(_label("BOUWSTENEN", 23))
	for kind in ["Warmup", "SteadyState", "Recovery", "IntervalsT", "FreeRide", "Cooldown"]:
		_button(library, _display(kind) + "  +", func(): _add(kind))
	var middle := _panel(columns, 660)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_label("WORKOUT", 23))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	var controls := HBoxContainer.new()
	middle.add_child(controls)
	_button(controls, "Omhoog", func(): _move(-1))
	_button(controls, "Omlaag", func(): _move(1))
	_button(controls, "Dupliceren", _duplicate)
	_button(controls, "Verwijderen", _remove)
	graph = Control.new()
	graph.custom_minimum_size.y = 200
	graph.draw.connect(_draw_graph)
	middle.add_child(graph)
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
	_button(footer, "Terug", func(): back_requested.emit())
	_button(footer, "Exporteren", _export)
	open_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE)
	save_dialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE)
	open_dialog.file_selected.connect(_load_file)
	save_dialog.file_selected.connect(_save_file)
	_add("Warmup")
	_add("SteadyState")
	_add("Recovery")
	_add("Cooldown")
	_select(0)

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
	l.add_theme_color_override("font_color", Color.WHITE)
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
	for child in list_box.get_children(): child.queue_free()
	var total := 0.0
	for i in range(blocks.size()):
		var block := blocks[i]
		var duration := _duration(block)
		total += duration
		var text := "%02d  %s   %s   %d%% FTP" % [i + 1, _display(block.kind), _clock(duration), roundi(float(block.power_low) * 100)]
		var b := _button(list_box, text, func(): _select(i))
		if i == selected: b.add_theme_color_override("font_color", BLUE)
	for child in inspector.get_children(): child.queue_free()
	if selected >= 0 and selected < blocks.size(): _build_inspector()
	summary.text = "%d blokken  ·  %s totaal" % [blocks.size(), _clock(total)]
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
		_spin(inspector, "Herhalingen", block.repeat, 1, 100, 1, func(v): _set("repeat", int(v)))
		for key in ["on_duration", "off_duration"]:
			_spin(inspector, key + " (seconden)", block[key], 1, 3600, 5, func(v): _set(key, v))
		for key in ["on_power", "off_power"]:
			_spin(inspector, key + " (% FTP)", float(block[key]) * 100, 0, 300, 1, func(v): _set(key, v / 100.0))
	else:
		_spin(inspector, "Duur (seconden)", block.duration, 1, 86400, 5, func(v): _set("duration", v))
		if block.kind != "FreeRide":
			_spin(inspector, "Startvermogen (% FTP)", float(block.power_low) * 100, 0, 300, 1, func(v): _set("power_low", v / 100.0))
			if block.kind in ["Warmup", "Cooldown", "Ramp"]:
				_spin(inspector, "Eindvermogen (% FTP)", float(block.power_high) * 100, 0, 300, 1, func(v): _set("power_high", v / 100.0))
	inspector.add_child(_label("Tekstbericht", 18))
	message_edit = LineEdit.new()
	message_edit.placeholder_text = "Instructie voor de renner"
	if not block.events.is_empty(): message_edit.text = str(block.events[0].message)
	inspector.add_child(message_edit)
	offset_spin = _spin(inspector, "Na seconden", float(block.events[0].time) if not block.events.is_empty() else 0.0, 0, _duration(block), 1, func(_v): pass)
	_button(inspector, "Bericht bewaren", _save_message)

func _set(key: String, value: Variant) -> void:
	if selected < 0: return
	blocks[selected][key] = value
	# Preserve inspector focus while updating the graph and list on commit.
	_refresh.call_deferred()

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
	var total := 0.0
	for block in blocks: total += _duration(block)
	if total <= 0: return
	var x := 0.0
	var w := graph.size.x
	var h := graph.size.y
	graph.draw_line(Vector2(0, h - 4), Vector2(w, h - 4), Color("#8fa5b6"), 1)
	for i in range(blocks.size()):
		var block := blocks[i]
		var width := w * _duration(block) / total
		var low := clampf(float(block.power_low) / 1.5, 0.0, 1.0)
		var high := clampf(float(block.power_high) / 1.5, 0.0, 1.0)
		var color := Color("#54c96e") if block.kind == "Warmup" else Color("#439ee9")
		if block.kind == "Recovery": color = Color("#9aaab9")
		if block.kind == "Cooldown": color = Color("#56b7e8")
		if block.kind == "IntervalsT": color = Color("#e5767b")
		var points := PackedVector2Array([Vector2(x, h - 4), Vector2(x, h - 4 - low * (h - 20)), Vector2(x + width, h - 4 - high * (h - 20)), Vector2(x + width, h - 4)])
		graph.draw_colored_polygon(points, color)
		if i == selected: graph.draw_rect(Rect2(x, 0, width, h), Color.WHITE, false, 2)
		x += width

func _dialog(mode: FileDialog.FileMode) -> FileDialog:
	var d := FileDialog.new()
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.file_mode = mode
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
	name_edit.text = workout.name
	blocks = workout.blocks.duplicate(true)
	_select(0)
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
			attrs = ' Repeat="%d" OnDuration="%g" OffDuration="%g" OnPower="%g" OffPower="%g"' % [block.repeat, block.on_duration, block.off_duration, block.on_power, block.off_power]
		elif kind in ["Warmup", "Cooldown", "Ramp"]:
			attrs = ' Duration="%g" PowerLow="%g" PowerHigh="%g"' % [block.duration, block.power_low, block.power_high]
		elif kind == "FreeRide":
			attrs = ' Duration="%g"' % block.duration
		else:
			attrs = ' Duration="%g" Power="%g"' % [block.duration, block.power_low]
		file.store_line("<%s%s>" % [kind, attrs])
		for event in block.events:
			file.store_line('<textevent timeoffset="%g" message="%s"/>' % [event.time, _escape(str(event.message))])
		file.store_line("</%s>" % kind)
	file.store_line("</workout></workout_file>")
	file.close()
	status.text = "Opgeslagen: " + path.get_file()
