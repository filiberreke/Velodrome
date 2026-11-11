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
	var placement: Dictionary = scene.madison.positioning(scene)
	state["position_valid"] = placement.valid; state["position_reason"] = placement.reason
	var pace: Dictionary = scene.madison.speed_guidance(scene)
	state["speed_valid"] = pace.valid; state["speed_reason"] = pace.reason
	state["instruction"] = "Volg de gele lijn en rij sneller dan %.1f km/u" % pace.minimum_kmh if (scene.madison.giver if scene.madison.active else scene.madison.active_rider) == 0 else "Volg de gele lijn. Rij maximaal %.0f km/u" % pace.receiver_max_kmh
	state["partner_present"] = scene.partner_present
	state["role"] = "Inkomend · jij geeft" if (scene.madison.giver if scene.madison.active else scene.madison.active_rider) == 0 else "Uitgaand · jij ontvangt"
	state["feedback"] = scene.feedback if scene.total_elapsed < scene.feedback_until else ""
	if not scene.partner_present: state["message"] = "Volgende aflossing over %.0f m" % maxf(0,scene.next_spawn_player_distance-scene.distances[0])
	exchange_hud.update_state(state)
	phase_label.text = "" if scene.demo else scene.game.setup_panel.ftp_page.signal_state.status(scene.game._now_s())
	status_panel.visible = not phase_label.text.is_empty()
