extends Node3D
## Madison prototype demo (GRAB + SLING + RELEASE): two real Velodrome riders, a sling_t slider, and a minimal
## debug timing bar that reads the SAME variables as the animation (sling_t -> MadisonProfile.slider_width).
## Run: godot --path game res://madison/madison_demo.tscn
## Capture screenshots: godot --path game res://madison/madison_demo.tscn -- --capture=<dir>

var pair: MadisonPair
var runner: MadisonScenarioRunner
var _flow := false
var _flow_name := ""
var cam: Camera3D
var sl_t: HSlider
var sl_dev: HSlider
var opt_gap: OptionButton
var chk_ik: CheckBox
var chk_drift: CheckBox
var lbl_info: Label
var lbl_bar: Label
var bar_inner: ColorRect
var bar_bg: ColorRect
var peak_marker: ColorRect
const BAR_W := 800.0
const UI_W := 1920.0   # project uses canvas_items stretch with a 1920x1080 base
const GAPS: Array[float] = [1.2, 1.0, 1.4, 1.5]
var _busy := false
var _drift_time := 0.0

func _ready() -> void:
	_build_world()
	pair = MadisonPair.new()
	add_child(pair)
	await pair.build(get_tree())
	runner = MadisonScenarioRunner.new()
	add_child(runner)
	await runner.build(get_tree())
	runner.visible = false
	pair.rpm = 75.0
	_build_ui()
	_set_camera("front")
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--capture="):
			await _capture(a.trim_prefix("--capture="))
			get_tree().quit()
			return

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.56, 0.68, 0.80)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.74, 0.55, 0.36)      # track-wood tone
	floor_mesh.material_override = m
	add_child(floor_mesh)
	# lane lines every 0.60 m (the player's lateral step) so the gap is readable
	for i in range(-6, 3):
		var line := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(0.015, 30)
		line.mesh = q
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.2, 0.35, 0.8) if i == 0 else Color(0.95, 0.95, 0.95)
		line.material_override = lm
		line.position = Vector3(-0.0 + float(i) * 0.6 + 0.3, 0.002, 0)
		add_child(line)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)

func _set_camera(preset: String) -> void:
	var gap := pair.gap
	var mid := Vector3(-gap * 0.5, 0.95, 0.35)
	match preset:
		"front":
			cam.position = mid + Vector3(1.55, 0.35, 2.7)
		"side":
			cam.position = mid + Vector3(3.2, 0.2, 0.2)
		"top":
			cam.position = mid + Vector3(0.0, 3.6, 0.9)
		"back":
			cam.position = mid + Vector3(-1.5, 0.5, -2.6)
	cam.look_at(mid, Vector3.UP)

# ---------------------------------------------------------------------------------------------- UI
func _label(parent: Control, text: String, pos: Vector2, size: Vector2 = Vector2(320, 22)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_label(root, "Madison prototype - GRAB + SLING + RELEASE", Vector2(16, 10), Vector2(600, 24))
	# HUD debug timing bar (reads sling_t only)
	var bar_x := (UI_W - BAR_W) * 0.5
	lbl_bar = _label(root, "", Vector2(bar_x, 930), Vector2(BAR_W, 22))
	bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.position = Vector2(bar_x, 958)
	bar_bg.size = Vector2(BAR_W, 26)
	root.add_child(bar_bg)
	bar_inner = ColorRect.new()
	bar_inner.color = Color(0.2, 0.85, 0.35)
	bar_inner.position = Vector2(2, 3)
	bar_inner.size = Vector2(BAR_W, 20)
	bar_bg.add_child(bar_inner)
	var sweet := ColorRect.new()
	sweet.color = Color(1, 1, 1, 0.9)
	sweet.position = Vector2(BAR_W * 0.5 - 1, -4)
	sweet.size = Vector2(2, 34)
	bar_bg.add_child(sweet)
	# controls
	var x := 16.0
	var y := 44.0
	_label(root, "sling_t", Vector2(x, y))
	sl_t = HSlider.new()
	sl_t.min_value = 0.0
	sl_t.max_value = 1.0
	sl_t.step = 0.001
	sl_t.position = Vector2(x + 70, y + 4)
	sl_t.size = Vector2(300, 18)
	root.add_child(sl_t)
	peak_marker = ColorRect.new()
	peak_marker.color = Color(1, 0.85, 0.1)
	peak_marker.position = Vector2(x + 70 + 8 + (300 - 16) * MadisonProfile.PEAK_T - 1, y + 2)
	peak_marker.size = Vector2(2, 22)
	root.add_child(peak_marker)
	_label(root, "peak", Vector2(x + 70 + (300 - 16) * MadisonProfile.PEAK_T - 6, y + 24), Vector2(60, 18))
	y += 52
	_label(root, "gap (m)", Vector2(x, y))
	opt_gap = OptionButton.new()
	for g in GAPS:
		opt_gap.add_item("%.2f" % g)
	opt_gap.position = Vector2(x + 70, y - 2)
	opt_gap.item_selected.connect(func(i: int) -> void:
		pair.gap = GAPS[i])
	root.add_child(opt_gap)
	y += 36
	_label(root, "speed diff (m)", Vector2(x, y))
	sl_dev = HSlider.new()
	sl_dev.min_value = -0.8
	sl_dev.max_value = 1.0
	sl_dev.step = 0.01
	sl_dev.value = 0.0
	sl_dev.position = Vector2(x + 110, y + 4)
	sl_dev.size = Vector2(260, 18)
	root.add_child(sl_dev)
	y += 30
	chk_drift = CheckBox.new()
	chk_drift.text = "dynamic drift (receiver sways +-0.35 m)"
	chk_drift.position = Vector2(x, y)
	root.add_child(chk_drift)
	y += 28
	chk_ik = CheckBox.new()
	chk_ik.text = "hand IK on"
	chk_ik.button_pressed = true
	chk_ik.position = Vector2(x, y)
	root.add_child(chk_ik)
	y += 36
	for spec in [["Play sling", "_play_sling"], ["Release", "_play_release"], ["Front", "_cam_front"], ["Top", "_cam_top"], ["Side", "_cam_side"]]:
		var b := Button.new()
		b.text = spec[0]
		b.position = Vector2(x, y)
		b.pressed.connect(Callable(self, spec[1]))
		root.add_child(b)
		x += b.get_minimum_size().x + 6
	x = 16.0
	y += 34
	for spec in [["A perfect", "_sc_a"], ["B too early", "_sc_b"], ["C too long", "_sc_c"], ["D 0.60 m", "_sc_d06"], ["D 1.20 m", "_sc_d12"], ["D 1.80 m", "_sc_d18"], ["Easy", "_sc_easy"], ["Advanced: hold A / Space", "_sc_manual"]]:
		var b2 := Button.new()
		b2.text = spec[0]
		b2.position = Vector2(x, y)
		b2.pressed.connect(Callable(self, spec[1]))
		root.add_child(b2)
		x += b2.get_minimum_size().x + 6
	lbl_info = _label(root, "", Vector2(1380, 44), Vector2(520, 170))

func _sc_a() -> void: _run_scenario("A", 1.2)
func _sc_b() -> void: _run_scenario("B", 1.2)
func _sc_c() -> void: _run_scenario("C", 1.2)
func _sc_d06() -> void: _run_scenario("D", 0.6)
func _sc_d12() -> void: _run_scenario("D", 1.2)
func _sc_d18() -> void: _run_scenario("D", 1.8)
func _sc_easy() -> void: _run_scenario("E", 1.2)
func _sc_manual() -> void: _run_scenario("M", 1.2)

## Hands the scene over to the MadisonDemoExchange controller (scenario runner) and back afterwards.
func _run_scenario(name: String, gap: float) -> void:
	if _flow or _busy:
		return
	_flow = true
	_flow_name = "%s  gap %.2f m" % [name, gap]
	pair.rg.detach()
	pair.rr.detach()
	pair.visible = false
	runner.visible = true
	pair.gap = gap
	_set_camera("front")
	var m: Dictionary = await runner.run(name, gap, false)
	lbl_info.text = "scenario %s done
release at sling_t %.2f  efficiency %.2f  (%s)
events: %s" % [_flow_name, m["release_sling_t"], m["release_efficiency"], m["release_reason"], " ".join(PackedStringArray(m["events"].map(func(e): return str(e))))]
	_flow = false
	runner.visible = false
	pair.visible = true
	pair.rg.attach(pair.giver, "giver", pair.contact)
	pair.rr.attach(pair.recv, "receiver", pair.contact)
	for r in [pair.rg, pair.rr]:
		r.overlay = 1.0
		r.mix_sling = 1.0

func _cam_front() -> void: _set_camera("front")
func _cam_top() -> void: _set_camera("top")
func _cam_side() -> void: _set_camera("side")

# ---------------------------------------------------------------------------------------------- behaviour
func _process(delta: float) -> void:
	if pair == null or pair.rg == null or sl_t == null:
		return
	if _flow:
		_update_flow_hud()
		return
	if not _busy:
		pair.sling_t = sl_t.value
		pair.ik_weight = 1.0 if chk_ik.button_pressed else 0.0
		_drift_time += delta
		var dz := sl_dev.value + (0.35 * sin(_drift_time * 1.6) if chk_drift.button_pressed else 0.0)
		pair.deviation = Vector3(0, 0, dz)
	else:
		sl_t.set_value_no_signal(pair.sling_t)
	pair.step(delta)
	_update_hud()

func _update_flow_hud() -> void:
	var ex := runner.ex
	var t := ex.sling_t
	var w := MadisonProfile.slider_width(t)
	bar_inner.size.x = (BAR_W - 4.0) * w
	bar_inner.position.x = 2.0 + (BAR_W - 4.0 - bar_inner.size.x) * 0.5
	bar_inner.color = Color(0.2, 0.85, 0.35) if t <= MadisonProfile.PEAK_T else Color(0.95, 0.55, 0.15)
	lbl_bar.text = "timing bar  width %.2f   (sling_t %.3f, efficiency %.3f)" % [w, t, MadisonProfile.efficiency(t)]
	sl_t.set_value_no_signal(t)
	lbl_info.text = "scenario %s
state %s   mode %s
approach_t %.2f  sling_t %.2f  release_t %.2f
grab window %s
lateral gap %.2f  visual gap %.2f
speed giver %.1f  receiver %.1f" % [_flow_name, MadisonDemoExchange.State.keys()[ex.state], MadisonDemoExchange.Mode.keys()[ex.mode], ex.approach_t, ex.sling_t, ex.release_t, "OPEN" if ex.grab_window_open else "-", ex.lateral_gap, ex.visual_gap, ex.speed_giver, ex.speed_receiver]

func _update_hud() -> void:
	var t := pair.sling_t
	var w := MadisonProfile.slider_width(t)
	bar_inner.size.x = (BAR_W - 4.0) * w
	bar_inner.position.x = 2.0 + (BAR_W - 4.0 - bar_inner.size.x) * 0.5
	bar_inner.color = Color(0.2, 0.85, 0.35) if t <= MadisonProfile.PEAK_T else Color(0.95, 0.55, 0.15)
	lbl_bar.text = "timing bar  width %.2f   (sling_t %.3f, efficiency %.3f)" % [w, t, MadisonProfile.efficiency(t)]
	var e := pair.errors_mm()
	var s := pair.stretch()
	lbl_info.text = "contact error  giver %.1f mm  receiver %.1f mm\narm stretch    giver %.2f  receiver %.2f\ngap %.2f m   deviation %.2f m\nIK %s%s" % [e.x, e.y, s.x, s.y, pair.gap, pair.deviation.z,
		"on" if pair.ik_weight > 0.5 else "off", "   CLAMPED (release early)" if (pair.rg.ik.last_clamped or pair.rr.ik.last_clamped) and pair.ik_weight > 0.5 else ""]

func _play_sling() -> void:
	if _busy:
		return
	_busy = true
	for r in [pair.rg, pair.rr]:
		r.release_t = 0.0
		r.mix_release = 0.0
		r.overlay = 1.0
	var frames := 150
	for f in frames + 1:
		pair.sling_t = float(f) / frames
		await get_tree().process_frame
	_busy = false

func _play_release() -> void:
	if _busy:
		return
	_busy = true
	var t0 := pair.sling_t
	var xf := roundi(60.0 * MadisonProfile.release_crossfade_seconds(t0))
	var total := xf + 45
	for f in total + 19:
		var x := clampf(float(f - xf) / 45.0, 0.0, 1.0)
		for r in [pair.rg, pair.rr]:
			r.release_t = x
			r.mix_release = smoothstep(0.0, 1.0, float(f) / xf)
			r.overlay = 1.0 if f <= total else 1.0 - smoothstep(0.0, 1.0, float(f - total) / 18.0)
		pair.ik_weight = 1.0 - smoothstep(0.0, 1.0, float(f) / xf)
		await get_tree().process_frame
	for r in [pair.rg, pair.rr]:
		r.release_t = 0.0
		r.mix_release = 0.0
		r.overlay = 1.0
	_busy = false

# ---------------------------------------------------------------------------------------------- screenshots
func _shot(path: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _state(t: float, dev: float = 0.0, ik: bool = true, gap: float = 1.2) -> void:
	_busy = false
	sl_t.value = t
	sl_dev.value = dev
	chk_ik.button_pressed = ik
	pair.gap = gap
	for r in [pair.rg, pair.rr]:
		r.release_t = 0.0
		r.mix_release = 0.0
		r.overlay = 1.0

func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [
		["grab_t0.00", 0.0, 0.0, true, 1.2, "front"], ["sling_t0.30", 0.3, 0.0, true, 1.2, "front"],
		["sling_t0.60_peak", 0.6, 0.0, true, 1.2, "front"], ["sling_t0.80", 0.8, 0.0, true, 1.2, "front"],
		["sling_t1.00_overheld", 1.0, 0.0, true, 1.2, "front"],
		["sling_t0.60_top", 0.6, 0.0, true, 1.2, "top"], ["sling_t0.60_side", 0.6, 0.0, true, 1.2, "side"],
		["dynamic_dev+0.30", 0.6, 0.3, true, 1.2, "top"], ["dynamic_dev-0.40", 0.6, -0.4, true, 1.2, "top"],
		["dynamic_dev+0.30_noIK", 0.6, 0.3, false, 1.2, "top"],
		["clamped_dev+1.00", 0.6, 1.0, true, 1.2, "top"],
		["gap1.40_t0.60", 0.6, 0.0, true, 1.4, "front"],
	]
	for s in shots:
		_state(s[1], s[2], s[3], s[4])
		_set_camera(s[5])
		for i in 6:
			await get_tree().process_frame
		await _shot(dir.path_join(s[0] + ".png"))
		print("captured ", s[0], " | ", lbl_info.text.replace("\n", " | "), " | ", lbl_bar.text)
	# flow shots through the controller
	await _capture_flow(dir, "A", 1.2, "front")
	await _capture_flow(dir, "D", 0.6, "front")
	await _capture_flow(dir, "D", 1.8, "front")
	# release strip
	_state(0.6)
	_set_camera("front")
	_busy = false
	var t0 := 0.6
	var xf := roundi(60.0 * MadisonProfile.release_crossfade_seconds(t0))
	_busy = true
	var marks := [0, xf / 2, xf, xf + 22, xf + 45]
	var total := xf + 45
	for f in total + 1:
		var x := clampf(float(f - xf) / 45.0, 0.0, 1.0)
		for r in [pair.rg, pair.rr]:
			r.release_t = x
			r.mix_release = smoothstep(0.0, 1.0, float(f) / xf)
		pair.ik_weight = 1.0 - smoothstep(0.0, 1.0, float(f) / xf)
		await get_tree().process_frame
		if f in marks:
			await _shot(dir.path_join("release_from_peak_f%02d.png" % f))
	_busy = false

func _capture_flow(dir: String, name: String, gap: float, cam_preset: String) -> void:
	var tag := "flow_%s_gap%.2f" % [name, gap]
	_run_scenario(name, gap)
	_set_camera(cam_preset)
	var want := {"approach": 0.45, "grab": true, "peak": true, "release": true, "separate": true}
	var ex := runner.ex
	var guard := 0
	while (_flow or ex.state != MadisonDemoExchange.State.IDLE) and guard < 900:
		guard += 1
		await get_tree().process_frame
		if ex.state == MadisonDemoExchange.State.APPROACH and want["approach"] is float and ex.approach_t >= 0.45:
			want["approach"] = false
			await _shot(dir.path_join(tag + "_1_approach.png"))
		elif ex.state == MadisonDemoExchange.State.SLING and want["grab"] == true and ex.sling_t >= 0.05:
			want["grab"] = false
			await _shot(dir.path_join(tag + "_2_grabbed.png"))
		elif ex.state == MadisonDemoExchange.State.SLING and want["peak"] == true and ex.sling_t >= 0.58:
			want["peak"] = false
			await _shot(dir.path_join(tag + "_3_sling_peak.png"))
		elif ex.state == MadisonDemoExchange.State.RELEASE and want["release"] == true and ex.release_t >= 0.3:
			want["release"] = false
			await _shot(dir.path_join(tag + "_4_release.png"))
		elif ex.state == MadisonDemoExchange.State.SEPARATE and want["separate"] == true and ex._t_state >= 0.15:
			want["separate"] = false
			await _shot(dir.path_join(tag + "_5_separate.png"))
	while _flow:
		await get_tree().process_frame
