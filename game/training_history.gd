extends VBoxContainer
const Style := preload("res://menu_theme.gd")
const PISTE_KINDS := ["derny", "madison", "free_ride", "flying_start", "take_lap"]
const COLUMN_WIDTHS := [1.25, 2.2, 0.65, 2.35, 0.15]
var menu
var rows: VBoxContainer
var back_button: Button
var summary: Label

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",14)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size",18)
	summary.add_theme_color_override("font_color",Style.MUTED)
	add_child(summary)
	var header := PanelContainer.new()
	var header_skin := Style.panel(Style.BLUE,Color.TRANSPARENT,16,10)
	header.add_theme_stylebox_override("panel",header_skin)
	add_child(header)
	var headings := _row(header)
	var captions := ["DATUM / TIJD ↓", "PISTETRAINING", "DUUR", "RESULTAAT", ""]
	for i in range(captions.size()): _cell(headings,captions[i],COLUMN_WIDTHS[i],15,Color.WHITE)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keep the header aligned with the rows, even when the scrollbar is needed.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	add_child(scroll)
	header_skin.content_margin_right = 16 + scroll.get_v_scroll_bar().get_combined_minimum_size().x
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	scroll.add_child(rows)
	back_button = Button.new()
	back_button.text = "← Pistetraining"
	back_button.custom_minimum_size.y = 48
	back_button.pressed.connect(menu.show_piste_training)
	add_child(back_button)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",18)
	parent.add_child(row)
	return row

func _cell(parent: HBoxContainer, caption: String, ratio: float, font_size: int = 19, color: Color = Style.INK) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = ratio
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _date(activity: Dictionary) -> String:
	var date := str(activity.get("started_local","")).replace("T"," ")
	if date.is_empty() and int(activity.get("started_unix",0)) > 0:
		date = Time.get_datetime_string_from_unix_time(int(activity.started_unix)).replace("T"," ")
	if date.length() < 16: return "Datum onbekend"
	return "%s/%s/%s\n%s" % [date.substr(8,2),date.substr(5,2),date.substr(0,4),date.substr(11,5)]

func _result(activity: Dictionary) -> String:
	var kind := str(activity.get("kind","derny"))
	var result := str(activity.get("reason","Training bewaard"))
	if kind == "derny":
		result = "Start %d km/u · beste %d km/u" % [int(activity.get("start_speed_kmh",30)),int(activity.get("completed_kmh",0))]
	elif kind == "flying_start" and activity.get("exercise_success",false):
		result = "%.1f km/u · piek %.0f W" % [float(activity.get("entry_speed_kmh",0)),float(activity.get("peak_power_w",0))]
	if not activity.get("final",false): result += "\nTussentijds bewaard"
	return result

func refresh() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var activities: Array[Dictionary] = menu.training_store.recent(0,PISTE_KINDS)
	summary.text = "%d opgeslagen pistetraining%s · nieuwste eerst" % [activities.size(),"" if activities.size() == 1 else "en"]
	if activities.is_empty():
		var empty := Label.new()
		empty.text = "Je pistetrainingen verschijnen hier\n\nRijd een pistetraining en bekijk daarna de resultaten en grafiek in dit overzicht."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size",22)
		empty.add_theme_color_override("font_color",Style.MUTED)
		empty.add_theme_stylebox_override("normal",Style.panel(Style.PAPER,Style.LINE,24))
		rows.add_child(empty)
		return
	for i in range(activities.size()):
		var activity: Dictionary = activities[i]
		var button := Button.new()
		button.custom_minimum_size.y = 88
		button.add_theme_stylebox_override("normal",Style.panel(Style.PAPER if i%2 == 0 else Style.IVORY,Style.LINE,16,10))
		button.add_theme_stylebox_override("hover",Style.panel(Style.PALE,Style.BLUE,16,10))
		button.add_theme_stylebox_override("pressed",Style.panel(Style.PALE,Style.BLUE,16,10))
		button.add_theme_stylebox_override("focus",Style.focus_ring(10))
		button.set_meta("activity_id",str(activity.get("id","")))
		var title := str(activity.get("title","Dernytraining"))
		var result := _result(activity)
		button.tooltip_text = "%s · %s\n%s" % [title,_date(activity).replace("\n"," "),result]
		rows.add_child(button)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
		button.add_child(margin)
		var row := _row(margin)
		_cell(row,_date(activity),COLUMN_WIDTHS[0],18,Style.MUTED)
		_cell(row,title+("\nPC-proefrit" if activity.get("demo",false) else ""),COLUMN_WIDTHS[1],20,Style.BLUE)
		var duration := int(activity.get("duration_s",0))
		_cell(row,"%d:%02d" % [duration/60,duration%60],COLUMN_WIDTHS[2],21)
		_cell(row,result,COLUMN_WIDTHS[3],18,Style.MUTED)
		_cell(row,"›",COLUMN_WIDTHS[4],25,Style.BLUE)
		button.pressed.connect(_open_activity.bind(activity))

func _open_activity(activity: Dictionary) -> void:
	var kind := str(activity.get("kind","derny"))
	var training
	if kind == "derny":
		menu.show_derny()
		training = menu.derny_page
	elif kind == "madison":
		menu.show_madison_training()
		training = menu.madison_page
	else:
		menu.show_piste_exercise(kind)
		training = menu.exercise_page
	training.show_activity(activity)
	training.set_history_origin(true)
