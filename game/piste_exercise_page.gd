extends "res://derny_training.gd"
const Exercise := preload("res://piste_exercise_session.gd")
var kind := "flying_start"
var budget_row: HBoxContainer
var budget_input: SpinBox
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
	budget_row = HBoxContainer.new(); add_child(budget_row)
	budget_input = _option(budget_row,"Vermogensplafond voor deze poging",50,2000,10,roundi(preload("res://player_profile.gd").new().ftp()*1.5),"W")
	tempo_row = HBoxContainer.new(); add_child(tempo_row)
	tempo_input = _option(tempo_row,"Constant pelotontempo",15,60,1,30,"km/u")
	limit_row = HBoxContainer.new(); add_child(limit_row)
	limit_input = _option(limit_row,"Tijdslimiet",1,30,1,10,"min")
	result = _label("",24)
	start_button = _button("Start training",begin)
	result_graph = preload("res://training_graph.gd").new()
	result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(result_graph)
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
	detail.text = "Eén voorbereidingsronde vanaf de rode achtervolgingslijn. Iedere poging begint op 30 km/u onderaan de piste. Gebruik de hoogte en kies wanneer je afdaalt.\nDoel: zo snel mogelijk over dezelfde lijn, met zo weinig mogelijk piekvermogen. Het plafond is een vergelijkingsdoel; het begrenst je vermogen niet.\nLinks/rechts of de stuurpaddles kiezen je rijlijn. Camera's en achteruitkijken werken zoals in wedstrijden." if kind == "flying_start" else "Een compact peloton van acht renners houdt een constant groepstempo, met wisselende koprijders in twee tot drie rijen. Je begint drie meter achteraan op dezelfde snelheid.\nVal aan, win een volledige ronde en sluit opnieuw aan achter het peloton. Je rijdt vrij tussen de renners, zoals in scratch. In het wiel krijg je maximaal 50% beschutting.\nLinks/rechts of de stuurpaddles kiezen je rijlijn. Je bepaalt zelf het moment van je aanval."
	_refresh()
func _refresh() -> void:
	if start_button == null: return
	var running: bool = session.running()
	var has_result := not selected_activity.is_empty()
	start_button.visible = not running; stop_button.hide()
	start_button.text = "Opnieuw proberen" if has_result else "Start training"
	detail.visible = not running and not has_result
	budget_row.visible = not running and kind == "flying_start"
	tempo_row.visible = not running and kind == "take_lap"
	limit_row.visible = not running and kind == "take_lap"
	result_graph.visible = has_result; upload_button.visible = has_result
	upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		var duration: float = selected_activity.get("duration_s",0)
		result.text = "%s · %d:%02d\n" % [selected_activity.get("reason","Tussentijds bewaard"),int(duration)/60,int(duration)%60]
		if kind == "flying_start":
			result.text += "Snelheid op de lijn: %.2f km/u\nPiekvermogen: %.0f W · gemiddeld %.0f W · plafond %.0f W%s\n" % [selected_activity.get("entry_speed_kmh",0),selected_activity.get("peak_power_w",0),selected_activity.get("mean_power_w",0),selected_activity.get("power_budget_w",0)," · overschreden" if not selected_activity.get("within_budget",true) else " · gehaald"] if selected_activity.get("exercise_success",false) else "Geen voltooide passage op de startlijn.\n"
		else: result.text += "Peloton %.0f km/u · %.1f / 250 m gewonnen\nPiekvermogen %.0f W · gemiddeld %.0f W\n" % [selected_activity.get("peloton_kmh",30),selected_activity.get("gained_m",0),selected_activity.get("peak_power_w",0),selected_activity.get("mean_power_w",0)]
		result.text += upload_status
		if selected_activity.get("demo",false): result.text += "\nPC-proefrit · gesimuleerde activiteit"
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "Iedere training wordt lokaal bewaard. Na afloop kun je naar Strava uploaden."
