extends VBoxContainer
signal upload_requested(activity: Dictionary)
signal back_requested
signal environment_requested(active: bool)
const Skin := preload("res://menu_theme.gd")
var ramp_dashboard: Control
var ramp_left: Label
var ramp_live: Label
var ramp_ftp: Label
var ramp_graph: Control
var ramp_samples: Array[Dictionary] = []
var ramp_step_stats: Dictionary = {}
var ramp_last_measurement_at := -1.0
var ramp_last_power := 0.0
var ramp_last_hr := -1.0
var heart_rate_bpm := -1.0

func _dashboard_panel(parent: Control, left: float, right: float, top: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = 0.0 if left >= 0 else 1.0
	panel.anchor_right = 0.0 if right >= 0 else 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = left
	panel.offset_right = right
	panel.offset_top = top
	panel.offset_bottom = bottom
	panel.add_theme_stylebox_override("panel", Skin.panel(Skin.PAPER, Skin.LINE, 14))
	return panel

func _dashboard_label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Skin.INK)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build_ramp_dashboard() -> void:
	ramp_dashboard = Control.new()
	ramp_dashboard.custom_minimum_size = Vector2(1200, 650)
	ramp_dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ramp_dashboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ramp_dashboard)
	var left := _dashboard_panel(ramp_dashboard, 24, 320, 90, 470)
	var left_scroll := ScrollContainer.new()
	left.add_child(left_scroll)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ramp_left = _dashboard_label(left_scroll, 17)
	var middle := _dashboard_panel(ramp_dashboard, 340, -340, 90, 210)
	ramp_live = _dashboard_label(middle, 22)
	var right := _dashboard_panel(ramp_dashboard, -320, -24, 90, 260)
	ramp_ftp = _dashboard_label(right, 23)
	var bottom := PanelContainer.new()
	ramp_dashboard.add_child(bottom)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -215
	bottom.offset_bottom = -20
	bottom.add_theme_stylebox_override("panel", Skin.panel(Skin.PAPER, Skin.LINE, 10))
	ramp_graph = preload("res://ftp_ramp_profile_graph.gd").new()
	bottom.add_child(ramp_graph)
	ramp_dashboard.hide()

func _reset_ramp_dashboard() -> void:
	ramp_samples.clear()
	ramp_step_stats.clear()
	ramp_last_measurement_at = -1.0
	ramp_last_power = 0.0
	ramp_last_hr = -1.0

func _record_ramp_sample(at: float, power: float) -> void:
	if twenty_mode or not test.running(): return
	var elapsed: float = maxf(0.0, at - test.started_at)
	# The ramp's started_at is reset on transition; keep an absolute display clock
	# anchored to the signal clock independently of the protocol.
	if ramp_last_measurement_at >= 0.0:
		var dt := at - ramp_last_measurement_at
		if dt > 0.0 and dt <= TrainerSignal.HOLD_SECONDS:
			var key := -1 if test.phase == "WARMUP" else int(maxf(0.0, ramp_last_measurement_at-test.ramp_at)/60.0) if test.ramp_at >= 0.0 else -2
			if key >= -1:
				var entry: Dictionary = ramp_step_stats.get(key, {"seconds":0.0,"energy":0.0,"hr_seconds":0.0,"hr_total":0.0})
				entry.seconds += dt
				entry.energy += dt*ramp_last_power
				if ramp_last_hr > 0.0:
					entry.hr_seconds += dt
					entry.hr_total += dt*ramp_last_hr
				ramp_step_stats[key] = entry
	ramp_last_measurement_at = at
	ramp_last_power = power
	ramp_last_hr = heart_rate_bpm
	var chart_time := maxf(0.0, at - ramp_chart_start)
	if ramp_samples.is_empty() or chart_time > float(ramp_samples[-1].t):
		ramp_samples.append({"t":chart_time,"w":power})
	if ramp_samples.size() > 12000: ramp_samples.pop_front()

var ramp_chart_start := 0.0
func _refresh_ramp_dashboard() -> void:
	if ramp_dashboard == null: return
	var visible_now: bool = not twenty_mode and test.running()
	ramp_dashboard.visible = visible_now
	result.visible = not visible_now
	if not visible_now: return
	var clock := session_now(now_s())
	var elapsed := maxf(0.0,clock-ramp_chart_start)
	var ramp_start := test.ramp_at-ramp_chart_start if test.ramp_at >= 0.0 else -1.0
	var target := test.target(clock)
	var hr_text := "%d bpm" % roundi(heart_rate_bpm) if heart_rate_bpm > 0.0 and live(now_s()) else "— bpm"
	var rpm_text := cadence_text()
	ramp_live.text = "SNELHEID  %.1f km/u       VERMOGEN  %.0f W\nCADANS  %s       HARTSLAG  %s\n%s" % [last_speed_kmh,measured,rpm_text,hr_text,"Opwarming · vrij rijden" if test.phase == "WARMUP" else "Doel %d W" % target]
	ramp_ftp.text = "VOORLOPIGE FTP\n%s\nBeste 60 s: %.1f W\n75%% van beste 60 s" % ["%.0f W" % test.ftp() if test.best_60 > 0.0 else "— W",test.best_60]
	var rows := "AFGELEGDE STAPPEN\nDoel       Gem. W    Gem. HR\n"
	var current_key := -1 if test.phase == "WARMUP" else int(maxf(0.0,clock-test.ramp_at)/60.0) if test.ramp_at >= 0.0 else -2
	for key in range(current_key,-2,-1):
		if key == -2: continue
		var stat: Dictionary = ramp_step_stats.get(key,{})
		var power_text := "%.0f" % (float(stat.get("energy",0.0))/float(stat.get("seconds",1.0))) if float(stat.get("seconds",0.0)) > 0 else "—"
		var heart_text := "%.0f" % (float(stat.get("hr_total",0.0))/float(stat.get("hr_seconds",1.0))) if float(stat.get("hr_seconds",0.0)) > 0 else "—"
		rows += "%s%s     %s W    %s bpm\n" % ["> " if key == current_key else "  ","Opwarming" if key == -1 else "%d W" % (100+20*key),power_text,heart_text]
	ramp_left.text = rows
	ramp_graph.update_profile(ramp_samples,elapsed,ramp_start,true)

const TrainerSignal := preload("res://trainer_signal.gd")
const FTP_MAX_PAUSE_SECONDS := 60.0
var signal_state := TrainerSignal.new()
var interrupted_clients := {}
var control_started_at := {}
const Twenty := preload("res://ftp_twenty_min.gd")
var twenty_mode := false
const Ramp := preload("res://ftp_ramp.gd")
const Trainer := preload("res://trainer_control.gd")
var test: Variant = Ramp.new()
var trainer := Trainer.new()
var player_profile = preload("res://player_profile.gd").new()
var upload_button: Button
var upload_status := ""
var selected_activity: Dictionary = {}
var activity_samples: Array[Dictionary] = []
var activity_distance := 0.0
var activity_started_unix := 0
var result_view_restored := false
func _record_activity(at: float, power: float) -> void:
	if not test.running(): return
	var elapsed := maxf(0.0,at-ramp_chart_start)
	var speed := maxf(0.0,last_speed_kmh)
	if not activity_samples.is_empty():
		var dt: float = elapsed-float(activity_samples[-1].time_s)
		if dt > 0.0 and dt <= TrainerSignal.HOLD_SECONDS:
			activity_distance += dt*speed/3.6
	if not activity_samples.is_empty() and elapsed-float(activity_samples[-1].time_s) < 1.0: return
	activity_samples.append({"time_s":elapsed,"distance_m":activity_distance,"game_speed_kmh":speed,"power_w":power,"cadence_rpm":cadence_rpm,"heart_rate_bpm":heart_rate_bpm if heart_rate_bpm > 0 else null})
func _complete_activity() -> void:
	if not selected_activity.is_empty() or activity_samples.size() < 2: return
	selected_activity = {"version":1,"id":"ftp_%d" % activity_started_unix,"kind":"ftp_test","title":"FTP 20 minuten" if twenty_mode else "FTP Ramp Test","reason":test.reason,"started_unix":activity_started_unix,"duration_s":float(activity_samples[-1].time_s),"distance_m":activity_distance,"samples":activity_samples.duplicate(true),"ftp_w":test.ftp()}
	var store := preload("res://training_store.gd").new()
	upload_status = "Training lokaal opgeslagen." if store.save(selected_activity) else store.error

var ftp_persisted := false
var ftp_save_message := ""
var last_sample := -100.0
var sample_id := -1
var measured := 0.0
var cadence_rpm := -1.0
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
	upload_button = _button("Opslaan op Strava", func(): upload_requested.emit(selected_activity))
	back_button = _button("← Training", leave)
	_build_ramp_dashboard()
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
	return (test is Ramp or test is Twenty) and test.running() and signal_state.paused_seconds(now) > FTP_MAX_PAUSE_SECONDS
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
	if twenty_mode and test.running(): test.tick(session_now(now))
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
	var hr_value: Variant = packet.get("heart_rate_bpm", packet.get("hr_bpm", null))
	heart_rate_bpm = float(hr_value) if (hr_value is int or hr_value is float) and is_finite(float(hr_value)) and float(hr_value) > 0 else -1.0
	var reported_gear: Variant = packet.get("gear")
	gear = int(reported_gear) if (reported_gear is int or reported_gear is float) and is_finite(float(reported_gear)) and float(reported_gear) >= 1 and float(reported_gear) <= 12 else -1
	var rpm: Variant = packet.get("cadence_rpm")
	cadence_rpm = float(rpm) if (rpm is int or rpm is float) and is_finite(float(rpm)) and float(rpm) >= 0.0 else -1.0
	_record_ramp_sample(session_now(maxf(last_sample,signal_state.resumed_at)), measured)
	_record_activity(session_now(maxf(last_sample,signal_state.resumed_at)), measured)
	test.sample(session_now(maxf(last_sample,signal_state.resumed_at)), measured, cadence_rpm)
	if test.phase == "RESULT": _release(now)

func begin() -> void:
	result_view_restored = false
	selected_activity = {}
	activity_samples.clear()
	activity_distance = 0.0
	activity_started_unix = int(Time.get_unix_time_from_system())
	if twenty_mode:
		_begin_twenty()
		return
	var now := now_s()
	if test.running() or not live(now) or not release_complete(): return
	ftp_persisted = false
	ftp_save_message = ""
	reset_session(now,trainer)
	_reset_ramp_dashboard()
	ramp_chart_start = session_now(now)
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
	if twenty_mode:
		if test.running():
			if not is_visible_in_tree(): finish("Test verlaten")
			if _ftp_pause_expired(now_s()): finish("FTP-test gestopt: pauze langer dan 1 minuut")
			else: test.tick(session_now(now_s()))
		_release(now_s())
		_refresh()
		return
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

func _restore_result_navigation() -> void:
	if test.phase != "RESULT" or result_view_restored: return
	_complete_activity()
	result_view_restored = true
	# Return from the in-race session container to the normal training menu.
	# This exposes the Back button and the result without requiring another ride.
	environment_requested.emit(false)
	if back_button != null:
		back_button.show()
		back_button.disabled = false
		back_button.grab_focus.call_deferred()

func cadence_text() -> String:
	return "%d rpm" % roundi(cadence_rpm) if live(now_s()) and cadence_rpm >= 0.0 else "— rpm"

func _refresh() -> void:
	_restore_result_navigation()
	if upload_button != null:
		upload_button.visible = test.phase == "RESULT" and not selected_activity.is_empty()
		upload_button.disabled = activity_samples.size() < 2
	_refresh_ramp_dashboard()
	if twenty_mode:
		_refresh_twenty()
		return
	if start_button == null: return
	start_button.visible = not test.running()
	start_button.disabled = not live(now_s()) or not release_complete()
	stop_button.visible = test.running()
	back_button.disabled = test.running()
	back_button.visible = true
	detail.visible = not test.running() and test.phase != "RESULT"
	warmup_hint.visible = test.phase == "IDLE"
	if test.running():
		var elapsed := maxf(0.0, session_now(now_s()) - test.started_at)
		var target_text := "Vrij vermogen" if test.phase == "WARMUP" else "Doel %d W" % test.target(session_now(now_s()))
		var caption := {"WARMUP": "Vrije opwarming", "CONNECTING": "Wacht op ERG-bevestiging", "RAMP": "Ramp Test"}
		result.text = "%s · %02d:%02d\n%s · gemeten %.0f W\nBeste 60 s: %.1f W" % [caption[test.phase], int(elapsed) / 60, int(elapsed) % 60, target_text, measured, test.best_60]
		if test.phase == "WARMUP":
			var remaining := int(ceil(maxf(0.0, Ramp.WARMUP_SECONDS - elapsed)))
			result.text = "Start test over %02d:%02d\n%s · gemeten %.0f W\nSchakelen blijft beschikbaar. Daarna neemt ERG over op 100 W." % [remaining / 60, remaining % 60, target_text, measured]
			if gear > 0: result.text += "\nVersnelling %d / 12" % gear
		result.text += "\nCadans · " + cadence_text()
		var connection_status := signal_state.status(now_s())
		if not connection_status.is_empty(): result.text += "\n"+connection_status
	elif test.phase == "RESULT":
		if test.best_60 > 0 and not ftp_persisted:
			ftp_persisted = true
			ftp_save_message = "FTP opgeslagen in je spelersprofiel." if player_profile.set_ftp(test.ftp(),"ramp_test") == OK else "FTP kon niet worden opgeslagen."
		result.text = "%s\n" % test.reason
		result.text += "Geschatte FTP: %.0f W · beste 60 s: %.1f W" % [test.ftp(), test.best_60] if test.best_60 > 0.0 else "Geen FTP: minder dan 60 seconden aaneengesloten rampmetingen."
		result.text += "\n" + ftp_save_message + "\n" + upload_status
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

func select_test(twenty: bool) -> void:
	if test.running(): finish("Test verlaten")
	twenty_mode = twenty
	test = Twenty.new() if twenty else Ramp.new()
	ftp_persisted = false
	ftp_save_message = ""
	title.text = "20’ FTP-test" if twenty else "FTP Ramp Test"
	if twenty:
		detail.text = "Warm eerst goed op. Rijd daarna 20 minuten op het hoogste vermogen dat je gelijkmatig kunt volhouden.\nJe kiest zelf je versnelling en vermogen; ERG blijft uit.\nFTP = 95% van het gemiddelde gemeten vermogen over de volledige 20 minuten.\nEen echte trainer met verse vermogensmetingen is vereist. Bij signaalverlies wordt het laatste vermogen maximaal 10 seconden behouden. Daarna pauzeert de test; bij een pauze langer dan 1 minuut stopt hij. Bij voortijdig stoppen blijft je bestaande FTP behouden."
	else:
		detail.text = "5 minuten vrij opwarmen op je eigen vermogen, zonder ERG-doel.\nDaarna 100 W, elke minuut +20 W. Blijf zitten en trap gelijkmatig.\nStop zodra je niet meer kunt. FTP = 75% van je beste gemeten 60 seconden.\nEen echte trainer met verse vermogensmetingen is vereist."
	stop_button.text = "Stop test" if twenty else "Stop test · ERG vrijgeven"
	_refresh()

func _twenty_fresh(now: float) -> bool:
	return live(now) and now - last_sample >= 0.0 and now - last_sample <= TrainerSignal.LIVE_SECONDS

func _begin_twenty() -> void:
	result_view_restored = false
	selected_activity = {}
	activity_samples.clear()
	activity_distance = 0.0
	activity_started_unix = int(Time.get_unix_time_from_system())
	ramp_chart_start = session_now(now_s())
	var now := now_s()
	if test.running() or not _twenty_fresh(now) or not release_complete(): return
	ftp_persisted = false
	ftp_save_message = ""
	reset_session(now,trainer)
	test.start(session_now(now))
	# Seed the interval with the latest fresh measurement, without charging warmup.
	test.sample(session_now(now), measured)
	_refresh()
	environment_requested.emit(true)
	stop_button.grab_focus()

func _refresh_twenty() -> void:
	_restore_result_navigation()
	if upload_button != null:
		upload_button.visible = test.phase == "RESULT" and not selected_activity.is_empty()
		upload_button.disabled = activity_samples.size() < 2
	if start_button == null: return
	start_button.visible = not test.running()
	start_button.disabled = not _twenty_fresh(now_s()) or not release_complete()
	stop_button.visible = test.running()
	back_button.disabled = test.running()
	warmup_hint.hide()
	detail.visible = not test.running() and test.phase != "RESULT"
	if test.running():
		var remaining := ceili(maxf(0.0,Twenty.DURATION-(session_now(now_s())-test.start_at)))
		var mean: float = test.energy / test.covered if test.covered > 0 else measured
		result.text = "20 minuten FTP-test · nog %02d:%02d\nGemeten %.0f W · gemiddeld %.1f W\nVrij vermogen · ERG uit · %s" % [remaining/60,remaining%60,measured,mean,cadence_text()]
		if gear > 0: result.text += "\nVersnelling %d / 12" % gear
		var connection_status := signal_state.status(now_s())
		if not connection_status.is_empty(): result.text += "\n" + connection_status
	elif test.phase == "RESULT":
		result.text = test.reason
		if test.complete():
			if not ftp_persisted:
				ftp_persisted = true
				ftp_save_message = "FTP opgeslagen in je spelersprofiel." if player_profile.set_ftp(test.ftp(),"twenty_minute_test") == OK else "FTP kon niet worden opgeslagen."
			result.text += "\nGemiddeld %.1f W · geschatte FTP %.0f W\n%s" % [test.average_power(),test.ftp(),ftp_save_message + "\n" + upload_status]
		else: result.text += "\nGeen volledige test; je bestaande FTP blijft behouden."
	else:
		result.text = "Werk de bridge bij voor de FTP-test." if bridge_update_needed else "Trainer gereed. Warm eerst op; Start begint direct aan de 20 minuten." if _twenty_fresh(now_s()) else "Wacht op verse trainergegevens."
