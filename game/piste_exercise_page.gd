extends "res://derny_training.gd"
const Exercise := preload("res://piste_exercise_session.gd")
var kind := "flying_start"
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
	title = _label("Vliegende start",34)
	detail = _label("",22)
	tempo_row = HBoxContainer.new(); add_child(tempo_row)
	tempo_input = _option(tempo_row,"Constant pelotontempo",15,60,1,30,"km/u")
	limit_row = HBoxContainer.new(); add_child(limit_row)
	limit_input = _option(limit_row,"Tijdslimiet",1,30,1,10,"min")
	result = _label("",24)
	start_button = _button("Start training",begin)
	results_row = HBoxContainer.new(); results_row.size_flags_vertical = Control.SIZE_EXPAND_FILL; results_row.add_theme_constant_override("separation",16); add_child(results_row)
	records_table = preload("res://flying_start_table.gd").new(); records_table.store = records_store; records_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL; results_row.add_child(records_table)
	result_graph = preload("res://training_graph.gd").new()
	result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_row.add_child(result_graph)
	upload_button = _button("Opslaan op Strava",func(): upload_requested.emit(selected_activity))
	stop_button = _button("Stop training",func(): finish("Handmatig gestopt"))
	back_button = _button("← Pistetraining",leave)
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
		detail.text = "Rijd vrij op de piste, zolang je wilt. Tijd, afstand en iedere rondetijd worden bijgehouden.\nVier onafhankelijke pacers rijden op 30, 35, 40 en 45 km/u, met blauwe, groene, oranje en rode truien. Sluit aan in hun slipstream wanneer je wilt.\nLinks/rechts of de paddles: rijlijn. Camera's en achteruitkijken werken zoals in wedstrijden."
	elif kind == "flying_start":
		detail.text = "Eén voorbereidingsronde vanaf de rode achtervolgingslijn. Iedere poging begint op 30 km/u onderaan de piste. Gebruik de hoogte en kies wanneer je afdaalt.\nVergelijk je snelheid op de lijn met je gemiddelde en maximale vermogen. De beste voltooide pogingen staan hieronder, gesorteerd op hoogste snelheid."
	else:
		detail.text = "Een compact peloton van acht renners houdt een constant groepstempo, met wisselende koprijders in twee tot drie rijen. Je begint drie meter achteraan op dezelfde snelheid.\nVal aan, win een volledige ronde en sluit opnieuw aan achter het peloton. Je rijdt vrij tussen de renners, zoals in scratch. In het wiel krijg je maximaal 50% beschutting.\nLinks/rechts of de stuurpaddles kiezen je rijlijn. Je bepaalt zelf het moment van je aanval."
	if kind == "flying_start": records_table.refresh()
	_refresh()
func _refresh() -> void:
	if start_button == null: return
	var running: bool = session.running()
	var has_result := not selected_activity.is_empty()
	start_button.visible = not running; stop_button.hide()
	start_button.text = "Opnieuw proberen" if has_result else "Start training"
	detail.visible = not running and not has_result
	records_table.visible = not running and kind == "flying_start"
	results_row.visible = not running and (has_result or kind == "flying_start")
	tempo_row.visible = not running and kind == "take_lap"
	limit_row.visible = not running and kind == "take_lap"
	result_graph.visible = has_result; upload_button.visible = has_result
	upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		var duration: float = selected_activity.get("duration_s",0)
		result.text = "%s · %d:%02d\n" % [selected_activity.get("reason","Tussentijds bewaard"),int(duration)/60,int(duration)%60]
		if kind == "flying_start":
			result.text += "Snelheid op de lijn: %.2f km/u\nGemiddeld vermogen: %.0f W · maximaal vermogen: %.0f W\n" % [selected_activity.get("entry_speed_kmh",0),selected_activity.get("mean_power_w",0),selected_activity.get("peak_power_w",0)] if selected_activity.get("exercise_success",false) else "Geen voltooide passage op de startlijn.\n"
		elif kind == "free_ride":
			result.text += "Afstand: %.3f km · %d voltooide rondes\nGemiddeld vermogen: %.0f W · maximaal vermogen: %.0f W\n" % [float(selected_activity.get("distance_m",0))/1000,selected_activity.get("laps",[]).size(),selected_activity.get("mean_power_w",0),selected_activity.get("peak_power_w",0)]
		else: result.text += "Peloton %.0f km/u · %.1f / 250 m gewonnen\nPiekvermogen %.0f W · gemiddeld %.0f W\n" % [selected_activity.get("peloton_kmh",30),selected_activity.get("gained_m",0),selected_activity.get("peak_power_w",0),selected_activity.get("mean_power_w",0)]
		result.text += upload_status
		if selected_activity.get("demo",false): result.text += "\nPC-proefrit · gesimuleerde activiteit"
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "Iedere training wordt lokaal bewaard. Na afloop kun je naar Strava uploaden."

func show_activity(activity: Dictionary, message: String = "Training opgeslagen in het spel.") -> void:
	super.show_activity(activity,message)
	if kind == "flying_start": records_table.refresh()
