extends "res://derny_hud.gd"
var exchange_hud: Control
func _ready() -> void:
	super._ready()
	dial.hide()
	exchange_hud = preload("res://madison_hud.gd").new(); add_child(exchange_hud)
func update_training(scene) -> void:
	var power: float = scene.demo_power if scene.demo else scene.game.setup_panel.ftp_page.measured
	power_meter.set_power(power)
	speed_label.text = "%.1f" % (scene.player_speed*3.6)
	gear_label.text = "PC-proefrit" if scene.demo else str(scene.game.trainer_gear)
	cadence_label.text = "— rpm" if scene.demo or scene.game.cadence < 0 else "%.0f rpm" % scene.game.cadence
	var heart: Variant = scene.game.trainer_heart_rate_bpm
	heart_label.text = "%d bpm" % int(heart) if heart is float or heart is int else "— bpm"
	slipstream_bar.value = 0; slipstream_label.text = "0%"
	var state: Dictionary = scene.madison.parameters(); state["progress"] = scene.page.progress.summary()
	if not scene.partner_present: state["message"] = "Volgende aflossing over %.0f m" % maxf(0,scene.next_spawn_player_distance-scene.distances[0])
	exchange_hud.update_state(state)
	phase_label.text = "" if scene.demo else scene.game.setup_panel.ftp_page.signal_state.status(scene.game._now_s())
	status_panel.visible = not phase_label.text.is_empty()
