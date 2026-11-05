extends Control
## Compact race presentation. Classification and physics remain owned by main.gd.
const MiniMap := preload("res://minimap.gd")
const MenuStyle := preload("res://menu_theme.gd")
const INK := MenuStyle.INK
const MUTED := MenuStyle.MUTED
const ACCENT := MenuStyle.BLUE
var signals: Control
var power_label: Label
var speed_label: Label
var slipstream_bar: ProgressBar
var slipstream_label: Label
var slipstream_heading: HBoxContainer
var left_stack: VBoxContainer
var map_panel: Control
var heart_label: Label
var gear_label: Label
var lap_label: Label
var time_label: Label
var gap_label: Label
var gap_caption: Label
var position_label: Label
var scratch_center: HBoxContainer
var pursuit_center: HBoxContainer
var right_caption: Label
var pursuit_time_label: Label
var pursuit_gap_label: Label
var pursuit_sides: Array[PanelContainer] = []
var pursuit_names: Array[Label] = []
var pursuit_laps: Array[Label] = []
var pursuit_stats: Array[Label] = []
var pursuit_lead_style: StyleBoxFlat
var pursuit_trail_style: StyleBoxFlat
var pursuit_tie_style: StyleBoxFlat
var map: Control
var rider_rows: Array[Dictionary] = []
var nearby_panel: PanelContainer
var peloton_label: Label
var points_panel: PanelContainer
var points_rows: Array[Dictionary] = []
var team_laps_panel: PanelContainer
var team_laps_scroll: ScrollContainer
var team_lap_rows: Array[Dictionary] = []
var shown_team_laps := 0
var power_panel: PanelContainer
var bottom_bar: PanelContainer
var developer_panel: PanelContainer
var developer_enabled := false
var developer_body: VBoxContainer
var power_meter: Control
var status_panel: PanelContainer
var popup: Label
var status_label: Label
var row_normal: StyleBoxFlat
var row_player: StyleBoxFlat
var solo_panel: PanelContainer
var solo_reference_label: Label
var solo_rows: Array[Dictionary] = []
var solo_bottom: HBoxContainer
var solo_elapsed_label: Label
var solo_estimate_label: Label

static func style(fill: Color = Color(0.9608, 0.9451, 0.9059, 0.75), border: Color = Color(0.8235, 0.8510, 0.8745, 0.65)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(22)
	return box

func text(value: String, font_size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	if value in ["Rondom jou", "RONDETIJDEN", "HALVE-RONDETIJDEN · 125 M", "TUSSENSTAND · PUNTEN"]:
		node.add_theme_font_override("font", MenuStyle.heading())
	node.add_theme_color_override("font_color", color)
	return node

func panel(parent_node: Node, position_preset: int, left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var node := PanelContainer.new()
	parent_node.add_child(node)
	node.set_anchors_preset(position_preset)
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style())
	return node

func _ready() -> void:
	theme = MenuStyle.create()
	var brand := MenuStyle.logo()
	brand.custom_minimum_size = Vector2.ZERO
	brand.position = Vector2(32, 24)
	brand.size = Vector2(348, 68)
	add_child(brand)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_stack = VBoxContainer.new()
	left_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_stack.offset_left = 32
	left_stack.offset_top = 150
	left_stack.offset_right = 410
	left_stack.offset_bottom = 916
	left_stack.add_theme_constant_override("separation", 16)
	add_child(left_stack)
	_build_power()
	row_normal = style(Color.TRANSPARENT, Color.TRANSPARENT)
	row_normal.set_content_margin_all(8)
	row_player = style(MenuStyle.BLUE, Color.TRANSPARENT)
	row_player.set_content_margin_all(8)
	_build_nearby()
	_build_points_standings()
	_build_team_laps()
	_build_solo_checkpoints()
	_build_bottom()
	for surface in [power_panel, bottom_bar]:
		var paper: StyleBoxFlat = surface.get_theme_stylebox("panel").duplicate()
		paper.border_color = MenuStyle.WOOD
		paper.border_width_top = 3
		surface.add_theme_stylebox_override("panel", paper)
	_build_developer()
	status_panel = panel(self, Control.PRESET_CENTER_TOP, -410, 80, 410, 142)
	status_panel.add_theme_stylebox_override("panel", style(Color(0.9608, 0.9451, 0.9059, 0.75), MenuStyle.WOOD))
	status_label = text("", 22, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(status_label)
	status_panel.hide()
	popup = preload("res://race_popup.gd").new()
	add_child(popup)
	_build_power_meter()
	signals = preload("res://race_signals.gd").new()
	add_child(signals)
	move_child(developer_panel, -1)

func _build_power_meter() -> void:
	power_meter = preload("res://power_meter.gd").new()
	add_child(power_meter)
	power_meter.anchor_left = 0.0
	power_meter.anchor_right = 1.0
	power_meter.offset_left = 442.0
	power_meter.offset_right = -442.0
	power_meter.offset_top = 96.0
	power_meter.offset_bottom = 242.0
	power_label = power_meter.value_label

func _build_power() -> void:
	power_panel = panel(left_stack, Control.PRESET_TOP_LEFT, 0, 0, 0, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	power_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := text("SNELHEID", 16, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var speed_row := HBoxContainer.new()
	column.add_child(speed_row)
	speed_label = text("0.0", 40)
	speed_row.add_child(speed_label)
	var speed_unit := text("km/u", 21, ACCENT)
	speed_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_row.add_child(speed_unit)
	heart_label = _metric(column, "HARTSLAG", "— bpm")
	heart_label.tooltip_text = "Hartslag is voorlopig een placeholder"
	gear_label = _metric(column, "VERSNELLING", "—")
	gear_label.custom_minimum_size.x = 100
	gear_label.clip_text = true
	gear_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gear_label.tooltip_text = "Gekozen versnelling uit de trainerbridge, wanneer beschikbaar"
	slipstream_heading = HBoxContainer.new()
	column.add_child(slipstream_heading)
	var slipstream_caption := text("SLIPSTREAM", 16, MUTED)
	slipstream_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slipstream_heading.add_child(slipstream_caption)
	slipstream_label = text("0%", 18, ACCENT)
	slipstream_heading.add_child(slipstream_label)
	slipstream_bar = ProgressBar.new()
	slipstream_bar.custom_minimum_size.y = 12
	slipstream_bar.show_percentage = false
	slipstream_bar.max_value = 69.0
	slipstream_bar.step = 0.01
	var track := style(MenuStyle.LINE, Color.TRANSPARENT)
	track.set_content_margin_all(0)
	track.set_corner_radius_all(6)
	var fill := style(ACCENT, Color.TRANSPARENT)
	fill.set_content_margin_all(0)
	fill.set_corner_radius_all(6)
	slipstream_bar.add_theme_stylebox_override("background", track)
	slipstream_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(slipstream_bar)

func _metric(parent_node: VBoxContainer, title: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent_node.add_child(row)
	var caption := text(title, 16, MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var number := text(value, 24)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	return number

func _build_nearby() -> void:
	map_panel = panel(self, Control.PRESET_TOP_RIGHT, -410, 112, -32, 318)
	map = MiniMap.new()
	map_panel.add_child(map)
	map.custom_minimum_size = Vector2(320, 155)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var laps := Control.new()
	map.add_child(laps)
	laps.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	laps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lap_label = text("1/1", 38)
	lap_label.name = "MinimapLap"
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	laps.add_child(lap_label)
	lap_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nearby_panel = panel(left_stack, Control.PRESET_TOP_LEFT, 0, 0, 0, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	nearby_panel.add_child(column)
	column.add_child(text("Rondom jou", 22, INK))
	peloton_label = text("", 17, ACCENT)
	peloton_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(peloton_label)
	for i in range(6):
		var shell := PanelContainer.new()
		shell.custom_minimum_size.y = 42
		shell.add_theme_stylebox_override("panel", row_normal)
		column.add_child(shell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		shell.add_child(row)
		var rank := text("", 22, MUTED)
		rank.custom_minimum_size.x = 30
		row.add_child(rank)
		var marker := text("●", 15)
		row.add_child(marker)
		var name_label := text("", 20)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		row.add_child(name_label)
		var gap := text("", 18, MUTED)
		gap.custom_minimum_size.x = 84
		gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(gap)
		rider_rows.append({"shell": shell, "rank": rank, "marker": marker, "name": name_label, "gap": gap})

func _build_team_laps() -> void:
	team_laps_panel = panel(left_stack, Control.PRESET_TOP_LEFT, 0, 0, 0, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	team_laps_panel.add_child(column)
	column.add_child(text("HALVE-RONDETIJDEN · 125 M", 16, MUTED))
	column.add_child(text("Afstand     Tijd (verschil)", 16, MUTED))
	team_laps_scroll = ScrollContainer.new()
	team_laps_scroll.custom_minimum_size.y = 330
	team_laps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	team_laps_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(team_laps_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	team_laps_scroll.add_child(rows)
	for i in range(32):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		var lap := text("%d m" % ((i + 1) * 125), 19, MUTED)
		lap.custom_minimum_size.x = 76
		row.add_child(lap)
		var value := text("", 20)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		team_lap_rows.append({"row": row, "distance": lap, "value": value})
		row.hide()
	team_laps_panel.tooltip_text = "Tijd per 125 m · cumulatief verschil op hetzelfde afstandspunt: + voor, − achter. (…) wacht op de tegenploeg."
	team_laps_panel.hide()

static func team_half_summary(own: Array, opponent: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(own.size()):
		var delta: Variant = null
		if i < opponent.size():
			delta = float(opponent[i]) - float(own[i])
		var prior: float = float(own[i - 1]) if i > 0 else 0.0
		result.append({"seconds": float(own[i]) - prior, "delta": delta})
	return result

func _update_team_laps(data: Dictionary) -> void:
	var team: bool = bool(data.get("team_mode", false))
	nearby_panel.visible = not team
	team_laps_panel.visible = team
	if not team:
		shown_team_laps = 0
		return
	var laps := team_half_summary(data.get("team_half_crossings", []), data.get("opponent_half_crossings", []))
	for i in range(team_lap_rows.size()):
		var row: Dictionary = team_lap_rows[i]
		row["row"].visible = i < laps.size()
		if i >= laps.size(): continue
		var delta: Variant = laps[i]["delta"]
		var gap := "…" if delta == null else ("0.00 s" if absf(float(delta)) < 0.005 else "%s%.2f s" % ["+" if float(delta) > 0.0 else "−", absf(float(delta))])
		row["value"].text = "%.2f s (%s)" % [float(laps[i]["seconds"]), gap]
	if laps.size() > shown_team_laps:
		team_laps_scroll.call_deferred("ensure_control_visible", team_lap_rows[mini(laps.size(), team_lap_rows.size()) - 1]["row"])
	shown_team_laps = laps.size()

func _build_bottom() -> void:
	bottom_bar = panel(self, Control.PRESET_BOTTOM_WIDE, 442, -144, -32, -28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bottom_bar.add_child(row)
	var center := HBoxContainer.new()
	scratch_center = center
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 48)
	row.add_child(center)
	var time := VBoxContainer.new()
	center.add_child(time)
	time.add_child(text("TIJD", 16, MUTED))
	time_label = text("00:00.0", 40)
	time.add_child(time_label)
	var leader := VBoxContainer.new()
	center.add_child(leader)
	gap_caption = text("KOPPOSITIE", 16, MUTED)
	leader.add_child(gap_caption)
	gap_label = text("Aan kop", 28, ACCENT)
	leader.add_child(gap_label)
	_build_pursuit_bar(row)
	var position := VBoxContainer.new()
	position.custom_minimum_size.x = 230
	row.add_child(position)
	var caption := text("POSITIE", 16, MUTED)
	right_caption = caption
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position.add_child(caption)
	position_label = text("1/8", 40)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position.add_child(position_label)
	pursuit_time_label = text("00:00.00", 36)
	pursuit_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position.add_child(pursuit_time_label)
	pursuit_time_label.hide()
	solo_bottom = HBoxContainer.new()
	solo_bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solo_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	solo_bottom.add_theme_constant_override("separation", 120)
	row.add_child(solo_bottom)
	for title in ["GEREDEN TIJD", "GESCHATTE EINDTIJD"]:
		var column := VBoxContainer.new()
		solo_bottom.add_child(column)
		column.add_child(text(title, 16, MUTED))
		var value := text("—", 40)
		column.add_child(value)
		if title == "GEREDEN TIJD": solo_elapsed_label = value
		else: solo_estimate_label = value
	solo_bottom.hide()
	var help := VBoxContainer.new()
	help.name = "HudShortcuts"
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help.add_theme_constant_override("separation", 8)
	row.add_child(help)
	help.add_child(text("ESC · Pauze", 17, MUTED))
	help.add_child(text("F10 - Instellingen", 17, MUTED))

func _build_solo_checkpoints() -> void:
	solo_panel = panel(left_stack, Control.PRESET_TOP_LEFT, 0, 0, 0, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	solo_panel.add_child(column)
	column.add_child(text("HALVE-RONDETIJDEN · 125 M", 16, MUTED))
	solo_reference_label = text("", 16, MUTED)
	column.add_child(solo_reference_label)
	for i in range(8):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var distance := text("%d m" % ((i + 1) * 125), 19, MUTED)
		distance.custom_minimum_size.x = 72
		row.add_child(distance)
		var elapsed := text("—", 20)
		elapsed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elapsed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(elapsed)
		var delta := text("", 19)
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(delta)
		solo_rows.append({"row": row, "elapsed": elapsed, "delta": delta})
	solo_panel.tooltip_text = "Tijd per afzonderlijke 125 meter · negatief/groen = sneller, positief/rood = langzamer dan de referentie."
	solo_panel.hide()

static func solo_clock(seconds: float) -> String:
	var ticks := maxi(0, int(floor(seconds * 1000.0 + 0.00001)))
	return "%02d:%02d.%03d" % [ticks / 60000, (ticks / 1000) % 60, ticks % 1000]

static func estimated_finish(elapsed: float, remaining_m: float, speed_kmh: float) -> Variant:
	if not is_finite(elapsed) or not is_finite(remaining_m): return null
	if remaining_m <= 0.0: return maxf(0.0, elapsed)
	# Below walking speed the instantaneous prediction is not useful.
	if not is_finite(speed_kmh) or speed_kmh < 1.0: return null
	return maxf(0.0, elapsed) + remaining_m / (speed_kmh / 3.6)

func _update_solo(data: Dictionary) -> void:
	var solo := bool(data.get("solo_time_trial", false))
	solo_panel.visible = solo
	solo_bottom.visible = solo
	lap_label.get_parent().visible = true
	position_label.get_parent().visible = not solo
	if not solo: return
	nearby_panel.hide()
	team_laps_panel.hide()
	scratch_center.hide()
	pursuit_center.hide()
	var elapsed := float(data["seconds"])
	solo_elapsed_label.text = clock_text(elapsed)
	var estimate: Variant = estimated_finish(elapsed, float(data.get("solo_remaining_m", 0.0)), float(data.get("speed_kmh", 0.0)))
	solo_estimate_label.text = "—" if data.get("run_up", false) or estimate == null else solo_clock(float(estimate)).get_slice(".", 0)
	var reference: Dictionary = data.get("solo_reference", {})
	var kind := str(data.get("solo_reference_kind", "none"))
	var reference_splits: Array = reference.get("splits", []) if kind != "none" else []
	var titles := {"last": "Laatste rit", "recent": "Recent PR · 60 dagen", "alltime": "All-time PR"}
	solo_reference_label.text = "Aanloopronde · klok start bij GO!" if data.get("run_up", false) else ("Tijd per 125 m" if reference_splits.is_empty() else str(titles.get(kind, "Referentie")))
	var crossings: Array = data.get("solo_crossings", [])
	var count := int(data.get("solo_distance_m", 500)) / 125
	for i in range(solo_rows.size()):
		var row: Dictionary = solo_rows[i]
		row.row.visible = i < count
		var segment: float = float(crossings[i]) - (float(crossings[i - 1]) if i > 0 else 0.0) if i < crossings.size() else 0.0
		row.elapsed.text = "%.3f" % segment if i < crossings.size() else "—"
		row.delta.text = ""
		if i >= crossings.size() or i >= reference_splits.size(): continue
		var reference_segment := float(reference_splits[i]) - (float(reference_splits[i - 1]) if i > 0 else 0.0)
		var delta := snappedf(segment - reference_segment, 0.001)
		row.delta.text = "%+.3f s" % delta if delta != 0.0 else "0.000 s"
		row.delta.add_theme_color_override("font_color", Color("27734a") if delta < 0.0 else (Color("af3843") if delta > 0.0 else MUTED))

func _build_pursuit_bar(row: HBoxContainer) -> void:
	pursuit_center = HBoxContainer.new()
	pursuit_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pursuit_center.add_theme_constant_override("separation", 0)
	row.add_child(pursuit_center)
	pursuit_lead_style = style(Color(0.8784, 0.9294, 0.9608, 0.9), Color.TRANSPARENT)
	pursuit_trail_style = style(Color(0.9608, 0.9451, 0.9059, 0.75), Color.TRANSPARENT)
	pursuit_tie_style = style(Color(0.9608, 0.9451, 0.9059, 0.55), Color.TRANSPARENT)
	for box in [pursuit_lead_style, pursuit_trail_style, pursuit_tie_style]:
		box.set_content_margin_all(12)
		box.set_corner_radius_all(8)
	for i in range(2):
		if i == 1:
			var middle := VBoxContainer.new()
			middle.custom_minimum_size.x = 170
			middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pursuit_center.add_child(middle)
			pursuit_gap_label = text("--", 30)
			pursuit_gap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			middle.add_child(pursuit_gap_label)
		var shell := PanelContainer.new()
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_stretch_ratio = 1.0
		shell.add_theme_stylebox_override("panel", pursuit_tie_style)
		pursuit_center.add_child(shell)
		pursuit_sides.append(shell)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		shell.add_child(line)
		var name_label := text("", 25)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var lap_time := text("--", 30)
		var numbers := VBoxContainer.new()
		numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		numbers.add_theme_constant_override("separation", 2)
		numbers.add_child(lap_time)
		var details := text("", 16)
		numbers.add_child(details)
		pursuit_stats.append(details)
		if i == 0:
			line.add_child(name_label)
			line.add_child(numbers)
		else:
			line.add_child(numbers)
			line.add_child(name_label)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pursuit_names.append(name_label)
		pursuit_laps.append(lap_time)
	pursuit_center.hide()

static func precise_clock(seconds: float) -> String:
	var ticks := maxi(0, int(floor(seconds * 100.0 + 0.00001)))
	return "%02d:%02d.%02d" % [ticks / 6000, (ticks / 100) % 60, ticks % 100]

func _update_pursuit_bar(data: Dictionary) -> void:
	var active := bool(data.get("pursuit", false))
	scratch_center.visible = not active
	pursuit_center.visible = active
	position_label.visible = not active
	pursuit_time_label.visible = active
	right_caption.text = "TOTALE TIJD" if active else "POSITIE"
	if not active:
		return
	pursuit_time_label.text = precise_clock(float(data["seconds"]))
	pursuit_names[0].text = str(data.get("pursuit_player", data["names"][0]))
	pursuit_names[1].text = str(data.get("pursuit_opponent", "AI")).left(20)
	pursuit_names[1].tooltip_text = pursuit_names[1].text
	var times: Array = data.get("pursuit_laps", [-1.0, -1.0])
	for i in range(2):
		pursuit_laps[i].text = "%.2f s" % float(times[i]) if float(times[i]) >= 0.0 else ""
		var stats: Dictionary = data.get("pursuit_stats", [{}, {}])[i]
		pursuit_stats[i].text = "%.1f km/u · %.0f W" % [float(stats["kmh"]), float(stats["watts"])] if float(times[i]) >= 0.0 and not stats.is_empty() else ""
	var live: Variant = data.get("pursuit_live_gap", null)
	pursuit_gap_label.text = ""
	if live != null:
		var gap: float = float(live)
		pursuit_gap_label.text = "0.00 s" if absf(gap) < 0.005 else "%s%.2f s" % ["+" if gap > 0.0 else "-", absf(gap)]
	# Race leadership uses equal-distance elapsed times, not a single fast lap.
	var delta: float = float(data.get("pursuit_split_delta", 0.0))
	var tied := absf(delta) < 0.005
	for i in range(2):
		var leads := (delta < 0.0) if i == 0 else (delta > 0.0)
		pursuit_sides[i].add_theme_stylebox_override("panel", pursuit_tie_style if tied else (pursuit_lead_style if leads else pursuit_trail_style))
		var ink := INK
		pursuit_names[i].add_theme_color_override("font_color", ink)
		pursuit_laps[i].add_theme_color_override("font_color", ink)
		pursuit_stats[i].add_theme_color_override("font_color", ink)

func _build_developer() -> void:
	developer_panel = panel(self, Control.PRESET_CENTER_TOP, -550, 160, 550, 888)
	developer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	developer_panel.add_theme_stylebox_override("panel", style(MenuStyle.PAPER, ACCENT))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	developer_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := text("DEVELOPER HUD", 24, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "X  ·  Sluiten"
	close.custom_minimum_size = Vector2(150, 42)
	close.pressed.connect(toggle_developer)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	developer_body = VBoxContainer.new()
	developer_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_body.add_theme_constant_override("separation", 18)
	scroll.add_child(developer_body)
	developer_panel.hide()

func toggle_developer() -> void:
	developer_enabled = not developer_enabled
	developer_panel.visible = developer_enabled and visible

func set_developer_texts(labels: Array[Label]) -> void:
	for item in labels:
		item.add_theme_font_size_override("font_size", 19)
		item.add_theme_color_override("font_color", INK)
		item.add_theme_constant_override("outline_size", 0)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		developer_body.add_child(item)

static func clock_text(seconds: float) -> String:
	# Integer tenths avoid 00:60.0 on rounding at a minute boundary.
	var tenths: int = maxi(0, int(floor(seconds * 10.0 + 0.00001)))
	var minutes: int = tenths / 600
	return "%02d:%02d.%d" % [minutes, (tenths / 10) % 60, tenths % 10]

static func nearby_ids(order: Array[int], player: int = 0) -> Array[int]:
	if order.is_empty():
		return []
	var count: int = mini(6, order.size())
	if order.size() <= count or order[0] == player:
		return order.slice(0, count)
	# Pin the actual race leader, then reserve five places for the local window.
	var others: Array[int] = order.slice(1)
	var slots: int = count - 1
	var start: int = clampi(others.find(player) - 2, 0, others.size() - slots)
	var result: Array[int] = []
	result.append(order[0])
	for index in range(start, start + slots):
		result.append(others[index])
	return result

func update_race(data: Dictionary) -> void:
	_update_pursuit_bar(data)
	_update_team_laps(data)
	_update_solo(data)
	slipstream_heading.visible = bool(data.get("draft_enabled", true))
	slipstream_bar.visible = bool(data.get("draft_enabled", true))
	var team: bool = bool(data.get("team_mode", false))
	var active: bool = team and bool(data.get("team_active", false))
	var target: float = float(data.get("team_target", -1.0))
	var out: bool = bool(data.get("team_out", false))
	var role := ""
	if active:
		role = "UITBOLLEN · automatisch aansluiten achteraan" if out else ("EERSTE KOPBEURT · stuur rechts om te wisselen" if target < 0.0 else ("Op kop · stuur rechts om te wisselen" if bool(data.get("team_leading", false)) else "Positie %d/%d" % [int(data.get("team_rank", 1)), int(data.get("team_count", 3))]))
	var following: bool = not bool(data.get("team_leading", false))
	power_meter.set_power(float(data["watts"]), target, active and following and not out and target >= 0.0, role)
	status_panel.offset_top = 260.0
	status_panel.offset_bottom = 322.0
	speed_label.text = "%.1f" % float(data.get("speed_kmh", 0.0))
	var maximum: float = maxf(0.01, float(data.get("draft_max", 0.69)) * 100.0)
	var reduction: float = clampf(float(data.get("draft_reduction", 0.0)) * 100.0, 0.0, maximum)
	slipstream_bar.max_value = maximum
	slipstream_bar.value = reduction
	slipstream_label.text = "%d%%" % roundi(reduction)
	slipstream_bar.tooltip_text = "%.0f%% minder luchtweerstand · maximaal %.0f%%" % [reduction, maximum]
	var bpm: Variant = data.get("heart_rate_bpm", null)
	heart_label.text = "%d bpm" % int(bpm) if (bpm is int or bpm is float) and int(bpm) > 0 else "— bpm"
	# Selection alone never means ERG is active. Future bridge integration supplies
	# these two fields only after confirming the actual trainer state.
	var erg_watts: Variant = data.get("erg_target_w", null)
	var erg_active: bool = bool(data.get("erg_active", false)) and (erg_watts is int or erg_watts is float)
	if erg_active:
		erg_active = is_finite(float(erg_watts)) and float(erg_watts) >= 0.0
	gear_label.text = "ERG %.0f W" % float(erg_watts) if erg_active else str(data["gear"])
	gear_label.get_parent().get_child(0).text = "WEERSTAND" if erg_active else "VERSNELLING"
	lap_label.text = "NEUTRAAL" if data.get("neutralised", false) else "%d/%d" % [data["lap"], data["laps"]]
	time_label.text = clock_text(data["seconds"])
	position_label.text = "%d/%d" % [data["position"], data["count"]]
	gap_label.text = data["leader_gap"]
	gap_caption.text = "TOT LAATSTE" if bool(data.get("elimination", false)) else ("PELOTON" if not str(data.get("peloton_gap", "")).is_empty() else "KOPPOSITIE")
	status_label.text = data.get("notice", "")
	status_panel.visible = not status_label.text.is_empty() and signals.countdown_label.text.is_empty()
	map.set_progress(data["distances"])
	map.set_race_leader(data.get("race_positions", []) if bool(data.get("points_race", false)) else [])
	map.set_colors(data["colours"])
	map.set_peloton(data.get("peloton", {}))
	peloton_label.text = str(data.get("peloton_gap", ""))
	peloton_label.visible = not peloton_label.text.is_empty()
	_update_points_standings(data)
	var order: Array[int] = data["order"]
	var ids: Array[int] = nearby_ids(order)
	var positions: Array = data.get("race_positions", [])
	if positions.size() == order.size(): ids = closest_race_ids(order, positions)
	for index in range(rider_rows.size()):
		var row: Dictionary = rider_rows[index]
		row["shell"].visible = index < ids.size()
		if index >= ids.size():
			continue
		var id: int = ids[index]
		row["shell"].set_meta("rider_id", id)
		row["rank"].text = str(order.find(id) + 1)
		row["name"].text = data["names"][id]
		row["name"].tooltip_text = data["names"][id]
		row["marker"].add_theme_color_override("font_color", data["colours"][id])
		row["gap"].text = data["gaps"][id]
		row["shell"].add_theme_stylebox_override("panel", row_player if id == 0 else row_normal)
		for key in ["rank", "name", "gap"]:
			row[key].add_theme_color_override("font_color", MenuStyle.PAPER if id == 0 else (INK if key == "name" else MUTED))

static func closest_race_ids(order: Array[int], positions: Array) -> Array[int]:
	var close: Array[int] = order.duplicate()
	close.sort_custom(func(a: int, b: int) -> bool:
		var first: float = absf(float(positions[a])-float(positions[0]))
		var second: float = absf(float(positions[b])-float(positions[0]))
		return a < b if first == second else first < second)
	close.resize(mini(6,close.size()))
	close.sort_custom(func(a: int, b: int) -> bool: return order.find(a) < order.find(b))
	return close

func _build_points_standings() -> void:
	points_panel = panel(self, Control.PRESET_TOP_RIGHT, -410, 330, -32, 858)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	points_panel.add_child(column)
	column.add_child(text("TUSSENSTAND · PUNTEN", 18, ACCENT))
	for i in range(16):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var rank := text("", 17, MUTED)
		rank.custom_minimum_size.x = 26
		row.add_child(rank)
		var name_label := text("", 17)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		row.add_child(name_label)
		var score := text("", 18, ACCENT)
		score.custom_minimum_size.x = 45
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score)
		points_rows.append({"row":row,"rank":rank,"name":name_label,"score":score})
	points_panel.hide()

func _update_points_standings(data: Dictionary) -> void:
	points_panel.visible = bool(data.get("points_race", false))
	if not points_panel.visible: return
	var order: Array = data.get("points_order", [])
	var scores: Array = data.get("point_scores", [])
	points_panel.offset_bottom = 330 + minf(528.0, 80.0+order.size()*26.0)
	for i in range(points_rows.size()):
		var row: Dictionary = points_rows[i]
		row.row.visible = i < order.size()
		if i >= order.size(): continue
		var id: int = int(order[i])
		row.rank.text = str(i+1)
		row.name.text = data.names[id]
		row.name.add_theme_color_override("font_color", ACCENT if id == 0 else INK)
		row.score.text = str(scores[id])
