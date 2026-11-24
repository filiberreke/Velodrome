extends "res://pursuit_options.gd"
var teammates: OptionButton
var resistance_choice: OptionButton
var resistance_hint: Label
var factor_inputs: Array[SpinBox] = []

func _ready() -> void:
	library.configure_team(3)
	super._ready()
	var title := _label("AI-ploegmaats")
	add_child(title); move_child(title, 0)
	teammates = _choice()
	teammates.add_item("PURSUIT_2_TEAMMATES_3_RIDERS", 3)
	teammates.add_item("PURSUIT_3_TEAMMATES_4_RIDERS", 4)
	add_child(teammates); move_child(teammates, 1)
	teammates.item_selected.connect(func(_index: int) -> void:
		library.configure_team(team_size())
		refresh_rides())
	opponent_choice.set_item_text(0, "AI-ploeg")
	opponent_choice.set_item_text(1, String(TranslationServer.translate("PURSUIT_A_PREVIOUS_TEAM_PERFORMANCE")))
	cp_box.get_child(2).text = "PURSUIT_OPPOSING_TEAM_CP_LEADING_POWER_W"
	var resistance_row := HBoxContainer.new()
	resistance_row.add_theme_constant_override("separation", 12)
	var resistance_title := _label("PURSUIT_RESISTANCE")
	resistance_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resistance_row.add_child(resistance_title)
	resistance_choice = _choice()
	resistance_choice.custom_minimum_size.x = 260
	resistance_choice.add_item("PURSUIT_MANUAL", 0)
	resistance_choice.add_item("ERG", 1)
	resistance_row.add_child(resistance_choice)
	add_child(resistance_row)
	resistance_hint = _label("")
	resistance_hint.add_theme_font_size_override("font_size", 17)
	resistance_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(resistance_hint)
	resistance_choice.item_selected.connect(func(_index: int) -> void:
		_refresh_resistance_hint()
		changed.emit())
	_refresh_resistance_hint()
	add_child(_label("PURSUIT_DRAFTING_POWER_OF_YOUR_LAST_TURN_ON_THE_FRONT"))
	for rank in range(1, 4):
		var line := HBoxContainer.new()
		var rank_label := _label(String(TranslationServer.translate("PURSUIT_POSITION_D")) % (rank + 1))
		rank_label.custom_minimum_size.x = 190
		line.add_child(rank_label)
		var input := SpinBox.new()
		input.min_value = 10.0
		input.max_value = 100.0
		input.step = 5.0
		input.value = [80.0, 50.0, 40.0][rank - 1]
		input.custom_minimum_size = Vector2(130, 44)
		line.add_child(input)
		factor_inputs.append(input)
		add_child(line)
	teammates.item_selected.connect(func(_index: int) -> void: _refresh_factor_inputs())
	_refresh_factor_inputs()

func _refresh_factor_inputs() -> void:
	for i in range(factor_inputs.size()):
		factor_inputs[i].get_parent().visible = i < team_size() - 1
	if team_size() == 3 and factor_inputs.size() >= 2 and is_equal_approx(factor_inputs[1].value, 60.0):
		factor_inputs[1].value = 50.0
	elif team_size() == 4 and factor_inputs.size() >= 2 and is_equal_approx(factor_inputs[1].value, 50.0):
		factor_inputs[1].value = 60.0

func configured_factors() -> Array[float]:
	var result: Array[float] = [1.0]
	for i in range(team_size() - 1):
		result.append(factor_inputs[i].value / 100.0)
	return result

func resistance_mode() -> String:
	return "ERG" if resistance_choice != null and resistance_choice.get_selected_id() == 1 else "MANUAL"

func _refresh_resistance_hint() -> void:
	resistance_hint.text = "PURSUIT_ERG_WHILE_DRAFTING_PEDAL_FREELY_WHILE_LEADING_AND_DROPPING_BACK" if resistance_mode() == "ERG" else "PURSUIT_PEDAL_AT_THE_INDICATED_TARGET_POWER_YOURSELF"


func team_size() -> int:
	return teammates.get_selected_id() if teammates != null else 3

func ai_choice_label() -> String:
	return String(TranslationServer.translate("PURSUIT_CHOOSE_OPPOSING_TEAM_COUNTRY"))

func available_ai_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var appearance = preload("res://player_appearance.gd").new()
	for option in appearance.suit_options:
		if option.id in ["configured", "default"]: continue
		result.append({"country": option.id, "name": option.label})
	return result

func uses_rider_picker() -> bool:
	return false
