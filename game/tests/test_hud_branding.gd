extends SceneTree
const HUD := preload("res://race_hud.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	root.content_scale_size = Vector2i(1920,1080)
	var ui := HUD.new()
	root.add_child(ui)
	await process_frame
	await process_frame
	var skin: StyleBoxFlat = ui.power_panel.get_theme_stylebox("panel")
	check(is_equal_approx(skin.bg_color.a, 0.75) and skin.bg_color.r > 0.9, "Ivory HUD surfaces have 75 percent opacity")
	check(ui.power_meter.get_parent() == ui and not ui.power_meter is PanelContainer, "Power bar has no enclosing panel")
	check(ui.lap_label.get_parent().get_parent() == ui.map, "Lap counter is inside the miniature track")
	check(ui.map.get_global_rect().has_point(ui.lap_label.get_global_rect().get_center()), "Lap counter stays within map")
	check(ui.bottom_bar.find_child("HudShortcuts", true, false) != null, "Keyboard shortcuts are in bottom bar")
	var shortcuts = ui.bottom_bar.find_child("HudShortcuts", true, false)
	check(shortcuts.get_child(0).text == "ESC · Pauze" and shortcuts.get_child(1).text == "F10 - Instellingen", "F10 appears below ESC")
	var cues = ui.signals
	cues.set_process(false)
	for value in ["3","2","1","START!"]:
		cues.set_countdown(value)
		check(cues.countdown_label.visible and cues.countdown_label.text == value, "Full-screen countdown: "+value)
	check(cues.countdown_label.get_rect().size == ui.size, "Countdown occupies full HUD independently of camera")
	cues.set_countdown("")
	check(not cues.countdown_label.visible, "Countdown disappears after start")
	cues.update_last_lap(true,251.0,2500.0,false)
	check(not cues.bell.visible, "Bell waits until player's final lap")
	cues.update_last_lap(true,250.0,2500.0,false)
	check(cues.bell.visible and cues.last_lap_announced, "Final-lap crossing announces bell")
	cues._process(0.15)
	check(absf(cues.bell.rotation) > 0.05, "Bell swings")
	check(cues.bell.texture != null and cues.bell.size.x <= 430.0, "Golden bell uses approved half-size asset")
	cues._process(3.0)
	check(not cues.bell.visible, "Bell clears after its short announcement")
	cues.update_last_lap(true,200.0,2500.0,false)
	check(not cues.bell.visible, "Bell does not repeat on every HUD update")
	cues.clear()
	cues.update_last_lap(true,250.0,2500.0,false)
	check(cues.bell.visible, "New race resets bell trigger")
	cues.update_last_lap(true,0.0,2500.0,true)
	check(not cues.bell.visible, "Finish clears bell")
	cues.clear()
	cues.update_last_lap(false,200.0,2500.0,false)
	check(not cues.bell.visible and not cues.last_lap_announced, "Setup and neutral phases cannot trigger bell")
	ui.free()
	print("HUD_BRANDING_OK" if failures == 0 else "HUD_BRANDING_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
