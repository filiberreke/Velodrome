extends "res://derny_training.gd"
var progress = preload("res://madison_progress.gd").new()
var difficulty: OptionButton
var count: OptionButton
var unlock_label: Label
func _ready() -> void:
	session = preload("res://piste_exercise_session.gd").new()
	progress.load_progress()
	add_theme_constant_override("separation",14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	title = _label("Aflossingstraining",34)
	detail = _label("Oefen met je ploegmaat. A: grijpen; in Advanced vasthouden en loslaten. Easy slingert en laat automatisch los (max 70%).\n←/→ of stuurpaddles: rijlijn. De snelle renner rijdt binnen; de ontvanger bij de blauwe lijn. Elke spelersronde verschijnt de ploegmaat opnieuw voor één gerichte aflossingspoging.",22)
	difficulty = OptionButton.new(); difficulty.add_item("Easy · automatisch slingeren · max 70%"); difficulty.add_item("Advanced · A vasthouden/loslaten · max 100%"); add_child(difficulty)
	count = OptionButton.new(); count.add_item("10 aflossingspogingen",10); count.add_item("20 aflossingspogingen",20); add_child(count)
	unlock_label = _label("",20)
	result = _label("",24)
	start_button = _button("Start aflossingstraining",begin)
	result_graph = preload("res://training_graph.gd").new(); result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(result_graph)
	upload_button = _button("Opslaan op Strava",func(): upload_requested.emit(selected_activity))
	stop_button = _button("Stop training",func(): finish("Handmatig gestopt"))
	back_button = _button("← Pistetraining",leave)
	_refresh()
func begin() -> void:
	if difficulty.selected == 1 and not progress.advanced_unlocked: return
	super.begin()
func _refresh() -> void:
	if start_button == null: return
	var locked: bool = not progress.advanced_unlocked
	difficulty.set_item_disabled(1,locked)
	if locked and difficulty.selected == 1: difficulty.select(0)
	unlock_label.text = "Advanced vergrendeld · haal 7/10 of 14/20 in Easy." if locked else "Advanced vrijgespeeld."
	var has_result := not selected_activity.is_empty()
	var running: bool = session.running()
	for node in [difficulty,count,unlock_label]: node.visible = not running
	detail.visible = not running and not has_result
	start_button.visible = not running; stop_button.hide()
	result_graph.visible = has_result
	upload_button.visible = has_result; upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		result.text = "%s · %d/%d pogingen · %d geslaagd\n%s" % [selected_activity.get("reason",""),selected_activity.get("attempts",0),selected_activity.get("target",10),selected_activity.get("successes",0),upload_status]
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "Een geldige greep en positieve momentumoverdracht tellen als geslaagd."
