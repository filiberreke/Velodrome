extends VBoxContainer
var menu
var rows: VBoxContainer
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
	back.text = "← Pistetraining"
	back.custom_minimum_size.y = 48
	back.pressed.connect(menu.show_piste_training)
	add_child(back)
func refresh() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var activities: Array[Dictionary] = menu.training_store.recent()
	if activities.is_empty():
		var empty := Label.new()
		empty.text = "Nog geen opgeslagen trainingen."
		rows.add_child(empty)
	for activity in activities:
		var button := Button.new()
		var duration: int = int(activity.get("duration_s",0))
		button.text = "%s · Derny · %d:%02d · %d km/u%s" % [activity.get("started_local",""),duration/60,duration%60,int(activity.get("completed_kmh",0))," · PC-proefrit" if activity.get("demo",false) else ""]
		if not activity.get("final",false): button.text += " · tussentijds bewaard"
		button.custom_minimum_size.y = 64
		button.pressed.connect(func(): menu.show_derny(); menu.derny_page.show_activity(activity))
		rows.add_child(button)
