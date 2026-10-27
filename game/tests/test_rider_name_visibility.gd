extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := preload("res://main.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._set_menu_visible(false)
	game.start_state = "RACING"
	game.camera.position = Vector3(0, 5, -4)
	for i in range(game.bikes.size()): game.bikes[i].position = Vector3(i,0,0)
	game._update_bunch_presentation()
	check(game.rider_name_mode == 0 and not game._rider_label_visible(1), "Auto must suppress dense bunch")
	check(not game.rider_energy_badges[1].visible, "Energy name cards must also hide")
	game.bikes[1].position = Vector3(0,0,25)
	game._update_bunch_presentation()
	check(game._rider_label_visible(1) and game.rider_energy_badges[1].visible, "Solo rider must retain name and stats")
	check(not game._rider_label_visible(0), "Own HUD should not be duplicated")
	var positions: Array[float] = game.distances.duplicate()
	var key := InputEventKey.new()
	key.keycode = KEY_V; key.pressed = true
	game._unhandled_key_input(key)
	check(game.rider_name_mode == 1 and game._rider_label_visible(2), "V enables all names")
	check(not game._rider_label_visible(0) and not game.rider_energy_badges[0].visible, "All names must still exclude player name/power card")
	key.echo = true; game._unhandled_key_input(key)
	check(game.rider_name_mode == 1, "Key repeat must not cycle repeatedly")
	key.echo = false; game._unhandled_key_input(key)
	check(game.rider_name_mode == 2 and not game.rider_energy_badges[1].visible, "V disables all names")
	game._unhandled_key_input(key)
	check(game.rider_name_mode == 0 and game.distances == positions, "Cycle returns to Auto without race changes")
	game.broadcast_intro.start()
	game.rider_name_mode = 1
	check(not game._rider_label_visible(1), "Cinematic suppresses forced labels")
	game._reset()
	check(game.rider_name_mode == 1, "Display preference survives race reset")
	game.free()
	if failures == 0: print("RIDER_NAME_VISIBILITY_OK")
	quit(0 if failures == 0 else 1)
