extends SceneTree

const HUD := preload("res://race_hud.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	var hud := HUD.new()
	root.add_child(hud)
	var order: Array[int] = [0]
	var distances: Array[float] = [0.0]
	var colours: Array[Color] = [Color.WHITE]
	var data := {"watts": 250.0, "gear": "12", "lap": 1, "laps": 4,
		"seconds": 0.0, "position": 1, "count": 1, "leader_gap": "Aan kop",
		"order": order, "distances": distances, "names": ["Speler"], "gaps": [""], "colours": colours}
	hud.update_race(data)
	await process_frame
	var trainer_size := hud.power_panel.size
	check(hud.gear_label.get_parent().visible and not hud.energy_panel.visible, "Legacy HUD keeps gear row")
	check(hud.gear_label.text == "12", "Trainer gear value unchanged")
	check(hud.gear_label.get_parent().get_child(0).text == "VERSNELLING", "Trainer caption unchanged")
	data.pc_control = true
	data.watts = 900.0
	data.pc_delivered_watts = 240.0
	data.pc_power_limit_watts = 240.0
	for reserve in [1.0, 0.425, 0.0, -0.5, 1.5]:
		data.pc_energy_fraction = reserve
		hud.update_race(data)
		var expected: float = clampf(reserve, 0.0, 1.0) * 100.0
		check(hud.energy_panel.visible and not hud.gear_label.get_parent().visible, "PC energy replaces entire gear row")
		check(is_equal_approx(hud.energy_bar.value, expected), "Energy bar follows reserve, bounded to 0–100")
		check(hud.energy_label.text == "%d%%" % roundi(expected), "Energy percentage matches bar")
		check(hud.power_meter.value_label.text == "240 W", "PC meter shows delivered power, not requested 900 W")
		check(hud.power_meter.limit_label.text == "MAX 240 W · gevraagd 900 W", "PC ceiling and blocked request are explicit")
	for reserve in [0.21, 0.20, 0.15, 0.10, 0.05, 0.0, 0.25]:
		data.pc_energy_fraction = reserve
		hud.update_race(data)
		var warning: String = hud.power_meter.warning_text
		check(warning.is_empty() == (reserve > 0.20), "Warning clears above 20 percent, including after recovery")
		if reserve == 0.20: check(warning.begins_with("ENERGIE LAAG"), "20 percent warning")
		if reserve == 0.10: check(warning.begins_with("ENERGIE KRITIEK"), "10 percent critical warning")
		if reserve == 0.0: check(warning.begins_with("ENERGIE LEEG"), "Empty reserve warning")
	for reserve in [null, NAN, INF]:
		data.pc_energy_fraction = reserve
		hud.update_race(data)
		check(hud.energy_bar.value == 0.0 and hud.energy_label.text == "—", "Unavailable reserve is not shown as full")
	data.pc_control = false
	data.pc_energy_fraction = 0.0
	data.gear = "50×15"
	hud.update_race(data)
	await process_frame
	check(not hud.energy_panel.visible and hud.gear_label.get_parent().visible, "Switch to trainer restores gear row")
	check(hud.power_panel.size == trainer_size, "Hidden energy bar preserves trainer panel layout")
	check(hud.gear_label.text == "50×15", "Trainer ratio label unchanged")
	check(hud.power_meter.value_label.text == "900 W", "Trainer uses measured watts without PC cap")
	check(not hud.power_meter.limit_label.visible and hud.power_meter.warning_text.is_empty(), "Trainer has no PC limit or energy warning")
	data.erg_active = true
	data.erg_target_w = 300.0
	hud.update_race(data)
	check(hud.gear_label.text == "ERG 300 W", "Existing ERG value unchanged")
	check(hud.gear_label.get_parent().get_child(0).text == "WEERSTAND", "Existing ERG caption unchanged")
	data.erg_active = false
	data.gear = "—"
	hud.update_race(data)
	check(hud.gear_label.text == "—" and not hud.energy_panel.visible, "Trainer disconnect keeps gear placeholder")
	# The team target remains usable alongside the PC ceiling and low-energy warning.
	data.pc_control = true
	data.pc_energy_fraction = 0.10
	data.team_mode = true
	data.team_active = true
	data.team_target = 300.0
	data.team_leading = false
	hud.update_race(data)
	await process_frame
	check(hud.power_meter.target_visible and hud.power_meter.target_label.text == "300 W", "PC fatigue keeps team target visible")
	check(hud.power_meter.limit_label.visible and hud.power_meter.warning_text.begins_with("ENERGIE KRITIEK"), "Team target, ceiling and energy warning coexist")
	check(hud.power_meter.target_label.get_global_rect().end.x <= hud.power_meter.limit_label.get_global_rect().end.x - hud.power_meter.limit_label.get_minimum_size().x, "Ceiling caption does not overlap team target")
	hud.free()
	if failures == 0: print("PC_ENERGY_HUD_OK")
	quit(0 if failures == 0 else 1)
