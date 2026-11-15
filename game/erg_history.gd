extends VBoxContainer
## ERG workouts and FTP tests: compact Velodrome list and full sensor graph.
const Palette := preload("res://menu_theme.gd")
const Intensity := preload("res://workout_intensity.gd")
var menu
var listing: VBoxContainer
var detail: VBoxContainer
var entries: VBoxContainer
var details_title: Label
var details_text: Label
var detail_graph: Control
var back_button: Button
var detail_back: Button

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	listing = VBoxContainer.new()
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(listing)
	var caption := Label.new()
	caption.text = "GEREDEN ERG-TRAININGEN EN FTP-TESTS"
	caption.add_theme_font_size_override("font_size", 25)
	caption.add_theme_color_override("font_color", Palette.BLUE)
	listing.add_child(caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 9)
	scroll.add_child(entries)
	back_button = Button.new()
	back_button.text = "← ERG-training"
	back_button.custom_minimum_size.y = 48
	back_button.pressed.connect(func(): menu.show_training())
	listing.add_child(back_button)
	detail = VBoxContainer.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	add_child(detail)
	details_title = Label.new()
	details_title.add_theme_font_size_override("font_size", 30)
	details_title.add_theme_color_override("font_color", Palette.INK)
	detail.add_child(details_title)
	details_text = Label.new()
	details_text.add_theme_font_size_override("font_size", 19)
	details_text.add_theme_color_override("font_color", Palette.MUTED)
	detail.add_child(details_text)
	detail_graph = preload("res://training_graph.gd").new()
	detail_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(detail_graph)
	detail_back = Button.new()
	detail_back.text = "← Overzicht"
	detail_back.custom_minimum_size.y = 48
	detail_back.pressed.connect(func(): detail.hide(); listing.show(); back_button.grab_focus.call_deferred())
	detail.add_child(detail_back)
	detail.hide()

static func mean_power(activity: Dictionary) -> float:
	if activity.has("mean_power_w"): return float(activity.mean_power_w)
	var samples: Array = activity.get("samples",[])
	var energy := 0.0
	var duration := 0.0
	for i in range(1,samples.size()):
		var dt := float(samples[i].get("time_s",0)) - float(samples[i-1].get("time_s",0))
		if dt <= 0.0 or dt > 10.0: continue
		energy += dt * float(samples[i-1].get("power_w",0))
		duration += dt
	return energy / duration if duration > 0.0 else 0.0

func refresh() -> void:
	detail.hide()
	listing.show()
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var workouts: Array[Dictionary] = []
	for item in menu.training_store.recent(300):
		if str(item.get("kind","")) in ["ftp_test","erg_workout"]:
			workouts.append(item)
	workouts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("started_unix",0)) > int(b.get("started_unix",0)))
	if workouts.is_empty():
		var empty := Label.new()
		empty.text = "Nog geen geregistreerde ERG-trainingen of FTP-tests.\nNa een rit verschijnen hier de gemeten waarden en de trainingsgrafiek."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 22)
		entries.add_child(empty)
		return
	for activity in workouts:
		var watts: float = mean_power(activity)
		var ftp: float = float(activity.get("ftp_reference_w", menu.ftp_page.player_profile.ftp()))
		var ratio: float = watts / maxf(20.0,ftp)
		var shell := PanelContainer.new()
		shell.add_theme_stylebox_override("panel",Palette.panel(Palette.PAPER,Palette.LINE,14,10))
		entries.add_child(shell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",18)
		shell.add_child(row)
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 68
		button.add_theme_font_size_override("font_size",19)
		var seconds: int = int(activity.get("duration_s",0))
		var date_text: String = str(activity.get("started_local",""))
		if date_text.is_empty():
			date_text = Time.get_datetime_string_from_unix_time(int(activity.get("started_unix",0))).replace("T"," ")
		button.text = "%s     %s     %d:%02d     %.0f W" % [date_text,str(activity.get("title","ERG-training")),seconds/60,seconds%60,watts]
		button.pressed.connect(_show_activity.bind(activity))
		row.add_child(button)
		var flames := Intensity.new()
		flames.configure(ratio)
		row.add_child(flames)

func _show_activity(activity: Dictionary) -> void:
	listing.hide()
	detail.show()
	details_title.text = str(activity.get("title","Training")) + " · " + str(activity.get("started_local",""))
	var seconds: int = int(activity.get("duration_s",0))
	var watts: float = mean_power(activity)
	var description: String = "Gereden tijd %d:%02d · gemiddeld %.0f W · %.2f km" % [seconds/60,seconds%60,watts,float(activity.get("distance_m",0.0))/1000.0]
	if activity.has("ftp_w"): description += " · berekende FTP %.0f W" % float(activity.ftp_w)
	description += "\n" + str(activity.get("reason",""))
	details_text.text = description
	detail_graph.set_samples(activity.get("samples",[]))
	detail_back.grab_focus.call_deferred()
