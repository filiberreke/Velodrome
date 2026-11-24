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
var return_to_history := false
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
	title = _label("TRAINING_HISTORY_DERNY_TRAINING", 34)
	detail = _label("DERNY_CHOOSE_YOUR_STARTING_SPEED_YOU_ARE_AUTOMATICALLY_PACED_DURING_THE_LEAD",22)
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
	_motor_tile(derny_motor_button, "Derny", derny_art, String(TranslationServer.translate("DERNY_UP_TO_60_AERODYNAMIC_BENEFIT_0_65_KM_H")), true)
	derny_motor_button.tooltip_text = "DERNY_SELECTED_PACER_UP_TO_60_AERODYNAMIC_BENEFIT_WHILE_DRAFTING_DEPENDING_O"
	heavy_motor_button = Button.new()
	heavy_motor_button.disabled = true
	heavy_motor_button.tooltip_text = "DERNY_NOT_YET_AVAILABLE_THIS_MOTORBIKE_WILL_OFFER_MORE_AERODYNAMIC_SHELTER_T"
	heavy_motor_button.custom_minimum_size = Vector2(270, 250)
	motor_row.add_child(heavy_motor_button)
	_motor_tile(heavy_motor_button, String(TranslationServer.translate("DERNY_HEAVY_MOTORBIKE")), preload("res://motor_choice_art.gd").Heavy.new(), String(TranslationServer.translate("DERNY_MORE_AERODYNAMIC_BENEFIT_COMING_SOON")), false)
	start_speed_row = HBoxContainer.new()
	start_speed_row.add_theme_constant_override("separation",16)
	add_child(start_speed_row)
	var speed_label := Label.new()
	speed_label.text = "DERNY_START_SPEED_AVERAGE"
	speed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_speed_row.add_child(speed_label)
	start_speed = SpinBox.new()
	start_speed.min_value = Session.MIN_START_KMH
	start_speed.max_value = Session.MAX_START_KMH
	start_speed.step = 1
	start_speed.value = Session.DEFAULT_START_KMH
	start_speed.suffix = String(TranslationServer.translate("COMMON_SPEED_UNIT"))
	start_speed.custom_minimum_size.x = 180
	start_speed_row.add_child(start_speed)
	result = _label("", 24)
	start_button = _button("DERNY_START_DERNY_TRAINING", begin)
	result_graph = preload("res://training_graph.gd").new()
	result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(result_graph)
	upload_button = _button("PISTE_EXERCISE_PAGE_SAVE_TO_STRAVA",func(): upload_requested.emit(selected_activity))
	stop_button = _button("FTP_RAMP_HUD_STOP_TRAINING", func(): finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY"))))
	back_button = _button("TRAINING_HISTORY_TRACK_TRAINING", leave)
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
	prepare_new_training()
	environment_requested.emit(true)
	if session.running() and is_instance_valid(scene): scene.hud.stop_button.grab_focus()

func prepare_new_training() -> void:
	if session.running(): return
	set_history_origin(false)
	selected_activity = {}
	upload_status = ""
	session.phase = "IDLE"
	result_graph.set_samples([])
	_refresh()
func finish(reason: String) -> void:
	if is_instance_valid(scene) and scene.active: scene.finish_session(reason)
	else: session.stop(reason)
	_refresh()
func set_history_origin(from_history: bool) -> void:
	return_to_history = from_history
	back_button.text = "DERNY_SAVED_TRAINING_SESSIONS" if from_history else "TRAINING_HISTORY_TRACK_TRAINING"

func leave() -> void:
	if session.running(): finish(String(TranslationServer.translate("MAIN_LEAVE_TRAINING")))
	environment_requested.emit(false)
	back_requested.emit()
func show_activity(activity: Dictionary, message: String = "TRAINING_ACTIVITY_SAVED") -> void:
	selected_activity = activity
	upload_status = String(tr(message))
	result_graph.set_samples(activity.get("samples",[]))
	_refresh()
func _process(_dt: float) -> void: _refresh()
func _refresh() -> void:
	if start_button == null: return
	var running := session.running()
	var has_result := not selected_activity.is_empty()
	start_speed_row.get_child(0).text = String(TranslationServer.translate("DERNY_STARTING_SPEED_FOR_NEXT_SESSION")) if has_result else String(TranslationServer.translate("DERNY_START_SPEED_AVERAGE"))
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
		result.text = String(TranslationServer.translate("DERNY_S_D_02D_2F_KM_STARTING_SPEED_D_KM_H_HIGHEST_COMPLETED_STEP_D_KM_H_S")) % [selected_activity.get("reason","") if not str(selected_activity.get("reason","")).is_empty() else String(TranslationServer.translate("DERNY_TRAINING_SAVED_BEFORE_COMPLETION")),duration/60,duration%60,float(selected_activity.get("distance_m",0))/1000,int(selected_activity.get("start_speed_kmh",Session.DEFAULT_START_KMH)),int(selected_activity.get("completed_kmh",0)),upload_status]
		if selected_activity.get("demo",false): result.text += String(TranslationServer.translate("TRAINING_PC_TEST_RIDE_SIMULATED_ACTIVITY"))
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "DERNY_YOU_CAN_DO_A_PC_TEST_RIDE_WITHOUT_A_TRAINER"
