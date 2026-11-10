extends "res://race_hud.gd"
## Reuses the race power meter, metrics panel, palette and slipstream bar.
var cadence_label: Label
var phase_label: Label
var graph: Control
var stop_button: Button
var leave_button: Button
var dial: Control
var call_label: Label
var call_age := 2.0
const CALL_SECONDS := 1.2
func _ready() -> void:
	super._ready()
	for node in [map_panel,nearby_panel,points_panel,team_laps_panel,solo_panel,bottom_bar,developer_panel,signals]: node.hide()
	left_stack.offset_top = 112
	cadence_label = _metric(power_panel.get_child(0), "CADANS", "— rpm")
	energy_panel.hide()
	dial = preload("res://derny_dial.gd").new()
	left_stack.add_child(dial)
	call_label = Label.new()
	call_label.add_theme_font_override("font",MenuStyle.heading())
	call_label.add_theme_font_size_override("font_size",46)
	call_label.add_theme_constant_override("outline_size",5)
	call_label.add_theme_color_override("font_outline_color",MenuStyle.INK)
	call_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(call_label)
	call_label.hide()
	phase_label = status_label
	status_panel.set_anchors_preset(Control.PRESET_CENTER)
	status_panel.offset_left = -410
	status_panel.offset_right = 410
	status_panel.offset_top = -40
	status_panel.offset_bottom = 40
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
	power_meter.set_power(power)
	power_meter.tooltip_text = "Geleverd vermogen"
	speed_label.text = "%.1f" % (scene.player_speed * 3.6)
	var heart: Variant = scene.game.trainer_heart_rate_bpm if not scene.demo else null
	heart_label.text = "%d bpm" % int(heart) if heart is float or heart is int else "— bpm"
	cadence_label.text = "%.0f rpm" % scene.game.cadence if not scene.demo and scene.game.cadence >= 0 else "— rpm"
	gear_label.text = str(scene.game.trainer_gear) if not scene.demo else "PC-proefrit"
	gear_label.get_parent().get_child(0).text = "VERSNELLING" if not scene.demo else "BEDIENING"
	slipstream_bar.max_value = scene.session.MAX_DRAFT * 100
	slipstream_bar.value = scene.reduction * 100
	slipstream_label.text = "%d%%" % roundi(scene.reduction*100)
	var approach: bool = scene.session.phase == "RUNUP"
	var progress: float = scene.session.runup_distance/250 if approach else scene.session.step_elapsed/60
	dial.update_dial(scene.motor.speed_mps*3.6,progress,int(ceil(60-scene.session.step_elapsed)),approach)
	phase_label.text = "Te dicht - snelheid begrensd"
	var status: String = scene.game.setup_panel.ftp_page.signal_state.status(scene.game._now_s()) if not scene.demo else ""
	status_panel.visible = scene.too_close or not status.is_empty()
	if not status.is_empty(): phase_label.text = status
	_update_call(scene)
func shout(message: String) -> void:
	call_label.text = message
	call_label.add_theme_color_override("font_color",Color("86f66c") if message == "ALLEZ" else Color("ffe247"))
	call_age = 0
	call_label.show()
func _process(dt: float) -> void:
	call_age += dt
	if call_age >= CALL_SECONDS: call_label.hide()
func _update_call(scene) -> void:
	if call_age >= CALL_SECONDS: return
	var camera: Camera3D = scene.game.camera
	var start: Vector3 = scene.game.bikes[0].position+Vector3.UP*1.8
	var end: Vector3 = scene.pilot.position+Vector3.UP*1.8
	var a := camera.unproject_position(start) if not camera.is_position_behind(start) else get_viewport_rect().size*Vector2(.5,.7)
	var b := camera.unproject_position(end)
	var fraction := clampf(call_age/CALL_SECONDS,0,1)
	call_label.position = a.lerp(b,fraction)-call_label.size*.5
	call_label.modulate.a = 1-fraction
	call_label.scale = Vector2.ONE*lerpf(1.0,.7,fraction)
