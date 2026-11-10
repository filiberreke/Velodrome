extends "res://derny_hud.gd"
var mission_panel: PanelContainer
var laps_panel: PanelContainer
var totals_label: Label
var current_lap_label: Label
var lap_rows: VBoxContainer
var lap_scroll: ScrollContainer
var shown_laps := -1
var mission_title: Label
var mission_text: Label
var mission_bar: ProgressBar
func _ready() -> void:
	super._ready()
	dial.hide()
	lap_label.add_theme_font_size_override("font_size",30)
	mission_panel = PanelContainer.new(); mission_panel.add_theme_stylebox_override("panel",style()); left_stack.add_child(mission_panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); mission_panel.add_child(box)
	mission_title = text("",24); box.add_child(mission_title)
	mission_text = text("",20); mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(mission_text)
	mission_bar = ProgressBar.new(); mission_bar.show_percentage = false; mission_bar.custom_minimum_size.y = 16; mission_bar.max_value = 250; box.add_child(mission_bar)
	var hint := text("←/→ of paddles: rijlijn\nC: camera · B: achteruitkijken",16); box.add_child(hint)
	_build_lap_table()
	map_panel.reparent(self); map_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT); map_panel.offset_left = -400; map_panel.offset_right = -32; map_panel.offset_top = 300; map_panel.offset_bottom = 540; map_panel.show()
func update_training(scene) -> void:
	var power: float = scene.demo_power if scene.demo else scene.game.setup_panel.ftp_page.measured
	power_meter.set_power(power)
	speed_label.text = "%.1f" % (scene.player_speed*3.6)
	var heart: Variant = scene.game.trainer_heart_rate_bpm if not scene.demo else null
	heart_label.text = "%d bpm" % int(heart) if heart is float or heart is int else "— bpm"
	cadence_label.text = "%.0f rpm" % scene.game.cadence if not scene.demo and scene.game.cadence >= 0 else "— rpm"
	gear_label.text = str(scene.game.trainer_gear) if not scene.demo else "PC-proefrit"
	gear_label.get_parent().get_child(0).text = "VERSNELLING" if not scene.demo else "BEDIENING"
	slipstream_bar.max_value = 50; slipstream_bar.value = scene.reduction*100; slipstream_label.text = "%d%%" % roundi(scene.reduction*100)
	var session = scene.session
	mission_panel.visible = session.kind != "free_ride"
	laps_panel.visible = session.kind == "free_ride"
	if session.kind == "free_ride": _update_lap_table(scene)
	mission_title.text = session.title(session.kind)
	lap_label.text = "%d:%02d" % [int(session.elapsed)/60,int(session.elapsed)%60]
	if session.kind == "flying_start":
		mission_text.text = "Nog %.0f m tot de achtervolgingslijn\nGem. %.0f W · max. %.0f W\nHoogte op de piste: %.1f m" % [maxf(0,250-session.gained_m),session.energy_j/maxf(.001,session.elapsed),session.peak_w,scene.game._at(scene.distance,scene.player_lane_offset).y]
	elif session.kind == "take_lap":
		var remaining := maxi(0,ceili(session.time_limit-session.elapsed))
		mission_text.text = "Peloton %.0f km/u\n%.1f / 250 m gewonnen\nNog %d:%02d" % [session.target_kmh,session.gained_m,remaining/60,remaining%60]
	mission_bar.value = clampf(session.gained_m,0,250)
	status_panel.hide()
	var positions: Array[float] = [scene.distance]
	if session.kind == "take_lap":
		for at in scene.pack_state.distances: positions.append(float(at))
		map.set_peloton({"front":scene.pack_state.front,"tail":scene.pack_state.tail})
	else:
		map.set_peloton({})
		if session.kind == "free_ride":
			for at in scene.pacers.distances: positions.append(float(at))
	var lines: Array[float] = []
	if session.kind in ["flying_start","free_ride"]: lines.append(float(session.origin))
	map.start_lines = lines
	var colours: Array[Color] = []
	if session.kind == "free_ride":
		colours.append(Color("ffdc46"))
		for colour in scene.Pacers.COLOURS: colours.append(colour)
	map.set_colors(colours)
	map.set_progress(positions)

static func lap_time(seconds: float) -> String:
	var ms := roundi(maxf(0,seconds)*1000)
	return "%d:%02d.%03d" % [ms/60000,(ms/1000)%60,ms%1000]
func _build_lap_table() -> void:
	laps_panel = PanelContainer.new(); laps_panel.add_theme_stylebox_override("panel",style()); left_stack.add_child(laps_panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",7); laps_panel.add_child(box)
	box.add_child(text("Vrije training · rondetijden",22))
	totals_label = text("",20); box.add_child(totals_label)
	current_lap_label = text("",18); box.add_child(current_lap_label)
	var header := HBoxContainer.new(); box.add_child(header)
	var number := text("Ronde",16); number.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(number); header.add_child(text("Tijd",16))
	lap_scroll = ScrollContainer.new(); lap_scroll.custom_minimum_size.y = 126; box.add_child(lap_scroll)
	lap_rows = VBoxContainer.new(); lap_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lap_scroll.add_child(lap_rows)
func _update_lap_table(scene) -> void:
	var session = scene.session
	totals_label.text = "%d:%02d · %.3f km" % [int(session.elapsed)/60,int(session.elapsed)%60,scene.total_distance/1000]
	current_lap_label.text = "Ronde %d · %s" % [session.laps.size()+1,lap_time(session.elapsed-session.lap_started_s)]
	if shown_laps == session.laps.size(): return
	shown_laps = session.laps.size()
	for child in lap_rows.get_children(): lap_rows.remove_child(child); child.queue_free()
	for lap in session.laps:
		var row := HBoxContainer.new(); lap_rows.add_child(row)
		var number := text(str(int(lap.lap)),18); number.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(number); row.add_child(text(lap_time(float(lap.seconds)),18))
	if not session.laps.is_empty(): _scroll_laps_latest.call_deferred()

func _scroll_laps_latest() -> void:
	if is_inside_tree() and lap_rows.get_child_count() > 0:
		lap_scroll.ensure_control_visible(lap_rows.get_child(lap_rows.get_child_count()-1))
