extends PanelContainer
var store
var entries: Array[Dictionary] = []
var rows: VBoxContainer
func _ready() -> void:
	add_theme_stylebox_override("panel",preload("res://menu_theme.gd").panel(Color("fffdf8"),Color("d2d9df"),14,10))
	custom_minimum_size = Vector2(640,200)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",8); add_child(box)
	var title := Label.new(); title.text = "Beste vliegende starts · top 10"; title.add_theme_font_size_override("font_size",23); box.add_child(title)
	_row(box,["#","Poging","Snelheid","Gem. W","Max. W"],true)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	rows = VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(rows)
func _row(parent: Node, values: Array, heading: bool = false) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); parent.add_child(row)
	for i in range(values.size()):
		var label := Label.new(); label.text = str(values[i]); label.add_theme_font_size_override("font_size",17 if heading else 19)
		label.custom_minimum_size.x = [28,170,110,90,90][i]
		if i == 1: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
func refresh() -> void:
	if rows == null or store == null: return
	entries.clear()
	for item in store.recent(100000):
		if item.get("kind") != "flying_start" or not item.get("exercise_success",false): continue
		var speed: Variant = item.get("entry_speed_kmh")
		if not (speed is float or speed is int) or not is_finite(float(speed)) or float(speed) <= 0: continue
		entries.append(item)
	entries.sort_custom(func(a,b):
		if float(a.entry_speed_kmh) != float(b.entry_speed_kmh): return float(a.entry_speed_kmh) > float(b.entry_speed_kmh)
		return float(a.get("started_unix",0)) > float(b.get("started_unix",0))
	)
	if entries.size() > 10: entries.resize(10)
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	for i in range(entries.size()):
		var item := entries[i]; var date := str(item.get("started_local",""))
		if date.length() >= 16: date = date.substr(8,2)+"/"+date.substr(5,2)+" "+date.substr(11,5)
		if item.get("demo",false): date += " · PC"
		_row(rows,[str(i+1),date,"%.2f km/u" % float(item.entry_speed_kmh),"%.0f" % float(item.get("mean_power_w",0)),"%.0f" % float(item.get("peak_power_w",0))])
	if entries.is_empty():
		var empty := Label.new(); empty.text = "Nog geen voltooide vliegende starts."; rows.add_child(empty)
