extends "res://ftp_training.gd"
signal edit_requested(id: String)
const Run := preload("res://workout_run.gd")
var menu
var workout_id := ""
var item := {}
var ftp_input: SpinBox
var ftp_caption: Label
var edit_button: Button
var confirmation_at := 0.0
var desired_target := -1
var previous_free := false
var last_session_clock := 0.0
var active_environment := false
func _ready() -> void:
	test = Run.new()
	trainer.erg_only = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",14)
	title = _label("Workout",34)
	detail = _label("",22)
	var caption := _label("WORKOUT_FTP_FOR_THIS_WORKOUT_W",20)
	ftp_caption = caption
	caption.tooltip_text = "WORKOUT_DEFAULTS_TO_YOUR_PLAYER_FTP_CHANGES_HERE_APPLY_ONLY_TO_THIS_WORKOUT"
	ftp_input = SpinBox.new()
	ftp_input.min_value = 20; ftp_input.max_value = 1000; ftp_input.step = 1
	add_child(ftp_input)
	result = _label("",24)
	start_button = _button("WORKOUT_START_WORKOUT",begin)
	edit_button = _button("WORKOUT_EDIT",func(): edit_requested.emit(workout_id))
	stop_button = _button("WORKOUT_STOP_RELEASE_ERG",func(): finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY"))))
	back_button = _button("WORKOUT_EDITOR_ERG_TRAINING",leave)
	_refresh()
func load_workout(workout: Dictionary) -> void:
	item = workout
	workout_id = str(item.id)
	test.load_workout(item)
	if has_meta("preparation_card"):
		get_meta("preparation_card").preview.set_workout(item.blocks)
	ftp_input.value = player_profile.ftp()
	title.text = str(item.name)
	detail.text = String(TranslationServer.translate("WORKOUT_D_BLOCKS_D_MINUTES_YOUR_PROFILE_FTP_IS_USED_BY_DEFAULT_YOU_CAN_OVERRID")) % [item.blocks.size(),int(ceil(test.duration()/60))]
	_refresh()
func begin() -> void:
	var now := now_s()
	if test.running(): return
	if not live(now): result.text = "WORKOUT_WAIT_FOR_FRESH_POWER_READINGS"; return
	if not release_complete() or (menu != null and not menu.ftp_page.release_complete()): result.text = "WORKOUT_WAIT_FOR_THE_PREVIOUS_TRAINER_SESSION_TO_BE_RELEASED"; return
	test.ftp_w = roundi(ftp_input.value)
	for block in test.blocks:
		if block.kind != "FreeRide" and maxf(float(block.power_low),float(block.power_high))*test.ftp_w > 1300:
			result.text = "WORKOUT_THIS_FTP_PRODUCES_A_TARGET_ABOVE_1300_W_ADJUST_THE_WORKOUT_OR_YOUR_FTP"; return
	reset_session(now,trainer)
	ramp_chart_start = session_now(now)
	activity_started_unix = int(Time.get_unix_time_from_system())
	activity_started_local = Time.get_datetime_string_from_system().replace("T"," ")
	upload_status = ""
	_reset_ramp_dashboard()
	activity_samples.clear()
	activity_distance = 0.0
	selected_activity = {}
	last_session_clock = session_now(now)
	test.start(last_session_clock)
	desired_target = -1
	confirmation_at = now
	previous_free = test.target(now) <= 0
	trainer.arm()
	active_environment = true
	environment_requested.emit(true)
	stop_button.grab_focus()
func _process(dt: float) -> void:
	var now := now_s()
	var clock := session_now(now)
	var advancing := minf(dt,maxf(0,clock-last_session_clock))
	last_session_clock = clock
	var target: int = test.target(now)
	var free: bool = target <= 0
	if test.running() and free != previous_free:
		confirmation_at = now
		previous_free = free
		test.phase = "CONNECTING"
	if test.running() and target != desired_target:
		desired_target = target
		if live(now) and not free and trainer.phase != "RELEASING" and trainer.error.is_empty(): trainer.arm()
	if test.running() and live(now) and not free and not trainer.armed and trainer.phase != "RELEASING" and trainer.error.is_empty(): trainer.arm()
	drive_trainer(trainer,test.running() and not free,0,1,now,target if not free else 0)
	if test.running() and (not live(now) or resume_pending(trainer)):
		confirmation_at = now
		if fresh(now) and test.phase in ["ERG","FREE"]: test.advance(advancing)
	elif test.running():
		if not trainer.error.is_empty(): finish("Trainerfout: " + tr(trainer.error))
		elif not free and trainer.last_response >= 0 and now-control_response_at(trainer) > 3: finish(String(TranslationServer.translate("FTP_TRAINER_BRIDGE_NO_LONGER_RESPONDING")))
		elif free:
			if release_complete(): test.phase = "FREE"; test.advance(advancing)
			elif now-confirmation_at > 8: finish(String(TranslationServer.translate("WORKOUT_RELEASE_FOR_FREE_RIDING_NOT_CONFIRMED")))
		else:
			var state: Dictionary = trainer.state
			var owned_erg: bool = trainer.owned and state.get("mode") == "ERG" and state.get("desired_mode") == "ERG" and state.get("applied_revision",-1) == state.get("revision",-2)
			var confirmed: bool = owned_erg and state.get("confirmed_target_w") == target
			if confirmed: confirmation_at = now; test.phase = "ERG"
			if test.phase == "ERG" and owned_erg: test.advance(advancing)
			if now-confirmation_at > 8: finish(String(TranslationServer.translate("FTP_ERG_TARGET_NOT_CONFIRMED_BY_TRAINER")))
		if not test.running(): finish(test.reason)
	_refresh()
func finish(message: String) -> void:
	test.stop(message)
	if selected_activity.is_empty() and activity_samples.size() >= 2:
		var energy := 0.0
		var covered := 0.0
		for i in range(1,activity_samples.size()):
			var dt: float = float(activity_samples[i].time_s) - float(activity_samples[i-1].time_s)
			if dt <= 0.0 or dt > 10.0: continue
			energy += dt * float(activity_samples[i-1].power_w)
			covered += dt
		var average: float = energy / covered if covered > 0.0 else 0.0
		var activity := {
			"version":1, "id":"erg_%d" % activity_started_unix, "kind":"erg_workout",
			"title":str(item.get("name","ERG-workout")), "reason":test.reason,
			"started_unix":activity_started_unix, "started_local":activity_started_local,
			"duration_s":float(activity_samples[-1].time_s), "distance_m":activity_distance,
			"samples":activity_samples.duplicate(true), "mean_power_w":average,
			"ftp_reference_w":float(ftp_input.value)
		}
		var archive := preload("res://training_store.gd").new()
		activity.merge(activity_venue)
		selected_activity = activity
		upload_status = String(TranslationServer.translate("FTP_TRAINING_SAVED_LOCALLY")) if archive.save(activity) else archive.error
	_release(now_s())
	if active_environment:
		active_environment = false
		environment_requested.emit(false)
	_refresh()
func leave() -> void:
	finish(String(TranslationServer.translate("MAIN_LEAVE_TRAINING")))
	back_requested.emit()
func _refresh() -> void:
	if start_button == null: return
	var running: bool = test.running()
	start_button.visible = not running
	stop_button.visible = running
	edit_button.visible = not running
	ftp_input.editable = not running
	ftp_input.visible = not running
	detail.visible = not running
	back_button.disabled = running
	if running:
		result.text = String(TranslationServer.translate("WORKOUT_D_02D_D_02D_S_0F_W_MEASURED_S")) % [int(test.elapsed)/60,int(test.elapsed)%60,int(test.duration())/60,int(test.duration())%60,String(TranslationServer.translate("WORKOUT_FREE_RIDING")) if test.phase == "FREE" else "Doel %d W" % test.target(now_s()),measured,test.instruction()]
		result.text += "\nCadans · " + cadence_text()
		var status := signal_state.status(now_s())
		if not status.is_empty(): result.text += "\n"+status
	elif test.phase == "RESULT": result.text = test.reason + (String(TranslationServer.translate("WORKOUT_TRAINER_RELEASED")) if release_complete() else String(TranslationServer.translate("WORKOUT_TRAINER_BEING_RELEASED"))) + ("\n" + upload_status if not upload_status.is_empty() else "")

func _record_ramp_sample(_at: float, power: float) -> void:
	if not test.running(): return
	if ramp_samples.is_empty() or test.elapsed > float(ramp_samples[-1].t):
		ramp_samples.append({"t":test.elapsed,"w":power,"hr":heart_rate_bpm,"rpm":cadence_rpm})
