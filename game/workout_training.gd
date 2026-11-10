extends "res://ftp_training.gd"
signal edit_requested(id: String)
const Run := preload("res://workout_run.gd")
var menu
var workout_id := ""
var item := {}
var ftp_input: SpinBox
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
	var caption := _label("FTP voor deze training (W)",20)
	caption.tooltip_text = "Standaard je spelers-FTP. Een wijziging hier geldt alleen voor deze training."
	ftp_input = SpinBox.new()
	ftp_input.min_value = 20; ftp_input.max_value = 1000; ftp_input.step = 1
	add_child(ftp_input)
	result = _label("",24)
	start_button = _button("Start workout",begin)
	edit_button = _button("Bewerken",func(): edit_requested.emit(workout_id))
	stop_button = _button("Stop · ERG vrijgeven",func(): finish("Handmatig gestopt"))
	back_button = _button("← ERG-training",leave)
	_refresh()
func load_workout(workout: Dictionary) -> void:
	item = workout
	workout_id = str(item.id)
	test.load_workout(item)
	ftp_input.value = player_profile.ftp()
	title.text = str(item.name)
	detail.text = "%d blokken · %d minuten\nJe profiel-FTP wordt als standaard gebruikt. Je kunt hieronder alleen voor deze training afwijken." % [item.blocks.size(),int(ceil(test.duration()/60))]
	_refresh()
func begin() -> void:
	var now := now_s()
	if test.running(): return
	if not live(now): result.text = "Wacht op verse vermogensmetingen."; return
	if not release_complete() or (menu != null and not menu.ftp_page.release_complete()): result.text = "Wacht op vrijgave van de vorige trainersessie."; return
	test.ftp_w = roundi(ftp_input.value)
	for block in test.blocks:
		if block.kind != "FreeRide" and maxf(float(block.power_low),float(block.power_high))*test.ftp_w > 1300:
			result.text = "Deze FTP levert een doel boven 1300 W op. Pas de workout of je FTP aan."; return
	reset_session(now,trainer)
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
		if not trainer.error.is_empty(): finish("Trainerfout: " + trainer.error)
		elif not free and trainer.last_response >= 0 and now-control_response_at(trainer) > 3: finish("Geen antwoord meer van trainerbridge")
		elif free:
			if release_complete(): test.phase = "FREE"; test.advance(advancing)
			elif now-confirmation_at > 8: finish("Vrijgave voor vrij rijden niet bevestigd")
		else:
			var state: Dictionary = trainer.state
			var owned_erg: bool = trainer.owned and state.get("mode") == "ERG" and state.get("desired_mode") == "ERG" and state.get("applied_revision",-1) == state.get("revision",-2)
			var confirmed: bool = owned_erg and state.get("confirmed_target_w") == target
			if confirmed: confirmation_at = now; test.phase = "ERG"
			if test.phase == "ERG" and owned_erg: test.advance(advancing)
			if now-confirmation_at > 8: finish("ERG-doel niet bevestigd door trainer")
		if not test.running(): finish(test.reason)
	_refresh()
func finish(message: String) -> void:
	test.stop(message)
	_release(now_s())
	if active_environment:
		active_environment = false
		environment_requested.emit(false)
	_refresh()
func leave() -> void:
	finish("Training verlaten")
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
		result.text = "%d:%02d / %d:%02d\n%s · %.0f W gemeten\n%s" % [int(test.elapsed)/60,int(test.elapsed)%60,int(test.duration())/60,int(test.duration())%60,"Vrij rijden" if test.phase == "FREE" else "Doel %d W" % test.target(now_s()),measured,test.instruction()]
		result.text += "\nCadans · " + cadence_text()
		var status := signal_state.status(now_s())
		if not status.is_empty(): result.text += "\n"+status
	elif test.phase == "RESULT": result.text = test.reason + ("\nTrainer vrijgegeven." if release_complete() else "\nTrainer wordt vrijgegeven.")
