extends PanelContainer
const Style := preload("res://menu_theme.gd")
const Flags := preload("res://national_flags.gd")
var rows: VBoxContainer
var last_key := ""
var abbreviations := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -312; offset_right = -32; offset_top = 330; offset_bottom = 360
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Style.panel(Color(0.9608, 0.9451, 0.9059, 0.75), Color(0.8235, 0.8510, 0.8745, 0.65), 10, 10))
	rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 2); add_child(rows)

func update_standings(data: Array[Dictionary]) -> void:
	var key := JSON.stringify(data)
	if key == last_key or rows == null: return
	last_key = key
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var title := Label.new(); title.text = "VIRTUEEL OMNIUM"; title.add_theme_font_size_override("font_size", 17); rows.add_child(title)
	if abbreviations.is_empty():
		var identities: Array = data.duplicate(true)
		identities.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.id) < String(b.id))
		var counts := {}; var initials := {}
		for rider in identities:
			var short := ""
			for word in String(rider.name).split(" ", false): short += word.left(1).to_upper()
			initials[rider.id] = short; counts[short] = int(counts.get(short, 0)) + 1
		var used := {}
		for rider in identities:
			var short: String = initials[rider.id]
			used[short] = int(used.get(short, 0)) + 1
			abbreviations[rider.id] = short + (str(used[short]) if counts[short] > 1 else "")
	for index in range(data.size()):
		var rider: Dictionary = data[index]
		var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; rows.add_child(row)
		row.add_theme_constant_override("separation", 5)
		var rank := Label.new(); rank.text = str(index + 1) + "."
		rank.custom_minimum_size.x = 26; rank.add_theme_font_size_override("font_size", 16); row.add_child(rank)
		var flag := TextureRect.new(); flag.texture = Flags.texture(String(rider.country)); flag.custom_minimum_size = Vector2(22, 17)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(flag)
		var name_label := Label.new()
		var short: String = abbreviations[rider.id]
		name_label.text = short; name_label.tooltip_text = rider.name; name_label.custom_minimum_size.x = 44
		name_label.add_theme_font_size_override("font_size", 16)
		if rider.player: name_label.add_theme_color_override("font_color", Style.BLUE)
		row.add_child(name_label)
		var laps := Label.new(); var lap_count: int = int(rider.get("laps", 0))
		laps.text = "%+d ronde%s" % [lap_count, "" if absi(lap_count) == 1 else "n"] if lap_count != 0 else ""
		laps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		laps.custom_minimum_size.x = 85; laps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		laps.add_theme_font_size_override("font_size", 16); row.add_child(laps)
		var score := Label.new(); score.custom_minimum_size.x = 30
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.text = str(rider.score); score.add_theme_font_size_override("font_size", 16); row.add_child(score)
