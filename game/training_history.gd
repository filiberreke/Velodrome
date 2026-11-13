extends VBoxContainer
const Style := preload("res://menu_theme.gd")
var menu
var rows: VBoxContainer
var back_button: Button
func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",10)
	scroll.add_child(rows)
	var back := Button.new()
	back_button = back
	back.text = "← Pistetraining"
	back.custom_minimum_size.y = 48
	back.pressed.connect(menu.show_piste_training)
	add_child(back)
func refresh() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var activities: Array[Dictionary] = menu.training_store.recent()
	if activities.is_empty():
		var empty := Label.new()
		empty.text = "Je trainingshistoriek begint hier\n\nVoltooide pistetrainingen verschijnen automatisch in dit overzicht.\nKies een training om de resultaten en grafiek opnieuw te bekijken."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 24)
		empty.add_theme_stylebox_override("normal", Style.panel(Style.PAPER, Style.LINE, 24))
		rows.add_child(empty)
	for activity in activities:
		var button := Button.new()
		var duration: int = int(activity.get("duration_s",0))
		button.text = "Duur %d:%02d · start %d km/u · beste %d km/u%s" % [duration/60,duration%60,int(activity.get("start_speed_kmh",30)),int(activity.get("completed_kmh",0))," · PC-proefrit" if activity.get("demo",false) else ""]
		if activity.get("kind","derny") != "derny":
			button.text = "Duur %d:%02d · %s%s" % [duration/60,duration%60,activity.get("reason","Tussentijds bewaard")," · PC-proefrit" if activity.get("demo",false) else ""]
		if activity.get("kind") == "flying_start" and activity.get("exercise_success",false): button.text += " · %.1f km/u · piek %.0f W" % [activity.get("entry_speed_kmh",0),activity.get("peak_power_w",0)]
		if not activity.get("final",false): button.text += " · tussentijds bewaard"
		var heading := "%s · %s" % [activity.get("started_local", ""), activity.get("title", "Dernytraining")]
		var details := button.text
		button.text = heading + "\n" + details
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 20)
		button.icon = Style.icon('<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>', Style.BLUE)
		button.add_theme_constant_override("h_separation", 18)
		button.custom_minimum_size.y = 88
		button.pressed.connect(func():
			if activity.get("kind","derny") == "derny": menu.show_derny(); menu.derny_page.show_activity(activity)
			elif activity.get("kind") == "madison": menu.show_madison_training(); menu.madison_page.show_activity(activity)
			else: menu.show_piste_exercise(str(activity.kind)); menu.exercise_page.show_activity(activity)
		)
		rows.add_child(button)
