extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	root.size = Vector2i(1920,1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	await process_frame; await process_frame
	var menu = game.setup_panel
	menu.cards[5].pressed.emit()
	check(menu.get("elimination_assist_toggle") == null, "Elimination offers manual steering only")
	menu.elimination_count_picker.select(0)
	game._confirm_start()
	check(game.race_mode == 2, "Elimination starts with manual steering")
	game.broadcast_intro.finish()
	game.start_state = "RACING"; game.running = true; game.clock = 30.0
	game.player_lane = 10; game._update_hud()
	check(game.hud.text.contains("Rijlijn: 11/11"), "HUD shows the selected lane and actual lane count")
	game.player_lane = 0
	game.distances.assign([100.0,90.0,80.0,70.0])
	check(game._hud_elimination_gap() == "+30.0 m", "HUD uses last opponent, not leader")
	game.finish_times[3] = 20.0
	check(game._hud_elimination_gap() == "+20.0 m", "HUD excludes eliminated riders")
	game.distances[0] = 60.0
	check(game._hud_elimination_gap() == "-20.0 m", "Last player sees negative gap to next active rider")
	var order: Array[int] = [1,2,0,3]
	game._update_compact_hud(order)
	check(game.race_overlay.gap_caption.text == "TOT LAATSTE", "Elimination HUD caption is explicit")
	game.lane_offsets[0] = game.LANES[0]
	game._steer_player(1)
	check(game.player_lane == 1, "Keyboard selects the next manual lane")
	game._process_steering(-40.0)
	check(game.player_lane == 0, "Ride steering selects the previous lane")
	game.clock = 31.0; game._process_steering(-40.0)
	check(game.player_lane == 0, "Held Ride pressure does not count as a new paddle press")
	game._process_steering(0.0)
	game._process_steering(40.0)
	check(game.player_lane == 1, "A new paddle press after release selects one lane")
	game.elimination_notice.text = "AFGEVALLEN · OUD"; game.elimination_notice.show(); game.elimination_notice_until = 100.0
	game._reset()
	check(game.elimination_notice.text.is_empty() and not game.elimination_notice.visible and game.elimination_notice_until < 0.0, "Restart clears old elimination banner")
	game.elimination_notice.text = "AFGEVALLEN · OUD"; game.elimination_notice.show()
	game._set_menu_visible(true)
	check(game.elimination_notice.text.is_empty() and not game.elimination_notice.visible, "Menu entry clears old elimination banner")
	menu.cards[5].pressed.emit(); game._confirm_start()
	game._reset(); menu.cards[0].pressed.emit()
	check(menu.get("elimination_assist_toggle") == null, "Scratch setup hides elimination-only option")
	game.free()
	print("ELIMINATION_CORRECTIONS failures=", failures)
	quit(0 if failures == 0 else 1)
