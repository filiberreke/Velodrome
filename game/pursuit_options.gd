extends VBoxContainer
signal changed
const Records := preload("res://pursuit_records.gd")
var library = Records.new()
var distance_choice: OptionButton
var opponent_choice: OptionButton
var cp_input: SpinBox
var cp_box: VBoxContainer
var ride_box: VBoxContainer
var ride_choice: OptionButton
var rides: Array[Dictionary] = []
var ai_choice: OptionButton
var ai_entries: Array[Dictionary] = []

func _label(value: String) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_color_override("font_color", Color("f3f5fa"))
	return node

func _choice() -> OptionButton:
	var node := OptionButton.new()
	node.custom_minimum_size.y = 46
	node.add_theme_font_size_override("font_size", 22)
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return node

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(_label("Afstand"))
	distance_choice = _choice()
	distance_choice.add_item("1 km · 4 ronden", 1000)
	distance_choice.add_item("4 km · 16 ronden", 4000)
	add_child(distance_choice)
	add_child(_label("Tegenstander"))
	opponent_choice = _choice()
	opponent_choice.add_item("AI-tegenstander")
	opponent_choice.add_item("Een vorige rit")
	add_child(opponent_choice)
	cp_box = VBoxContainer.new()
	cp_box.add_child(_label(ai_choice_label()))
	ai_choice = _choice()
	cp_box.add_child(ai_choice)
	refresh_ai_choices()
	ai_choice.item_selected.connect(func(_index: int) -> void: changed.emit())
	cp_box.add_child(_label("CP tegenstander (W)"))
	cp_input = SpinBox.new()
	cp_input.min_value = 50
	cp_input.max_value = 800
	cp_input.value = 250
	cp_input.step = 1
	cp_input.custom_minimum_size.y = 52
	cp_input.get_line_edit().add_theme_font_size_override("font_size", 24)
	cp_box.add_child(cp_input)
	add_child(cp_box)
	ride_box = VBoxContainer.new()
	ride_box.add_child(_label("Opgeslagen rit"))
	ride_choice = _choice()
	ride_box.add_child(ride_choice)
	add_child(ride_box)
	distance_choice.item_selected.connect(func(_index: int) -> void: refresh_rides())
	opponent_choice.item_selected.connect(func(_index: int) -> void: refresh_state())
	ride_choice.item_selected.connect(func(_index: int) -> void: changed.emit())
	refresh_rides()

func distance_m() -> int:
	return distance_choice.get_selected_id()

func is_replay() -> bool:
	return opponent_choice.selected == 1

func selected_ride_id() -> String:
	return str(ride_choice.get_item_metadata(ride_choice.selected)) if ride_choice.selected >= 0 and not rides.is_empty() else ""

func can_start() -> bool:
	return not is_replay() or not selected_ride_id().is_empty()

func refresh_rides() -> void:
	var previous: String = selected_ride_id()
	rides = library.list_rides(distance_m())
	ride_choice.clear()
	for ride in rides:
		ride_choice.add_item("%s · %.2f s" % [ride["name"], ride["time_s"]])
		var index: int = ride_choice.item_count - 1
		ride_choice.set_item_metadata(index, ride["id"])
		if ride["id"] == previous:
			ride_choice.select(index)
	if rides.is_empty():
		ride_choice.add_item("Nog geen rit van deze afstand opgeslagen")
		ride_choice.disabled = true
	else:
		ride_choice.disabled = false
	refresh_state()

func refresh_state() -> void:
	cp_box.visible = not is_replay()
	ride_box.visible = is_replay()
	changed.emit()

func ai_choice_label() -> String:
	return "Kies AI-renner"

func available_ai_entries() -> Array[Dictionary]:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor.has_method("available_pursuit_riders"):
			return ancestor.available_pursuit_riders()
		ancestor = ancestor.get_parent()
	return []

func refresh_ai_choices() -> void:
	ai_entries = available_ai_entries()
	ai_choice.clear()
	for entry in ai_entries:
		ai_choice.add_item(String(entry.name))

func selected_ai() -> Dictionary:
	return ai_entries[ai_choice.selected].duplicate(true) if ai_choice != null and ai_choice.selected >= 0 and ai_choice.selected < ai_entries.size() else {}
