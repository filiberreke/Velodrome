extends VBoxContainer
signal back_requested
signal environment_requested(active: bool)
const Ramp := preload("res://ftp_ramp.gd")
const Trainer := preload("res://trainer_control.gd")
var test := Ramp.new()
var trainer := Trainer.new()
var last_sample := -100.0
var sample_id := -1
var measured := 0.0
var gear := -1
var telemetry_ok := false
var bridge_update_needed := false
var confirmation_since := -1.0
var confirmation_target := -1
var warmup_hint: Label
var title: Label
var detail: Label
var result: Label
var start_button: Button
var stop_button: Button
var back_button: Button

func _ready() -> void:
	trainer.erg_only = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 22)
	title = _label("FTP Ramp Test", 38)
	detail = _label("5 minuten vrij opwarmen op je eigen vermogen, zonder ERG-doel.\nDaarna 100 W, elke minuut +20 W. Blijf zitten en trap gelijkmatig.\nStop zodra je niet meer kunt. FTP = 75% van je beste gemeten 60 seconden.\nEen echte trainer met verse vermogensmetingen is vereist.", 24)
	result = _label("", 30)
	warmup_hint = _label("Richtvermogen: ongeveer 80–120 W, of lager als dat prettiger is.\nDit is een vrijblijvende indicatie: kies een rustig, comfortabel vermogen.", 22)
	start_button = _button("Start FTP-test", begin)
	stop_button = _button("Stop test · ERG vrijgeven", func(): finish("Handmatig gestopt"))
	back_button = _button("← Training", leave)
	_refresh()

func _label(text: String, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	add_child(node)
	return node

func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 60
	node.pressed.connect(action)
	add_child(node)
	return node

func now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

func fresh(now: float) -> bool:
	return telemetry_ok and now - last_sample <= Ramp.SIGNAL_TIMEOUT

func receive(packet: Dictionary, now: float) -> void:
	if packet.get("type") != "telemetry": return
	var power: Variant = packet.get("power_w")
	var id: Variant = packet.get("power_sample_id")
	var age: Variant = packet.get("power_age_s")
	bridge_update_needed = not packet.has("power_sample_id") or not packet.has("power_age_s")
	var recent: bool = (age is int or age is float) and is_finite(float(age)) and float(age) >= 0.0 and float(age) <= Ramp.SIGNAL_TIMEOUT
	var numeric: bool = (power is float or power is int) and is_finite(float(power)) and float(power) >= 0.0
	telemetry_ok = packet.get("valid") == true and numeric and recent and (id is int or id is float) and is_finite(float(id)) and float(id) >= 0 and floor(float(id)) == float(id)
	if not telemetry_ok:
		if test.running(): finish("Vermogenssignaal ongeldig of verloren")
		return
	if int(id) == sample_id: return # Bridge repeats the last FTMS sample at 10 Hz.
	if int(id) < sample_id:
		if test.running(): finish("Bridge herstart of metingen uit volgorde")
		sample_id = int(id)
		last_sample = -100.0
		return
	sample_id = int(id)
	last_sample = now - float(age)
	measured = float(power)
	var reported_gear: Variant = packet.get("gear")
	gear = int(reported_gear) if (reported_gear is int or reported_gear is float) and is_finite(float(reported_gear)) and float(reported_gear) >= 1 and float(reported_gear) <= 12 else -1
	var rpm: Variant = packet.get("cadence_rpm")
	var cadence: float = float(rpm) if (rpm is int or rpm is float) and is_finite(float(rpm)) else -1.0
	test.sample(last_sample, measured, cadence)
	if test.phase == "RESULT": _release(now)

func begin() -> void:
	var now := now_s()
	if test.running() or not fresh(now) or not release_complete(): return
	test.start(now)
	confirmation_since = -1.0
	confirmation_target = -1
	trainer.arm()
	_refresh()
	environment_requested.emit(true)
	stop_button.grab_focus()

func release_complete() -> bool:
	var free_sim: bool = trainer.state.get("mode") == "SIM" and now_s() - trainer.last_response <= 1.5
	return not trainer.socket.is_bound() or (not trainer.owned and trainer.pending.is_empty() and (trainer.state.get("release_confirmed", false) or free_sim) and not trainer.state.get("udp_owned", false))

func _release(now: float) -> void:
	trainer.tick(false, 0.0, 1.0, now)

func finish(reason: String) -> void:
	test.stop(reason)
	_release(now_s())
	_refresh()

func leave() -> void:
	finish("Test verlaten")
	environment_requested.emit(false)
	back_requested.emit()

func _process(_delta: float) -> void:
	var now := now_s()
	if test.running() and (not is_visible_in_tree() or not fresh(now)):
		finish("Vermogenssignaal verloren" if is_visible_in_tree() else "Test verlaten")
	var target := test.target(now)
	trainer.tick(test.phase in ["CONNECTING", "RAMP"], 0.0, 1.0, now, target)
	if test.running():
		if test.phase == "RAMP" and now - trainer.last_response > 3.0:
			finish("Geen antwoord meer van trainerbridge")
		elif not trainer.error.is_empty():
			finish("Trainerfout: " + trainer.error)
		else:
			var state: Dictionary = trainer.state
			var confirmed: bool = trainer.owned and state.get("mode") == "ERG" and state.get("desired_mode") == "ERG" and state.get("confirmed_target_w") == target and state.get("applied_revision", -1) == state.get("revision", -2)
			if confirmation_target != target:
				confirmation_target = target
				confirmation_since = now
			if confirmed: confirmation_since = now
			elif test.phase != "WARMUP" and now - confirmation_since > 8.0: finish("ERG-doel niet bevestigd door trainer")
			test.tick(now, confirmed)
			if not test.running(): _release(now)
	_refresh()

func _refresh() -> void:
	if start_button == null: return
	start_button.visible = not test.running()
	start_button.disabled = not fresh(now_s()) or not release_complete()
	stop_button.visible = test.running()
	back_button.disabled = test.running()
	detail.visible = not test.running() and test.phase != "RESULT"
	warmup_hint.visible = test.phase in ["IDLE", "WARMUP"]
	if test.running():
		var elapsed := maxf(0.0, now_s() - test.started_at)
		var target_text := "Vrij vermogen" if test.phase == "WARMUP" else "Doel %d W" % test.target(now_s())
		var caption := {"WARMUP": "Vrije opwarming", "CONNECTING": "Wacht op ERG-bevestiging", "RAMP": "Ramp Test"}
		result.text = "%s · %02d:%02d\n%s · gemeten %.0f W\nBeste 60 s: %.1f W" % [caption[test.phase], int(elapsed) / 60, int(elapsed) % 60, target_text, measured, test.best_60]
		if test.phase == "WARMUP":
			var remaining := int(ceil(maxf(0.0, Ramp.WARMUP_SECONDS - elapsed)))
			result.text = "Start test over %02d:%02d\n%s · gemeten %.0f W\nSchakelen blijft beschikbaar. Daarna neemt ERG over op 100 W." % [remaining / 60, remaining % 60, target_text, measured]
			if gear > 0: result.text += "\nVersnelling %d / 12" % gear
	elif test.phase == "RESULT":
		result.text = "%s\n" % test.reason
		result.text += "Geschatte FTP: %.0f W · beste 60 s: %.1f W" % [test.ftp(), test.best_60] if test.best_60 > 0.0 else "Geen FTP: minder dan 60 seconden aaneengesloten rampmetingen."
		result.text += "\nERG vrijgegeven." if release_complete() else "\nERG-vrijgave nog niet bevestigd. Bridge bewaakt ook de lease."
	else:
		result.text = "Werk de bridge bij voor de FTP-test." if bridge_update_needed else "Trainer gereed." if fresh(now_s()) else "Wacht op verse trainergegevens."

func shutdown() -> void:
	finish("Spel gesloten")
	trainer.close()

func _notification(what: int) -> void:
	# Moving the HUD between menu and session containers also exits the tree.
	# Only actual deletion closes the socket; a layout move must keep warmup alive.
	if what == NOTIFICATION_PREDELETE:
		test.stop("Spel gesloten")
		trainer.close()
