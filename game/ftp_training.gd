extends VBoxContainer
signal back_requested
signal environment_requested(active: bool)
const TrainerSignal := preload("res://trainer_signal.gd")
const FTP_MAX_PAUSE_SECONDS := 60.0
var signal_state := TrainerSignal.new()
var interrupted_clients := {}
var control_started_at := {}
const Ramp := preload("res://ftp_ramp.gd")
const Trainer := preload("res://trainer_control.gd")
var test = Ramp.new()
var trainer := Trainer.new()
var player_profile = preload("res://player_profile.gd").new()
var ftp_persisted := false
var ftp_save_message := ""
var last_sample := -100.0
var sample_id := -1
var measured := 0.0
var last_speed_kmh := 0.0
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
	return telemetry_ok and signal_state.usable(now)
func live(now: float) -> bool:
	return telemetry_ok and signal_state.live(now)
func session_now(now: float) -> float: return signal_state.time(now)
func reset_session(now: float, client) -> void:
	signal_state.reset_clock(now); interrupted_clients.erase(client.get_instance_id()); control_started_at[client.get_instance_id()] = now
func control_response_at(client) -> float: return maxf(client.last_response,float(control_started_at.get(client.get_instance_id(),-100.0)))
func resume_pending(client) -> bool: return interrupted_clients.has(client.get_instance_id())
func drive_trainer(client, active: bool, grade: float, aero: float, now: float, target: int = 0) -> void:
	var id: int = client.get_instance_id()
	var receiving := live(now)
	var transient: bool = client.owned and client.armed and now-signal_state.last_valid <= TrainerSignal.CONTROL_HOLD_SECONDS
	if not active: interrupted_clients.erase(id)
	elif not receiving and not transient: interrupted_clients[id] = true
	elif interrupted_clients.has(id):
		if client.owned and client.armed: interrupted_clients.erase(id)
		elif client.phase != "RELEASING" and (not client.state.get("udp_owned",false) or client.error == "Geen antwoord van bridge"):
			client.arm(client.allow_released_session); interrupted_clients.erase(id); control_started_at[id] = now
	client.tick(active and fresh(now) and (receiving or transient) and not resume_pending(client),grade,aero,now,target)
func _ftp_pause_expired(now: float) -> bool:
	return test is Ramp and test.running() and signal_state.paused_seconds(now) > FTP_MAX_PAUSE_SECONDS
func receive(packet: Dictionary, now: float) -> void:
	if packet.get("type") != "telemetry": return
	var power: Variant = packet.get("power_w")
	var id: Variant = packet.get("power_sample_id")
	var age: Variant = packet.get("power_age_s")
	bridge_update_needed = not packet.has("power_sample_id") or not packet.has("power_age_s")
	var valid_age: bool = (age is int or age is float) and is_finite(float(age)) and float(age) >= 0
	var numeric: bool = (power is float or power is int) and is_finite(float(power)) and float(power) >= 0
	var valid_id: bool = (id is int or id is float) and is_finite(float(id)) and float(id) >= 0 and floor(float(id)) == float(id)
	if _ftp_pause_expired(now): finish("FTP-test gestopt: pauze langer dan 1 minuut")
	var measured_ok: bool = packet.get("valid") == true and numeric and valid_age and valid_id
	var recovering := not signal_state.live(now)
	var was_paused: bool = signal_state.paused_since >= 0
	signal_state.receive(measured_ok,now)
	if was_paused and measured_ok and test is Ramp: test.interrupt_measurements()
	if not measured_ok: return # Preserve the last good measurement through the same race hold/pause window.
	telemetry_ok = true
	var speed: Variant = packet.get("speed_kmh")
	if (speed is int or speed is float) and is_finite(float(speed)) and float(speed) >= 0: last_speed_kmh = float(speed)
	if int(id) == sample_id: return # Bridge repeats the last FTMS sample at 10 Hz.
	if int(id) < sample_id:
		if not recovering: return # Late UDP frame, not a new measurement.
		if test is Ramp: test.interrupt_measurements()

	sample_id = int(id)
	last_sample = now - float(age)
	measured = float(power)
	var reported_gear: Variant = packet.get("gear")
	gear = int(reported_gear) if (reported_gear is int or reported_gear is float) and is_finite(float(reported_gear)) and float(reported_gear) >= 1 and float(reported_gear) <= 12 else -1
	var rpm: Variant = packet.get("cadence_rpm")
	var cadence: float = float(rpm) if (rpm is int or rpm is float) and is_finite(float(rpm)) else -1.0
	test.sample(session_now(maxf(last_sample,signal_state.resumed_at)), measured, cadence)
	if test.phase == "RESULT": _release(now)

func begin() -> void:
	var now := now_s()
	if test.running() or not live(now) or not release_complete(): return
	ftp_persisted = false
	ftp_save_message = ""
	reset_session(now,trainer)
	test.start(session_now(now))
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
	var clock := session_now(now)
	var receiving := live(now)
	if test.running() and not is_visible_in_tree(): finish("Test verlaten")
	if _ftp_pause_expired(now): finish("FTP-test gestopt: pauze langer dan 1 minuut")
	var target: int = test.target(clock)
	drive_trainer(trainer,test.phase in ["CONNECTING","RAMP"],0,1,now,target)
	if test.running():
		if not receiving or resume_pending(trainer):
			confirmation_since = clock
		elif test.phase == "RAMP" and now-control_response_at(trainer) > 3: finish("Geen antwoord meer van trainerbridge")
		elif not trainer.error.is_empty(): finish("Trainerfout: "+trainer.error)
		if test.running() and fresh(now):
			var state: Dictionary = trainer.state
			var confirmed: bool = receiving and trainer.owned and state.get("mode") == "ERG" and state.get("desired_mode") == "ERG" and state.get("confirmed_target_w") == target and state.get("applied_revision",-1) == state.get("revision",-2)
			if confirmation_target != target: confirmation_target = target; confirmation_since = clock
			if confirmed: confirmation_since = clock
			elif receiving and not resume_pending(trainer) and test.phase != "WARMUP" and clock-confirmation_since > 8: finish("ERG-doel niet bevestigd door trainer")
			test.tick(clock,confirmed)
			if not test.running(): _release(now)
	_refresh()

func _refresh() -> void:
	if start_button == null: return
	start_button.visible = not test.running()
	start_button.disabled = not live(now_s()) or not release_complete()
	stop_button.visible = test.running()
	back_button.disabled = test.running()
	detail.visible = not test.running() and test.phase != "RESULT"
	warmup_hint.visible = test.phase in ["IDLE", "WARMUP"]
	if test.running():
		var elapsed := maxf(0.0, session_now(now_s()) - test.started_at)
		var target_text := "Vrij vermogen" if test.phase == "WARMUP" else "Doel %d W" % test.target(session_now(now_s()))
		var caption := {"WARMUP": "Vrije opwarming", "CONNECTING": "Wacht op ERG-bevestiging", "RAMP": "Ramp Test"}
		result.text = "%s · %02d:%02d\n%s · gemeten %.0f W\nBeste 60 s: %.1f W" % [caption[test.phase], int(elapsed) / 60, int(elapsed) % 60, target_text, measured, test.best_60]
		if test.phase == "WARMUP":
			var remaining := int(ceil(maxf(0.0, Ramp.WARMUP_SECONDS - elapsed)))
			result.text = "Start test over %02d:%02d\n%s · gemeten %.0f W\nSchakelen blijft beschikbaar. Daarna neemt ERG over op 100 W." % [remaining / 60, remaining % 60, target_text, measured]
			if gear > 0: result.text += "\nVersnelling %d / 12" % gear
		var connection_status := signal_state.status(now_s())
		if not connection_status.is_empty(): result.text += "\n"+connection_status
	elif test.phase == "RESULT":
		if test.best_60 > 0 and not ftp_persisted:
			ftp_persisted = true
			ftp_save_message = "FTP opgeslagen in je spelersprofiel." if player_profile.set_ftp(test.ftp(),"ramp_test") == OK else "FTP kon niet worden opgeslagen."
		result.text = "%s\n" % test.reason
		result.text += "Geschatte FTP: %.0f W · beste 60 s: %.1f W" % [test.ftp(), test.best_60] if test.best_60 > 0.0 else "Geen FTP: minder dan 60 seconden aaneengesloten rampmetingen."
		result.text += "\n" + ftp_save_message
		result.text += "\nERG vrijgegeven." if release_complete() else "\nERG-vrijgave nog niet bevestigd. Bridge bewaakt ook de lease."
	else:
		result.text = "Werk de bridge bij voor de FTP-test." if bridge_update_needed else "Trainer gereed." if live(now_s()) else "Wacht op verse trainergegevens."

func shutdown() -> void:
	finish("Spel gesloten")
	trainer.close()

func _notification(what: int) -> void:
	# Moving the HUD between menu and session containers also exits the tree.
	# Only actual deletion closes the socket; a layout move must keep warmup alive.
	if what == NOTIFICATION_PREDELETE:
		test.stop("Spel gesloten")
		trainer.close()
