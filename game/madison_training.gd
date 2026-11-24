extends "res://derny_training.gd"
var progress = preload("res://madison_progress.gd").new()
var difficulty: OptionButton
var count: OptionButton
var unlock_label: Label
var results_scroll: ScrollContainer
var results_table: GridContainer
func _ready() -> void:
	session = preload("res://piste_exercise_session.gd").new()
	progress.load_progress()
	add_theme_constant_override("separation",14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	title = _label("MENU_MADISON_EXCHANGE_TRAINING",34)
	detail = _label("MADISON_PRACTISE_WITH_YOUR_TEAMMATE_A_GRAB_IN_ADVANCED_HOLD_AND_RELEASE_EASY_S",22)
	difficulty = OptionButton.new(); difficulty.add_item("MADISON_EASY_AUTOMATIC_SLING_MAX_70"); difficulty.add_item("MADISON_ADVANCED_HOLD_RELEASE_A_MAX_100"); add_child(difficulty)
	count = OptionButton.new(); count.add_item("MADISON_10_EXCHANGE_ATTEMPTS",10); count.add_item("MADISON_20_EXCHANGE_ATTEMPTS",20); add_child(count)
	unlock_label = _label("",20)
	result = _label("",24)
	start_button = _button("MADISON_START_EXCHANGE_TRAINING",begin)
	result_graph = preload("res://training_graph.gd").new(); result_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(result_graph)
	results_scroll = ScrollContainer.new(); results_scroll.custom_minimum_size.y = 180
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(results_scroll)
	results_table = GridContainer.new(); results_table.columns = 5; results_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_table.add_theme_constant_override("h_separation",20); results_table.add_theme_constant_override("v_separation",8)
	results_scroll.add_child(results_table)
	upload_button = _button("PISTE_EXERCISE_PAGE_SAVE_TO_STRAVA",func(): upload_requested.emit(selected_activity))
	stop_button = _button("FTP_RAMP_HUD_STOP_TRAINING",func(): finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY"))))
	back_button = _button("TRAINING_HISTORY_TRACK_TRAINING",leave)
	_refresh()
func begin() -> void:
	if difficulty.selected == 1 and not progress.advanced_unlocked: return
	super.begin()
func _refresh() -> void:
	if start_button == null: return
	var locked: bool = not progress.advanced_unlocked
	difficulty.set_item_disabled(1,locked)
	if locked and difficulty.selected == 1: difficulty.select(0)
	unlock_label.text = "MADISON_ADVANCED_LOCKED_ACHIEVE_7_10_OR_14_20_IN_EASY" if locked else "MADISON_ADVANCED_UNLOCKED"
	var has_result := not selected_activity.is_empty()
	var running: bool = session.running()
	for node in [difficulty,count,unlock_label]: node.visible = not running and not has_result
	detail.visible = not running and not has_result
	start_button.visible = not running; stop_button.hide()
	result_graph.custom_minimum_size.y = 140
	result_graph.visible = has_result
	results_scroll.visible = has_result and not selected_activity.get("exchanges",[]).is_empty()
	upload_button.visible = has_result; upload_button.disabled = selected_activity.get("samples",[]).size() < 2
	if has_result:
		result.text = String(TranslationServer.translate("MADISON_S_D_D_ATTEMPTS_D_SUCCESSFUL_S")) % [selected_activity.get("reason",""),selected_activity.get("attempts",0),selected_activity.get("target",10),selected_activity.get("successes",0),upload_status]
	elif session.phase == "RESULT": result.text = session.reason
	else: result.text = "MADISON_FOLLOW_THE_YELLOW_EXCHANGE_ZONE_OUTGOING_YOU_GIVE_THE_SLING_ON_THE_INS"

func show_activity(activity: Dictionary, message: String = "TRAINING_ACTIVITY_SAVED") -> void:
	super.show_activity(activity,message)
	for child in results_table.get_children():
		results_table.remove_child(child); child.queue_free()
	for heading in [String(TranslationServer.translate("MADISON_ATTEMPT")),String(TranslationServer.translate("MADISON_ROLE")),String(TranslationServer.translate("MADISON_RESULT")),String(TranslationServer.translate("MADISON_REASON_FOR_FAILURE")),"Score /100"]:
		_table_cell(heading,true)
	for stored in activity.get("exchanges",[]):
		var exchange: Dictionary = _display_exchange(stored)
		for text in [str(exchange.get("number","")),TranslationServer.translate({"Uitgaand": "MADISON_OUTGOING", "Inkomend": "MADISON_INCOMING"}.get(exchange.get("role", ""), exchange.get("role", ""))),String(TranslationServer.translate("MADISON_SUCCESSFUL")) if exchange.get("success",false) else String(TranslationServer.translate("MADISON_FAILED")),str(exchange.get("reason","")),str(exchange.get("score",0))]:
			_table_cell(text)

func _table_cell(text: String, heading: bool = false) -> void:
	var cell := Label.new(); cell.text = text; cell.add_theme_font_size_override("font_size",18)
	if results_table.get_child_count()%5 == 3:
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cell.custom_minimum_size.x = 220
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if heading: cell.add_theme_color_override("font_color",preload("res://menu_theme.gd").BLUE)
	results_table.add_child(cell)

func _display_exchange(stored: Dictionary) -> Dictionary:
	var exchange: Dictionary = stored.duplicate()
	if exchange.has("player_role"):
		exchange["role"] = "Uitgaand" if exchange.player_role == "giver" else "Inkomend"
	else:
		# Previously stored activities used the opposite Dutch role names.
		exchange["role"] = "Uitgaand" if stored.get("role","") == "Inkomend" else "Inkomend" if stored.get("role","") == "Uitgaand" else str(stored.get("role",""))
		var reason: String = str(stored.get("reason",""))
		for pair in [["Inkomend","Uitgaand"],["inkomend","uitgaand"]]:
			reason = reason.replace(pair[0],"__ROLE_SWAP__").replace(pair[1],pair[0]).replace("__ROLE_SWAP__",pair[1])
		exchange["reason"] = reason
	return exchange
