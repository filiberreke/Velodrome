extends VBoxContainer
signal upload_requested(activity: Dictionary)
signal back_requested
signal environment_requested(active: bool)
const HudTheme := preload("res://menu_theme.gd")
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
var twenty_warmup := false
var twenty_warmup_at := 0.0
var twenty_reference_w := 0.0

func _reset_ramp_dashboard() -> void:
	ramp_samples.clear()
	ramp_step_stats.clear()
	ramp_last_measurement_at = -1.0
	ramp_last_power = 0.0
	ramp_last_hr = -1.0

func _record_ramp_sample(at: float, power: float) -> void:
	if twenty_mode or not (test is Ramp) or not test.running(): return
	if ramp_last_measurement_at >= 0.0:
		var dt := at - ramp_last_measurement_at
		if dt > 0.0 and dt <= TrainerSignal.HOLD_SECONDS:
			var key: int = -1 if test.phase == "WARMUP" else int(maxf(0.0, ramp_last_measurement_at-test.ramp_at)/60.0) if test.ramp_at >= 0.0 else -2
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
		ramp_samples.append({"t":chart_time,"w":power,"hr":heart_rate_bpm,"rpm":cadence_rpm})
	if ramp_samples.size() > 12000: ramp_samples.pop_front()

var ramp_chart_start := 0.0
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
var activity_started_local := ""
var result_view_restored := false
func _record_activity(at: float, power: float) -> void:
	if not test.running() and not twenty_warmup: return
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
	selected_activity = {"version":1,"started_local":activity_started_local,"id":"ftp_%d" % activity_started_unix,"kind":"ftp_test","demo":activity_virtual,"title":String(TranslationServer.translate("FTP_20_MINUTE_FTP")) if twenty_mode else String(TranslationServer.translate("MENU_FTP_RAMP_TEST_2")),"reason":test.reason,"started_unix":activity_started_unix,"duration_s":float(activity_samples[-1].time_s),"distance_m":activity_distance,"samples":activity_samples.duplicate(true),"ftp_w":test.ftp(),"ftp_reference_w":player_profile.ftp()}
	var store := preload("res://training_store.gd").new()
	upload_status = String(TranslationServer.translate("FTP_TRAINING_SAVED_LOCALLY")) if store.save(selected_activity) else store.error
	get_node("/root/ActivityUploads").capture_training(selected_activity, activity_virtual)

var ftp_persisted := false
var ftp_save_message := ""
var last_sample := -100.0
var sample_id := -1
var measured := 0.0
var cadence_rpm := -1.0
var last_speed_kmh := 0.0
var gear := -1
var telemetry_ok := false
var activity_virtual := false
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
	title = _label("MENU_FTP_RAMP_TEST_2", 38)
	detail = _label("FTP_WARM_UP_FOR_5_MINUTES_AT_YOUR_OWN_POWER_WITHOUT_AN_ERG_TARGET_THEN_100", 24)
	result = _label("", 30)
	warmup_hint = _label("FTP_SUGGESTED_POWER_AROUND_80_120_W_OR_LOWER_IF_MORE_COMFORTABLE_THIS_IS_O", 22)
	start_button = _button("FTP_START_FTP_TEST", begin)
	stop_button = _button("FTP_STOP_TEST_RELEASE_ERG", func(): finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY"))))
	upload_button = _button("PISTE_EXERCISE_PAGE_SAVE_TO_STRAVA", func(): upload_requested.emit(selected_activity))
	back_button = _button("WORKOUT_EDITOR_ERG_TRAINING", leave)
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
func drive_trainer(client, active: bool, grade: float, aero: float, now: float, target: int = 0, grade_rate: float = 10.0) -> void:
	var id: int = client.get_instance_id()
	var receiving := live(now)
	var transient: bool = client.owned and client.armed and now-signal_state.last_valid <= TrainerSignal.CONTROL_HOLD_SECONDS
	if not active: interrupted_clients.erase(id)
	elif not receiving and not transient: interrupted_clients[id] = true
	elif interrupted_clients.has(id):
		if client.owned and client.armed: interrupted_clients.erase(id)
		elif client.phase != "RELEASING" and (not client.state.get("udp_owned",false) or client.error == "FTP_NO_RESPONSE_FROM_BRIDGE"):
			client.arm(client.allow_released_session); interrupted_clients.erase(id); control_started_at[id] = now
	client.grade_rate = grade_rate
	client.tick(active and fresh(now) and (receiving or transient) and not resume_pending(client),grade,aero,now,target)
func _ftp_pause_expired(now: float) -> bool:
	return (test.running() or twenty_warmup) and signal_state.paused_seconds(now) > FTP_MAX_PAUSE_SECONDS
func receive(packet: Dictionary, now: float) -> void:
	if packet.get("type") != "telemetry": return
	activity_virtual = packet.get("virtual", false) == true
	var power: Variant = packet.get("power_w")
	var id: Variant = packet.get("power_sample_id")
	var age: Variant = packet.get("power_age_s")
	bridge_update_needed = not packet.has("power_sample_id") or not packet.has("power_age_s")
	var valid_age: bool = (age is int or age is float) and is_finite(float(age)) and float(age) >= 0
	var numeric: bool = (power is float or power is int) and is_finite(float(power)) and float(power) >= 0
	var valid_id: bool = (id is int or id is float) and is_finite(float(id)) and float(id) >= 0 and floor(float(id)) == float(id)
	if _ftp_pause_expired(now): finish(String(TranslationServer.translate("FTP_FTP_TEST_STOPPED_PAUSE_LONGER_THAN_1_MINUTE")))
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
	var sample_clock: float = session_now(maxf(last_sample,signal_state.resumed_at))
	if twenty_mode and (twenty_warmup or test.running()):
		var chart_time: float = maxf(0.0,sample_clock-ramp_chart_start)
		if ramp_samples.is_empty() or chart_time > float(ramp_samples[-1].t):
			ramp_samples.append({"t":chart_time,"w":measured,"hr":heart_rate_bpm,"rpm":cadence_rpm})
	else:
		_record_ramp_sample(sample_clock, measured)
	_record_activity(sample_clock, measured)
	if not twenty_warmup: test.sample(sample_clock, measured, cadence_rpm)
	if test.phase == "RESULT": _release(now)

func begin() -> void:
	result_view_restored = false
	selected_activity = {}
	activity_samples.clear()
	activity_distance = 0.0
	activity_started_unix = int(Time.get_unix_time_from_system())
	activity_started_local = Time.get_datetime_string_from_system().replace("T"," ")
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
	if twenty_warmup and test is Twenty:
		# Early stopping during warmup produces a result but never changes FTP.
		test.start(session_now(now_s()))
	twenty_warmup = false
	test.stop(reason)
	_release(now_s())
	_refresh()

func leave() -> void:
	finish(String(TranslationServer.translate("MENU_EXIT_TEST")))
	environment_requested.emit(false)
	back_requested.emit()

func _process(_delta: float) -> void:
	if twenty_mode:
		if twenty_warmup:
			if _ftp_pause_expired(now_s()) or not is_visible_in_tree(): finish(String(TranslationServer.translate("FTP_FTP_TEST_STOPPED_PAUSED_OR_EXITED")))
			var warm_now: float = session_now(now_s())
			if twenty_warmup and warm_now - twenty_warmup_at >= Ramp.WARMUP_SECONDS:
				twenty_warmup = false
				test.start(warm_now)
				# The warmup is excluded from the FTP test average.
				test.sample(warm_now, measured)
		if test.running():
			if not is_visible_in_tree(): finish(String(TranslationServer.translate("MENU_EXIT_TEST")))
			if _ftp_pause_expired(now_s()): finish(String(TranslationServer.translate("FTP_FTP_TEST_STOPPED_PAUSE_LONGER_THAN_1_MINUTE")))
			else: test.tick(session_now(now_s()))
		_release(now_s())
		_refresh()
		return
	var now := now_s()
	var clock := session_now(now)
	var receiving := live(now)
	if test.running() and not is_visible_in_tree(): finish(String(TranslationServer.translate("MENU_EXIT_TEST")))
	if _ftp_pause_expired(now): finish(String(TranslationServer.translate("FTP_FTP_TEST_STOPPED_PAUSE_LONGER_THAN_1_MINUTE")))
	var target: int = test.target(clock)
	drive_trainer(trainer,test.phase in ["CONNECTING","RAMP"],0,1,now,target)
	if test.running():
		if not receiving or resume_pending(trainer):
			confirmation_since = clock
		elif test.phase == "RAMP" and now-control_response_at(trainer) > 3: finish(String(TranslationServer.translate("FTP_TRAINER_BRIDGE_NO_LONGER_RESPONDING")))
		elif not trainer.error.is_empty(): finish("Trainerfout: "+tr(trainer.error))
		if test.running() and fresh(now):
			var state: Dictionary = trainer.state
			var confirmed: bool = receiving and trainer.owned and state.get("mode") == "ERG" and state.get("desired_mode") == "ERG" and state.get("confirmed_target_w") == target and state.get("applied_revision",-1) == state.get("revision",-2)
			if confirmation_target != target: confirmation_target = target; confirmation_since = clock
			if confirmed: confirmation_since = clock
			elif receiving and not resume_pending(trainer) and test.phase != "WARMUP" and clock-confirmation_since > 8: finish(String(TranslationServer.translate("FTP_ERG_TARGET_NOT_CONFIRMED_BY_TRAINER")))
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
		back_button.disabled = false
		if is_visible_in_tree(): back_button.grab_focus.call_deferred()

func cadence_text() -> String:
	return "%d rpm" % roundi(cadence_rpm) if live(now_s()) and cadence_rpm >= 0.0 else "— rpm"

func _refresh() -> void:
	_restore_result_navigation()
	if upload_button != null:
		upload_button.visible = test.phase == "RESULT" and not selected_activity.is_empty()
		upload_button.disabled = activity_samples.size() < 2
	if twenty_mode:
		_refresh_twenty()
		return
	if start_button == null: return
	start_button.visible = not test.running()
	start_button.disabled = not live(now_s()) or not release_complete()
	stop_button.visible = test.running()
	back_button.disabled = test.running()
	# The menu owns visibility after moving this button into the shared header.
	detail.visible = not test.running() and test.phase != "RESULT"
	warmup_hint.visible = test.phase == "IDLE"
	if test.running():
		var elapsed := maxf(0.0, session_now(now_s()) - test.started_at)
		var target_text := String(TranslationServer.translate("FTP_SELF_PACED_POWER")) if test.phase == "WARMUP" else "Doel %d W" % test.target(session_now(now_s()))
		var caption := {"WARMUP": String(TranslationServer.translate("FTP_FREE_WARM_UP")), "CONNECTING": String(TranslationServer.translate("FTP_WAIT_FOR_ERG_CONFIRMATION")), "RAMP": "Ramp Test"}
		result.text = String(TranslationServer.translate("FTP_S_02D_02D_S_MEASURED_0F_W_BEST_60_S_1F_W")) % [caption[test.phase], int(elapsed) / 60, int(elapsed) % 60, target_text, measured, test.best_60]
		if test.phase == "WARMUP":
			var remaining := int(ceil(maxf(0.0, Ramp.WARMUP_SECONDS - elapsed)))
			result.text = String(TranslationServer.translate("FTP_TEST_STARTS_IN_02D_02D_S_MEASURED_0F_W_GEAR_SHIFTING_REMAINS_AVAILABLE")) % [remaining / 60, remaining % 60, target_text, measured]
			if gear > 0: result.text += "\nVersnelling %d / 12" % gear
		result.text += "\nCadans · " + cadence_text()
		var connection_status := signal_state.status(now_s())
		if not connection_status.is_empty(): result.text += "\n"+connection_status
	elif test.phase == "RESULT":
		if test.best_60 > 0 and not ftp_persisted:
			ftp_persisted = true
			ftp_save_message = String(TranslationServer.translate("FTP_FTP_SAVED_IN_YOUR_PLAYER_PROFILE")) if player_profile.set_ftp(test.ftp(),"ramp_test") == OK else String(TranslationServer.translate("FTP_FTP_COULD_NOT_BE_SAVED"))
		result.text = "%s\n" % TranslationServer.translate(test.reason)
		result.text += String(TranslationServer.translate("FTP_ESTIMATED_FTP_0F_W_BEST_60_S_1F_W")) % [test.ftp(), test.best_60] if test.best_60 > 0.0 else String(TranslationServer.translate("FTP_NO_FTP_FEWER_THAN_60_SECONDS_OF_CONSECUTIVE_RAMP_READINGS"))
		result.text += "\n" + ftp_save_message + "\n" + upload_status
		result.text += String(TranslationServer.translate("FTP_ERG_RELEASED")) if release_complete() else String(TranslationServer.translate("FTP_ERG_RELEASE_NOT_YET_CONFIRMED_THE_BRIDGE_ALSO_MONITORS_THE_LEASE"))
	else:
		result.text = "FTP_UPDATE_THE_BRIDGE_FOR_THE_FTP_TEST" if bridge_update_needed else "FTP_TRAINER_READY" if live(now_s()) else "FTP_WAIT_FOR_FRESH_TRAINER_DATA"

func shutdown() -> void:
	finish(String(TranslationServer.translate("MAIN_GAME_CLOSED")))
	trainer.close()

func _notification(what: int) -> void:
	# Moving the HUD between menu and session containers also exits the tree.
	# Only actual deletion closes the socket; a layout move must keep warmup alive.
	if what == NOTIFICATION_PREDELETE:
		test.stop(String(TranslationServer.translate("MAIN_GAME_CLOSED")))
		trainer.close()

func select_test(twenty: bool) -> void:
	twenty_warmup = false
	if test.running() or twenty_warmup: finish(String(TranslationServer.translate("MENU_EXIT_TEST")))
	twenty_mode = twenty
	test = Twenty.new() if twenty else Ramp.new()
	ftp_persisted = false
	ftp_save_message = ""
	title.text = "MENU_20_MINUTE_FTP_TEST" if twenty else "MENU_FTP_RAMP_TEST_2"
	if twenty:
		detail.text = "FTP_FIRST_WARM_UP_FREELY_FOR_5_MINUTES_THEN_RIDE_FOR_20_MINUTES_AT_THE_HIG"
	else:
		detail.text = "FTP_WARM_UP_FOR_5_MINUTES_AT_YOUR_OWN_POWER_WITHOUT_AN_ERG_TARGET_THEN_100"
	stop_button.text = "FTP_RAMP_HUD_STOP_TEST" if twenty else "FTP_STOP_TEST_RELEASE_ERG"
	_refresh()

func _twenty_fresh(now: float) -> bool:
	return live(now) and now - last_sample >= 0.0 and now - last_sample <= TrainerSignal.LIVE_SECONDS

func _begin_twenty() -> void:
	result_view_restored = false
	selected_activity = {}
	activity_samples.clear()
	ramp_samples.clear()
	activity_distance = 0.0
	activity_started_unix = int(Time.get_unix_time_from_system())
	var now := now_s()
	if test.running() or twenty_warmup or not _twenty_fresh(now) or not release_complete(): return
	ftp_persisted = false
	ftp_save_message = ""
	reset_session(now,trainer)
	ramp_chart_start = session_now(now)
	twenty_warmup_at = session_now(now)
	twenty_warmup = true
	twenty_reference_w = 0.95 * player_profile.ftp()
	_refresh()
	environment_requested.emit(true)
	stop_button.grab_focus()

func _refresh_twenty() -> void:
	_restore_result_navigation()
	if upload_button != null:
		upload_button.visible = test.phase == "RESULT" and not selected_activity.is_empty()
		upload_button.disabled = activity_samples.size() < 2
	if start_button == null: return
	start_button.visible = not test.running() and not twenty_warmup
	start_button.disabled = not _twenty_fresh(now_s()) or not release_complete()
	stop_button.visible = test.running() or twenty_warmup
	back_button.disabled = test.running() or twenty_warmup
	warmup_hint.hide()
	detail.visible = not test.running() and test.phase != "RESULT"
	if twenty_warmup:
		var remaining_warm: int = ceili(maxf(0.0,Ramp.WARMUP_SECONDS-(session_now(now_s())-twenty_warmup_at)))
		result.text = String(TranslationServer.translate("FTP_FREE_WARM_UP_02D_02D_REMAINING_THEN_20_MINUTES_SELF_PACED_POWER_GUIDE_")) % [remaining_warm/60,remaining_warm%60,twenty_reference_w]
	elif test.running():
		var remaining := ceili(maxf(0.0,Twenty.DURATION-(session_now(now_s())-test.start_at)))
		var mean: float = test.energy / test.covered if test.covered > 0 else measured
		result.text = String(TranslationServer.translate("FTP_20_MINUTE_FTP_TEST_02D_02D_REMAINING_MEASURED_0F_W_AVERAGE_1F_W_SELF_P")) % [remaining/60,remaining%60,measured,mean,cadence_text()]
		if gear > 0: result.text += "\nVersnelling %d / 12" % gear
		var connection_status := signal_state.status(now_s())
		if not connection_status.is_empty(): result.text += "\n" + connection_status
	elif test.phase == "RESULT":
		result.text = TranslationServer.translate(test.reason)
		if test.complete():
			if not ftp_persisted:
				ftp_persisted = true
				ftp_save_message = String(TranslationServer.translate("FTP_FTP_SAVED_IN_YOUR_PLAYER_PROFILE")) if player_profile.set_ftp(test.ftp(),"twenty_minute_test") == OK else String(TranslationServer.translate("FTP_FTP_COULD_NOT_BE_SAVED"))
			result.text += String(TranslationServer.translate("FTP_AVERAGE_1F_W_ESTIMATED_FTP_0F_W_S")) % [test.average_power(),test.ftp(),ftp_save_message + "\n" + upload_status]
		else: result.text += String(TranslationServer.translate("FTP_TEST_INCOMPLETE_YOUR_EXISTING_FTP_IS_RETAINED"))
	else:
		result.text = "FTP_UPDATE_THE_BRIDGE_FOR_THE_FTP_TEST" if bridge_update_needed else "FTP_TRAINER_READY_START_BEGINS_WITH_5_MINUTES_OF_FREE_WARM_UP" if _twenty_fresh(now_s()) else "FTP_WAIT_FOR_FRESH_TRAINER_DATA"
