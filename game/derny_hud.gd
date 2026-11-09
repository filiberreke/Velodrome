extends "res://race_hud.gd"
## Reuses the race power meter, metrics panel, palette and slipstream bar.
var cadence_label: Label
var phase_label: Label
var graph: Control
var stop_button: Button
var leave_button: Button
func _ready() -> void:
	super._ready()
	for node in [map_panel,nearby_panel,points_panel,team_laps_panel,solo_panel,bottom_bar,developer_panel,signals]: node.hide()
	left_stack.offset_top = 112
	cadence_label = _metric(power_panel.get_child(0), "CADANS", "— rpm")
	energy_panel.hide()
	phase_label = status_label
	status_panel.offset_top = 248
	status_panel.offset_bottom = 308
	var controls := VBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -400
	controls.offset_right = -32
	controls.offset_top = 150
	controls.add_theme_constant_override("separation",8)
	add_child(controls)
	for caption in ["Stop training", "← Pistetraining"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 46
		controls.add_child(button)
	stop_button = controls.get_child(0)
	leave_button = controls.get_child(1)
	graph = preload("res://training_graph.gd").new()
	add_child(graph)
	graph.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	graph.offset_left = 24
	graph.offset_right = -24
	graph.offset_top = -222
	graph.offset_bottom = -24
func update_training(scene) -> void:
	var power: float = scene.demo_power if scene.demo else scene.game.setup_panel.ftp_page.measured
	var target: float = scene.required_power()
	var role := "Richtvermogen · schatting" if scene.session.phase == "PACE" else "Automatisch meegenomen tot 30 km/u"
	if not scene.demo and scene.game.trainer_control.phase == "ACTIVE" and not scene.game.trainer_control.aero_supported: role += " · beschutting alleen virtueel"
	power_meter.set_power(power,target,true,role)
	speed_label.text = "%.1f" % (scene.player_speed * 3.6)
	var heart: Variant = scene.game.trainer_heart_rate_bpm if not scene.demo else null
	heart_label.text = "%d bpm" % int(heart) if heart is float or heart is int else "— bpm"
	cadence_label.text = "%.0f rpm" % scene.game.cadence if not scene.demo and scene.game.cadence >= 0 else "— rpm"
	gear_label.text = str(scene.game.trainer_gear) if not scene.demo else "PC-proefrit"
	gear_label.get_parent().get_child(0).text = "VERSNELLING" if not scene.demo else "BEDIENING"
	slipstream_bar.max_value = 88
	slipstream_bar.value = scene.reduction * 100
	slipstream_label.text = "%d%%" % roundi(scene.reduction*100)
	var caption := "Aanloop · automatisch aansluiten · nog %.0f m" % maxf(0,250-scene.session.runup_distance) if scene.session.phase == "RUNUP" else "Derny %.0f km/u · %.1f m · volgende stap over %d s" % [scene.session.target_kmh,scene.gap(),int(ceil(60-fmod(scene.session.elapsed,60)))]
	if scene.too_close: caption = "TE DICHT · begrensd op %.0f km/u · minder vermogen" % scene.session.target_kmh
	elif scene.session.loss_seconds > 0: caption = "SLUIT AAN · nog %.1f s" % maxf(0,5-scene.session.loss_seconds)
	phase_label.text = caption
	status_panel.show()
