extends VBoxContainer
signal back_requested
signal environment_requested(active: bool)
signal upload_requested(activity: Dictionary)
const Session := preload("res://derny_session.gd")
var session = Session.new()
var scene: Node3D
var title: Label
var detail: Label
var result: Label
var start_button: Button
var stop_button: Button
var back_button: Button
var upload_button: Button
var result_graph: Control
var selected_activity := {}
var upload_status := ""
var start_speed: SpinBox
var start_speed_row: HBoxContainer
var motor_picker: VBoxContainer
var derny_motor_button: Button
var heavy_motor_button: Button
func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	title = _label("Dernytraining", 34)
	detail = _label("Kies je startsnelheid. Tijdens de aanloopronde word je automatisch meegenomen. De gekozen snelheid is een rondegemiddelde, elke minuut +1 km/u.\nDe derny rijdt met vast vermogen: trager bergop, sneller bergaf. Hij begint onderaan en gaat bij elke extra 5 km/u één rijlijn hoger. Jij volgt automatisch.\nIn het wiel remt het spel onbedoeld inhalen af; stuur bewust twee rijlijnen opzij om te passeren.\nTempo vragen: → sneller (+1 km/u), ← trager (−1 km/u), op trainer en simulator. Zodra je sneller of trager vraagt, stopt het automatisch versnellen en bepaal je zelf het tempo voor de rest van de training.\nMeer dan 15 meter achterstand gedurende 5 seconden beëindigt de training.\nElke training wordt lokaal bewaard. Na afloop kun je naar Strava uploaden.",22)
	motor_picker = VBoxContainer.new()
	motor_picker.add_theme_constant_override("separation", 10)
	add_child(motor_picker)
	var motor_caption := Label.new()
	motor_caption.text = "Motor"
	motor_picker.add_child(motor_caption)
	var motor_row := HBoxContainer.new()
	motor_row.add_theme_constant_override("separation", 14)
	motor_picker.add_child(motor_row)
	derny_motor_button = Button.new()
	derny_motor_button.toggle_mode = true
	derny_motor_button.button_group = ButtonGroup.new()
	derny_motor_button.button_pressed = true
	derny_motor_button.custom_minimum_size = Vector2(270, 250)
	motor_row.add_child(derny_motor_button)
	var derny_art := TextureRect.new()
	derny_art.texture = preload("res://motor_choice_art.gd").derny(self)
	derny_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	derny_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_motor_tile(derny_motor_button, "Derny", derny_art, "Tot 60% aerovoordeel\n0–65 km/u", true)
	derny_motor_button.tooltip_text = "Geselecteerde gangmaker. Tot 60% aerovoordeel in het wiel, afhankelijk van afstand en zijwaartse positie."
	heavy_motor_button = Button.new()
	heavy_motor_button.disabled = true
	heavy_motor_button.tooltip_text = "Nog niet beschikbaar. Deze motor zal meer aerodynamische beschutting bieden dan de huidige derny."
	heavy_motor_button.custom_minimum_size = Vector2(270, 250)
	motor_row.add_child(heavy_motor_button)
	_motor_tile(heavy_motor_button, "Zware motor", preload("res://motor_choice_art.gd").Heavy.new(), "Meer aerovoordeel\nBinnenkort", false)
	start_speed_row = HBoxContainer.new()
	start_speed_row.add_theme_constant_override("separation",16)
	add_child(start_speed_row)
	var speed_label := Label.new()
	speed_label.text = "Startsnelheid (rondegemiddelde)"
	speed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_speed_row.add_child(speed_label)
	start_speed = SpinBox.new()
	start_speed.min_value = Session.MIN_START_KMH
	start_speed.max_value = Session.MAX_START_KMH
	start_speed.step = 1
	start_speed.value = Session.DEFAULT_START_KMH
	start_speed.suffix = "km/u"
	start_speed.custom_minimum_size.x = 180
	start_speed_row.add_child(start_speed)
	result = _label("", 24)
	start_button = _button("Start dernytraining", begin)
	result_graph = preload("res://training_graph.gd").new()
	result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(result_graph)
	upload_button = _button("Opslaan op Strava",func(): upload_requested.emit(selected_activity))
	stop_button = _button("Stop training", func(): finish("Handmatig gestopt"))
	back_button = _button("← Pistetraining", leave)
	_refresh()
func _label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	add_child(node)
	return node
func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.pressed.connect(action)
	add_child(node)
	return node

func _motor_tile(button: Button, caption: String, artwork: Control, stats: String, selected: bool) -> void:
	var style := preload("res://menu_theme.gd")
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style.panel(style.PALE if selected else style.IVORY, style.BLUE if selected else style.LINE, 12, 10))
	button.add_theme_stylebox_override("focus", style.focus_ring(10))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14; content.offset_right = -14; content.offset_top = 12; content.offset_bottom = -12
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	button.add_child(content)
	var heading := Label.new()
	heading.text = caption
	heading.add_theme_font_override("font", style.heading())
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", style.BLUE if selected else style.MUTED)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(heading)
	artwork.custom_minimum_size.y = 120
	artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(artwork)
	var description := Label.new()
	description.text = stats
	description.add_theme_font_size_override("font_size", 18)
	description.add_theme_color_override("font_color", style.INK if selected else style.MUTED)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)
func begin() -> void:
	if session.running(): return
	selected_activity = {}
	upload_status = ""
	environment_requested.emit(true)
	if session.running() and is_instance_valid(scene): scene.hud.stop_button.grab_focus()
func finish(reason: String) -> void:
	if is_instance_valid(scene) and scene.active: scene.finish_session(reason)
	else: session.stop(reason)
	_refresh()
func leave() -> void:
	if session.running(): finish("Training verlaten")
	environment_requested.emit(false)
	back_requested.emit()
func show_activity(activity: Dictionary, message: String = "Training opgeslagen in het spel.") -> void:
	selected_activity = activity
	upload_status = message
	result_graph.set_samples(activity.get("samples",[]))
	_refresh()
func _process(_dt: float) -> void: _refresh()
func _refresh() -> void:
	if start_button == null: return
	var running := session.running()
	var has_result := not selected_activity.is_empty()
	start_speed_row.get_child(0).text = "Startsnelheid volgende training" if has_result else "Startsnelheid (rondegemiddelde)"
	start_speed_row.visible = not running
	start_speed.editable = not running
	start_button.visible = not running
	stop_button.hide()
	detail.visible = not running and not has_result
	result_graph.visible = has_result
	upload_button.visible = has_result
	upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		var duration: int = int(selected_activity.get("duration_s",0))
		result.text = "%s · %d:%02d · %.2f km\nStartsnelheid: %d km/u · hoogste voltooide stap: %d km/u\n%s" % [selected_activity.get("reason","") if not str(selected_activity.get("reason","")).is_empty() else "Tussentijds bewaarde training",duration/60,duration%60,float(selected_activity.get("distance_m",0))/1000,int(selected_activity.get("start_speed_kmh",Session.DEFAULT_START_KMH)),int(selected_activity.get("completed_kmh",0)),upload_status]
		if selected_activity.get("demo",false): result.text += "\nPC-proefrit · gesimuleerde activiteit"
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "Zonder trainer kun je een PC-proefrit maken."
