extends "res://race_hud.gd"
## FTP test overlay reusing the race metrics and power meter, not the menu sheet.
var ftp_page
var live_power_label: Label
var step_panel: PanelContainer
var step_rows: VBoxContainer
var step_scroll: ScrollContainer
var step_caption: Label
var ramp_dial: Control
const RampProtocol := preload("res://ftp_ramp.gd")
var phase_caption: Label
var ftp_panel: PanelContainer
var ftp_value: Label
var best_value: Label
var graph_panel: PanelContainer
var profile_graph: Control
var stop_test: Button
var current_step := -999
var step_labels: Dictionary = {}
var twenty_detail: Label

func reset_for_session() -> void:
	current_step = -999
	step_labels.clear()
	if step_rows != null:
		for child in step_rows.get_children():
			step_rows.remove_child(child)
			child.queue_free()

func _ready() -> void:
	super._ready()
	for node in [map_panel, nearby_panel, points_panel, team_laps_panel, solo_panel, bottom_bar, developer_panel, signals]:
		node.hide()
	energy_panel.hide()
	slipstream_heading.hide()
	slipstream_bar.hide()
	popup.hide()
	status_panel.hide()
	left_stack.offset_top = 150.0
	left_stack.offset_bottom = 780.0
	power_panel.show()
	var metrics_column: VBoxContainer = power_panel.get_child(0) as VBoxContainer
	live_power_label = _metric(metrics_column, String(TranslationServer.translate("WORKOUT_POWER")), "— W")
	# Standard top-left race panel supplies speed, heart rate, cadence, and gearing.
	# The centre remains the unmodified race power meter with its red target arrow.
	power_meter.show()
	_build_dial()
	_build_ftp()
	_build_steps()
	_build_profile()
	_build_stop()

func _build_dial() -> void:
	ramp_dial = preload("res://ftp_ramp_dial.gd").new()
	left_stack.add_child(ramp_dial)

func _build_steps() -> void:
	step_panel = panel(self, Control.PRESET_TOP_RIGHT, -378, 367, -32, 685)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	step_panel.add_child(column)
	column.add_child(text(String(TranslationServer.translate("WORKOUT_POWER_STEPS")), 20, ACCENT))
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var target_label := text(String(TranslationServer.translate("FTP_RAMP_HUD_TARGET")), 16, MUTED)
	target_label.custom_minimum_size.x = 115
	heading.add_child(target_label)
	var watt_label := text("Gem. W", 16, MUTED)
	watt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(watt_label)
	heading.add_child(text(String(TranslationServer.translate("FTP_RAMP_HUD_AVG_HR")), 16, MUTED))
	step_scroll = ScrollContainer.new()
	step_scroll.custom_minimum_size.y = 215
	step_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(step_scroll)
	step_rows = VBoxContainer.new()
	step_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_rows.add_theme_constant_override("separation", 5)
	step_scroll.add_child(step_rows)

func _build_ftp() -> void:
	ftp_panel = panel(self, Control.PRESET_TOP_RIGHT, -378, 156, -32, 350)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	ftp_panel.add_child(column)
	column.add_child(text(String(TranslationServer.translate("FTP_RAMP_HUD_ESTIMATED_FTP")), 18, ACCENT))
	ftp_value = text("— W", 49)
	column.add_child(ftp_value)
	best_value = text("Beste 60 s: —", 19, MUTED)
	column.add_child(best_value)
	twenty_detail = text(String(TranslationServer.translate("FTP_RAMP_HUD_75_OF_BEST_60_SECONDS")), 15, MUTED)
	column.add_child(twenty_detail)
	phase_caption = text("", 19, ACCENT)
	phase_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(phase_caption)

func _build_profile() -> void:
	graph_panel = panel(self, Control.PRESET_BOTTOM_WIDE, 32, -246, -32, -24)
	graph_panel.add_theme_stylebox_override("panel", style(Color(0.9608, 0.9451, 0.9059, 0.78)))
	var column := VBoxContainer.new()
	graph_panel.add_child(column)
	column.add_child(text(String(TranslationServer.translate("FTP_RAMP_HUD_POWER_PROFILE_TARGET_AND_ACTUAL")), 16, ACCENT))
	profile_graph = preload("res://ftp_ramp_profile_graph.gd").new()
	profile_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(profile_graph)

func _build_stop() -> void:
	stop_test = Button.new()
	stop_test.text = "FTP_RAMP_HUD_STOP_TEST"
	stop_test.custom_minimum_size = Vector2(260, 48)
	stop_test.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stop_test.offset_left = -310
	stop_test.offset_right = -32
	stop_test.offset_top = 702
	stop_test.offset_bottom = 752
	stop_test.pressed.connect(_stop_ramp)
	add_child(stop_test)

func _stop_ramp() -> void:
	if ftp_page != null: ftp_page.finish(String(TranslationServer.translate("MAIN_STOPPED_MANUALLY")))

func _make_step_row(key: int) -> Dictionary:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	step_rows.add_child(line)
	var label := text(String(TranslationServer.translate("WORKOUT_EDITOR_WARM_UP")) if key == -1 else "%d W" % (100+20*key), 17)
	label.custom_minimum_size.x = 115
	line.add_child(label)
	var watts := text("—", 17)
	watts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(watts)
	var hr := text("—", 17)
	hr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(hr)
	return {"row":line,"label":label,"watts":watts,"hr":hr}

func update_ftp(page) -> void:
	ftp_page = page
	if not page.test.running() and not page.twenty_warmup: return
	ftp_panel.show()
	stop_test.text = "FTP_RAMP_HUD_STOP_TEST"
	var twenty: bool = page.twenty_mode
	var now: float = page.now_s()
	var clock: float = page.session_now(now)
	var fresh: bool = page.live(now)
	speed_label.text = "%.1f" % page.last_speed_kmh if fresh else "—"
	live_power_label.text = "%.0f W" % page.measured if fresh else "— W"
	heart_label.text = "%d bpm" % roundi(page.heart_rate_bpm) if fresh and page.heart_rate_bpm > 0 else "— bpm"
	cadence_label.text = page.cadence_text()
	gear_label.text = str(page.gear) if fresh and page.gear > 0 else "—"
	power_meter.set_power(page.measured if fresh else 0.0, float(page.test.target(clock)) if not twenty else 0.0, not twenty and page.test.phase == "RAMP", "")
	var elapsed: float = maxf(0.0, clock - page.ramp_chart_start)
	var ramp_at: float = float(page.test.ramp_at) if not twenty else -1.0
	var profile_ramp_at: float = ramp_at-page.ramp_chart_start if ramp_at >= 0.0 else RampProtocol.WARMUP_SECONDS
	if twenty: profile_graph.update_twenty(page.ramp_samples,elapsed,page.twenty_reference_w, RampProtocol.WARMUP_SECONDS)
	else: profile_graph.update_profile(page.ramp_samples, elapsed, profile_ramp_at, true)
	var current_w: int = int(page.test.target(clock)) if page.test.phase == "RAMP" else 0
	var next_w: int = RampProtocol.START_W if page.test.phase != "RAMP" else mini(RampProtocol.MAX_W, current_w + RampProtocol.STEP_W)
	var remaining_s: float = 0.0
	if page.test.phase == "WARMUP":
		remaining_s = maxf(0.0, RampProtocol.WARMUP_SECONDS - (clock - page.test.started_at))
	elif page.test.phase == "RAMP":
		remaining_s = maxf(0.0, RampProtocol.STEP_SECONDS - fposmod(clock - ramp_at, RampProtocol.STEP_SECONDS))
	ramp_dial.update_step(current_w, next_w, remaining_s, page.test.phase)
	if twenty:
		var left_s: float = maxf(0.0,RampProtocol.WARMUP_SECONDS - (clock-page.twenty_warmup_at)) if page.twenty_warmup else maxf(0.0,1200.0-(clock-page.test.start_at))
		ramp_dial.update_step(0,roundi(page.twenty_reference_w),left_s,"WARMUP20" if page.twenty_warmup else "TWENTY")
	if twenty:
		step_panel.hide()
		twenty_detail.text = "FTP_RAMP_HUD_95_OF_AVERAGE_POWER"
		var avg: float = page.test.energy / page.test.covered if page.test.covered > 0.0 else 0.0
		ftp_value.text = "%.0f W" % (avg*0.95) if page.test.covered > 0.0 else "— W"
		best_value.text = "Gemiddeld %.0f W" % avg if page.test.covered > 0.0 else String(TranslationServer.translate("FTP_RAMP_HUD_WARM_UP_NO_FTP_MEASUREMENT"))
		var remaining_t: int = ceili(maxf(0.0,RampProtocol.WARMUP_SECONDS-(clock-page.twenty_warmup_at))) if page.twenty_warmup else ceili(maxf(0.0,1200.0-(clock-page.test.start_at)))
		phase_caption.text = String(TranslationServer.translate("FTP_RAMP_HUD_S_02D_02D_REMAINING")) % [String(TranslationServer.translate("WORKOUT_EDITOR_WARM_UP")) if page.twenty_warmup else "Vrije 20'-test",remaining_t/60,remaining_t%60]
		return
	step_panel.show()
	twenty_detail.text = "FTP_RAMP_HUD_75_OF_BEST_60_SECONDS"
	ftp_value.text = "%.0f W" % page.test.ftp() if page.test.best_60 > 0 else "— W"
	best_value.text = "Beste 60 s: %.1f W" % page.test.best_60 if page.test.best_60 > 0 else "Beste 60 s: —"
	var step_key: int = -1 if page.test.phase == "WARMUP" else int(maxf(0.0,clock-ramp_at)/60.0) if ramp_at >= 0.0 else -2
	if page.test.phase == "WARMUP":
		var seconds: int = ceili(maxf(0.0,300.0-(clock-page.test.started_at)))
		phase_caption.text = String(TranslationServer.translate("FTP_RAMP_HUD_FREE_WARM_UP_D_02D_REMAINING")) % [seconds/60,seconds%60]
	elif page.test.phase == "CONNECTING":
		phase_caption.text = "FTP_RAMP_HUD_WAITING_FOR_ERG_CONFIRMATION"
	else:
		var left: int = ceili(maxf(0.0,60.0-fposmod(clock-ramp_at,60.0)))
		phase_caption.text = String(TranslationServer.translate("FTP_RAMP_HUD_TARGET_D_W_D_S_REMAINING")) % [page.test.target(clock),left]
	if step_key != current_step:
		current_step = step_key
		for child in step_rows.get_children():
			step_rows.remove_child(child)
			child.queue_free()
		step_labels.clear()
		for key in range(step_key,-2,-1):
			if key < -1: continue
			step_labels[key] = _make_step_row(key)
		step_scroll.set_deferred("scroll_vertical",0)
	for key in step_labels:
		var row: Dictionary = step_labels[key]
		var stat: Dictionary = page.ramp_step_stats.get(key,{})
		var duration: float = float(stat.get("seconds",0.0))
		var hr_duration: float = float(stat.get("hr_seconds",0.0))
		row.watts.text = "%.0f W" % (float(stat.get("energy",0.0))/duration) if duration > 0.0 else "—"
		row.hr.text = "%.0f" % (float(stat.get("hr_total",0.0))/hr_duration) if hr_duration > 0.0 else "—"
		row.label.add_theme_color_override("font_color", ACCENT if key == step_key else INK)

func update_workout(page) -> void:
	ftp_page = page
	if not page.test.running(): return
	ftp_panel.hide()
	step_panel.hide()
	stop_test.text = "FTP_RAMP_HUD_STOP_TRAINING"
	var fresh: bool = page.live(page.now_s())
	speed_label.text = "%.1f" % page.last_speed_kmh if fresh else "—"
	live_power_label.text = "%.0f W" % page.measured if fresh else "— W"
	heart_label.text = "%d bpm" % roundi(page.heart_rate_bpm) if fresh and page.heart_rate_bpm > 0 else "— bpm"
	cadence_label.text = page.cadence_text()
	gear_label.text = str(page.gear) if fresh and page.gear > 0 else "—"
	var target: int = page.test.target(page.now_s())
	power_meter.set_power(page.measured if fresh else 0.0,float(target),target > 0,"")
	profile_graph.update_workout(page.ramp_samples,page.test.elapsed,page.test.blocks,float(page.test.ftp_w),page.test.duration())
	var part: Dictionary = page.test.current()
	if part.is_empty(): return
	var remaining: float = float(part.block.duration)-float(part.seconds)
	var following := 0
	var index: int = int(part.index)+1
	if index < page.test.blocks.size():
		var block: Dictionary = page.test.blocks[index]
		if block.kind != "FreeRide": following = roundi(float(block.power_low)*page.test.ftp_w)
	ramp_dial.update_workout(target,following,remaining,float(part.block.duration),index >= page.test.blocks.size(),page.test.instruction(),page.signal_state.status(page.now_s()))
