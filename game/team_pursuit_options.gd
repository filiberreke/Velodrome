extends "res://pursuit_options.gd"
var teammates: OptionButton
var resistance_choice: OptionButton
var resistance_hint: Label

func _ready() -> void:
	library.configure_team(3)
	super._ready()
	var title := _label("AI-ploegmaats")
	add_child(title); move_child(title, 0)
	teammates = _choice()
	teammates.add_item("2 ploegmaats · 3 renners", 3)
	teammates.add_item("3 ploegmaats · 4 renners", 4)
	add_child(teammates); move_child(teammates, 1)
	teammates.item_selected.connect(func(_index: int) -> void:
		library.configure_team(team_size())
		refresh_rides())
	opponent_choice.set_item_text(0, "AI-ploeg")
	opponent_choice.set_item_text(1, "Een vorige ploegprestatie")
	cp_box.get_child(0).text = "CP tegenploeg · kopvermogen (W)"
	var resistance_row := HBoxContainer.new()
	resistance_row.add_theme_constant_override("separation", 12)
	var resistance_title := _label("Weerstand")
	resistance_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resistance_row.add_child(resistance_title)
	resistance_choice = _choice()
	resistance_choice.custom_minimum_size.x = 260
	resistance_choice.add_item("Manueel", 0)
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

func resistance_mode() -> String:
	return "ERG" if resistance_choice != null and resistance_choice.get_selected_id() == 1 else "MANUAL"

func _refresh_resistance_hint() -> void:
	resistance_hint.text = "ERG is voorbereid; automatische weerstand is nog niet beschikbaar." if resistance_mode() == "ERG" else "Trap zelf het aangegeven doelvermogen."


func team_size() -> int:
	return teammates.get_selected_id() if teammates != null else 3
