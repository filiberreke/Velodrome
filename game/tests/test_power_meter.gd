extends SceneTree
const Meter := preload("res://power_meter.gd")
const Game := preload("res://main.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	check(is_equal_approx(Meter.fraction(600), 0.9), "600 W uses 90 percent")
	check(is_equal_approx(Meter.fraction(300), 0.45), "300 W target at 45 percent")
	check(is_equal_approx(Meter.fraction(1050), 0.95), "Upper range compressed")
	check(Meter.fraction(-50) == 0 and Meter.fraction(2000) == 1, "Display clamps outside scale")
	check(Meter.zone_color(100) == Color.WHITE and Meter.zone_color(101) == Meter.GREEN, "White and light green bands")
	check(Meter.zone_color(430) == Meter.RED and Meter.zone_color(700) == Color("7b1727"), "Red and dark red bands")
	var game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var ui = game.race_overlay
	var meter = ui.power_meter
	for power in [0.0, 100.0, 430.0, 600.0, 1500.0, 1900.0]:
		meter.set_power(power)
		await process_frame
		check(absf(meter.value_label.get_rect().get_center().x - meter.size.x * 0.5) < 0.1, "Watts stay centered independent of fill")
		check(meter.value_label.text == "%.0f W" % power, "Actual number is not clamped to scale")
	meter.set_power(279.9, 300, true)
	check(meter.fill_color == Meter.RED, "Below tolerance red")
	meter.set_power(280, 300, true)
	check(meter.fill_color == Meter.GREEN, "20 W below target green")
	meter.set_power(900, 300, true)
	check(meter.fill_color == Meter.GREEN, "Above target remains green")
	meter.set_power(430)
	check(meter.fill_color == Meter.RED and not meter.target_visible, "Ordinary zones restored")
	check(meter.get_global_rect().position.x > ui.power_panel.get_global_rect().end.x, "Meter between personal box and minimap")
	check(meter.get_global_rect().end.x < ui.map_panel.get_global_rect().position.x, "Meter does not overlap minimap")
	check(not ui.map_panel is PanelContainer and ui.map_panel.get_child_count() == 1, "Minimap has no panel or heading")
	game.setup_panel.select_mode(2)
	var options = game.setup_panel.team_options
	check(options.resistance_mode() == "MANUAL", "Manual default")
	options.resistance_choice.select(1)
	options.resistance_choice.item_selected.emit(1)
	check(options.resistance_mode() == "ERG" and "nog niet beschikbaar" in options.resistance_hint.text, "Prepared ERG option explained")
	await process_frame
	await process_frame
	check(game.setup_panel.start_button.get_global_rect().end.y <= 1080.1, "Expanded menu fits screen")
	game._confirm_start(); game.broadcast_intro.finish()
	check(game.team_resistance_mode == "ERG", "Preference stored on actual race start")
	game._update_hud()
	check(not ui.gear_label.text.begins_with("ERG"), "Menu preference never falsely claims active ERG")
	# Same public HUD input the future bridge integration will supply.
	var order: Array[int] = []
	var data := {"watts": 290.0, "gear": "4", "erg_active": true, "erg_target_w": 300, "team_mode": true, "team_active": true, "team_target": 300.0, "lap": 1, "laps": 4, "seconds": 10.0, "position": 1, "count": 2, "leader_gap": "", "distances": game.distances, "colours": ui.map.rider_colours, "names": [], "order": [], "gaps": []}
	data["order"] = order
	ui.update_race(data)
	check(ui.gear_label.text == "ERG 300 W", "Confirmed active ERG replaces gear")
	check(meter.target_visible and meter.target_label.text == "300 W", "Follower sees target")
	data["team_leading"] = true
	data["watts"] = 150.0
	ui.update_race(data)
	check(not meter.target_visible and meter.target_label.text.is_empty() and meter.fill_color == Meter.zone_color(150.0), "Returning to head hides target and restores normal colour")
	data["team_leading"] = false
	ui.update_race(data)
	check(meter.target_visible and meter.fill_color == Meter.RED, "Following again restores target and deficit colour")
	data["team_out"] = true
	ui.update_race(data)
	check(not meter.target_visible, "Coasting during exchange hides target")
	data["erg_target_w"] = null
	ui.update_race(data)
	check(ui.gear_label.text == "4", "Missing ERG value falls back to gear")
	game.free()
	print("POWER_METER_OK" if failures == 0 else "POWER_METER_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
