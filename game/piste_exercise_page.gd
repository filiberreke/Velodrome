extends "res://derny_training.gd"
const Exercise := preload("res://piste_exercise_session.gd")
var kind := "flying_start"
var omnium_origin := ""
var records_store
var records_table: PanelContainer
var results_row: HBoxContainer
var tempo_row: HBoxContainer
var tempo_input: SpinBox
var limit_row: HBoxContainer
var limit_input: SpinBox
func _ready() -> void:
	session = Exercise.new()
	add_theme_constant_override("separation",14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	title = _label("RACE_MENU_FLYING_START",34)
	detail = _label("",22)
	tempo_row = HBoxContainer.new(); add_child(tempo_row)
	tempo_input = _option(tempo_row,String(TranslationServer.translate("PISTE_EXERCISE_PAGE_CONSTANT_PELOTON_PACE")),15,60,1,30,"km/u")
	limit_row = HBoxContainer.new(); add_child(limit_row)
	limit_input = _option(limit_row,String(TranslationServer.translate("PISTE_EXERCISE_PAGE_TIME_LIMIT")),1,30,1,10,"min")
	result = _label("",24)
	start_button = _button("PISTE_EXERCISE_PAGE_START_TRAINING",begin)
	results_row = HBoxContainer.new(); results_row.size_flags_vertical = Control.SIZE_EXPAND_FILL; results_row.add_theme_constant_override("separation",16); add_child(results_row)
	records_table = preload("res://flying_start_table.gd").new(); records_table.store = records_store; records_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL; results_row.add_child(records_table)
	result_graph = preload("res://training_graph.gd").new()
	result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_row.add_child(result_graph)
	upload_button = _button("PISTE_EXERCISE_PAGE_SAVE_TO_STRAVA",func(): upload_requested.emit(selected_activity))
	stop_button = _button("FTP_RAMP_HUD_STOP_TRAINING",func(): finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY"))))
	back_button = _button("TRAINING_HISTORY_TRACK_TRAINING",leave)
	configure(kind)
func _option(row: HBoxContainer, caption: String, low: float, high: float, step: float, value: float, suffix: String) -> SpinBox:
	row.add_theme_constant_override("separation",16)
	var label := Label.new(); label.text = caption; label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(label)
	var input := SpinBox.new(); input.min_value = low; input.max_value = high; input.step = step; input.value = value; input.suffix = suffix; input.custom_minimum_size.x = 180; row.add_child(input)
	return input
func configure(mode: String) -> void:
	if mode != kind:
		selected_activity = {}; upload_status = ""; session.phase = "IDLE"
	kind = mode
	title.text = Exercise.title(kind)
	if kind == "free_ride":
		detail.text = "TRAINING_RIDE_FREELY_ON_THE_TRACK_FOR_AS_LONG_AS_YOU_LIKE_TIME_DISTANCE_AND_EVE"
	elif kind == "flying_start":
		detail.text = "TRAINING_ONE_PREPARATION_LAP_FROM_THE_RED_PURSUIT_LINE_EACH_ATTEMPT_STARTS_AT_3"
	else:
		detail.text = "TRAINING_A_COMPACT_PELOTON_OF_EIGHT_RIDERS_MAINTAINS_A_CONSTANT_GROUP_PACE_ROTA"
	if kind == "flying_start": records_table.refresh()
	_refresh()
func _refresh() -> void:
	if start_button == null: return
	var running: bool = session.running()
	var has_result := not selected_activity.is_empty()
	start_button.visible = not running; stop_button.hide()
	start_button.text = "PISTE_EXERCISE_PAGE_TRY_AGAIN" if has_result else "PISTE_EXERCISE_PAGE_START_TRAINING"
	detail.visible = not running and not has_result
	records_table.visible = not running and kind == "flying_start"
	results_row.visible = not running and (has_result or kind == "flying_start")
	tempo_row.visible = not running and kind == "take_lap"
	limit_row.visible = not running and kind == "take_lap"
	result_graph.visible = has_result; upload_button.visible = has_result
	upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		var duration: float = selected_activity.get("duration_s",0)
		result.text = "%s · %d:%02d\n" % [selected_activity.get("reason",String(TranslationServer.translate("PISTE_EXERCISE_PAGE_SAVED_BEFORE_COMPLETION"))),int(duration)/60,int(duration)%60]
		if kind == "flying_start":
			result.text += String(TranslationServer.translate("TRAINING_SPEED_AT_THE_LINE_2F_KM_H_AVERAGE_POWER_0F_W_MAXIMUM_POWER_0F_W")) % [selected_activity.get("entry_speed_kmh",0),selected_activity.get("mean_power_w",0),selected_activity.get("peak_power_w",0)] if selected_activity.get("exercise_success",false) else String(TranslationServer.translate("TRAINING_NO_COMPLETED_PASSAGE_ACROSS_THE_START_LINE"))
		elif kind == "free_ride":
			result.text += String(TranslationServer.translate("TRAINING_DISTANCE_3F_KM_D_COMPLETED_LAPS_AVERAGE_POWER_0F_W_MAXIMUM_POWER_0F_W")) % [float(selected_activity.get("distance_m",0))/1000,selected_activity.get("laps",[]).size(),selected_activity.get("mean_power_w",0),selected_activity.get("peak_power_w",0)]
		else:
			var length := preload("res://venues/venue_catalog.gd").lap_length_label(float(selected_activity.get("lap_length_m", 250.0)))
			result.text += String(TranslationServer.translate("TRAINING_PELOTON_0F_KM_H_1F_250_M_GAINED_PEAK_POWER_0F_W_AVERAGE_0F_W")) % [selected_activity.get("peloton_kmh",30),selected_activity.get("gained_m",0),length,selected_activity.get("peak_power_w",0),selected_activity.get("mean_power_w",0)]
		result.text += upload_status
		if selected_activity.get("demo",false): result.text += String(TranslationServer.translate("TRAINING_PC_TEST_RIDE_SIMULATED_ACTIVITY"))
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "PISTE_EXERCISE_PAGE_EVERY_TRAINING_SESSION_IS_SAVED_LOCALLY_YOU_CAN_UPLOAD_TO_STRAVA_AFTER"

func show_activity(activity: Dictionary, message: String = "TRAINING_ACTIVITY_SAVED") -> void:
	super.show_activity(activity,message)
	if kind == "flying_start": records_table.set_venue(String(activity.get("venue_id", "velodrome")))

func set_history_origin(from_history: bool) -> void:
	if from_history: omnium_origin = ""
	super.set_history_origin(from_history)
	if not omnium_origin.is_empty(): back_button.text = "RACE_MENU_OMNIUM"
