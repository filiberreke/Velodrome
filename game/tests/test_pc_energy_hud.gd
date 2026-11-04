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
	for reserve in [1.0, 0.425, 0.0, -0.5, 1.5]:
		data.pc_energy_fraction = reserve
		hud.update_race(data)
		var expected: float = clampf(reserve, 0.0, 1.0) * 100.0
		check(hud.energy_panel.visible and not hud.gear_label.get_parent().visible, "PC energy replaces entire gear row")
		check(is_equal_approx(hud.energy_bar.value, expected), "Energy bar follows reserve, bounded to 0–100")
		check(hud.energy_label.text == "%d%%" % roundi(expected), "Energy percentage matches bar")
	for reserve in [null, NAN, INF]:
		data.pc_energy_fraction = reserve
		hud.update_race(data)
		check(hud.energy_bar.value == 0.0 and hud.energy_label.text == "—", "Unavailable reserve is not shown as full")
	data.pc_control = false
	data.gear = "50×15"
	hud.update_race(data)
	await process_frame
	check(not hud.energy_panel.visible and hud.gear_label.get_parent().visible, "Switch to trainer restores gear row")
	check(hud.power_panel.size == trainer_size, "Hidden energy bar preserves trainer panel layout")
	check(hud.gear_label.text == "50×15", "Trainer ratio label unchanged")
	data.erg_active = true
	data.erg_target_w = 300.0
	hud.update_race(data)
	check(hud.gear_label.text == "ERG 300 W", "Existing ERG value unchanged")
	check(hud.gear_label.get_parent().get_child(0).text == "WEERSTAND", "Existing ERG caption unchanged")
	data.erg_active = false
	data.gear = "—"
	hud.update_race(data)
	check(hud.gear_label.text == "—" and not hud.energy_panel.visible, "Trainer disconnect keeps gear placeholder")
	hud.free()
	if failures == 0: print("PC_ENERGY_HUD_OK")
	quit(0 if failures == 0 else 1)
