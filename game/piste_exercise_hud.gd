extends "res://derny_hud.gd"
var mission_title: Label
var mission_text: Label
var mission_bar: ProgressBar
func _ready() -> void:
	super._ready()
	dial.hide()
	lap_label.add_theme_font_size_override("font_size",30)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",style()); left_stack.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); panel.add_child(box)
	mission_title = text("",24); box.add_child(mission_title)
	mission_text = text("",20); mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(mission_text)
	mission_bar = ProgressBar.new(); mission_bar.show_percentage = false; mission_bar.custom_minimum_size.y = 16; mission_bar.max_value = 250; box.add_child(mission_bar)
	var hint := text("←/→ of paddles: rijlijn\nC: camera · B: achteruitkijken",16); box.add_child(hint)
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
	mission_title.text = session.title(session.kind)
	lap_label.text = "%d:%02d" % [int(session.elapsed)/60,int(session.elapsed)%60]
	if session.kind == "flying_start":
		mission_text.text = "Nog %.0f m tot de achtervolgingslijn\nPiek %.0f W · plafond %.0f W\nHoogte op de piste: %.1f m" % [maxf(0,250-session.gained_m),session.peak_w,session.power_budget,scene.game._at(scene.distance,scene.player_lane_offset).y]
	else:
		var remaining := maxi(0,ceili(session.time_limit-session.elapsed))
		mission_text.text = "Peloton %.0f km/u\n%.1f / 250 m gewonnen\nNog %d:%02d" % [session.target_kmh,session.gained_m,remaining/60,remaining%60]
	mission_bar.value = clampf(session.gained_m,0,250)
	status_panel.visible = scene.too_close
	phase_label.text = "Peloton te dicht · stuur opzij om aan te vallen"
	var positions: Array[float] = [scene.distance]
	if session.kind == "take_lap":
		for i in range(session.PACK_COUNT): positions.append(scene.pack_distance-i*session.PACK_SPACING)
		map.set_peloton({"front":scene.pack_distance,"tail":session.pack_tail(scene.pack_distance)})
	else: map.set_peloton({})
	var lines: Array[float] = []
	if session.kind == "flying_start": lines.append(float(session.origin))
	map.start_lines = lines
	map.set_progress(positions)
