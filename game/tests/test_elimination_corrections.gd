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
	check(menu.elimination_assist_toggle.visible and not menu.elimination_assist_toggle.button_pressed, "Elimination setup has default-off assist toggle")
	menu.elimination_count_picker.select(0)
	menu.elimination_assist_toggle.button_pressed = true
	game._confirm_start()
	check(game.race_mode == 2 and game.elimination_assist.enabled, "Start reads the chosen assist setting")
	game.broadcast_intro.finish()
	game.start_state = "RACING"; game.running = true; game.clock = 30.0
	game.distances.assign([100.0,90.0,80.0,70.0])
	check(game._hud_elimination_gap() == "+30.0 m", "HUD uses last opponent, not leader")
	game.finish_times[3] = 20.0
	check(game._hud_elimination_gap() == "+20.0 m", "HUD excludes eliminated riders")
	game.distances[0] = 60.0
	check(game._hud_elimination_gap() == "-20.0 m", "Last player sees negative gap to next active rider")
	var order: Array[int] = [1,2,0,3]
	game._update_compact_hud(order)
	check(game.race_overlay.gap_caption.text == "TOT LAATSTE", "Elimination HUD caption is explicit")
	game.elimination_assist.target = game.LANES[1]
	game.lane_offsets[0] = game.LANES[0]
	game._steer_player(1)
	check(game.player_lane == 1 and game.elimination_assist.manual_until == 32.0 and game.elimination_assist.target < 0.0, "Keyboard immediately overrides assist from actual lane")
	game._process_steering(-40.0)
	check(game.player_lane == 0, "Ride steering overrides assist")
	game.clock = 31.0; game._process_steering(-40.0)
	check(game.elimination_assist.manual_until == 32.0 and game.player_lane == 0, "Held Ride pressure does not count as a new paddle press")
	game._process_steering(0.0)
	game._process_steering(40.0)
	check(game.elimination_assist.manual_until == 33.0 and game.player_lane == 1, "A new paddle press after release overrides assist again")
	game.elimination_notice.text = "AFGEVALLEN · OUD"; game.elimination_notice.show(); game.elimination_notice_until = 100.0
	game._reset()
	check(game.elimination_notice.text.is_empty() and not game.elimination_notice.visible and game.elimination_notice_until < 0.0, "Restart clears old elimination banner")
	check(not game.elimination_assist.enabled and not menu.elimination_assist_toggle.button_pressed, "Restart defaults assist off again")
	game.elimination_notice.text = "AFGEVALLEN · OUD"; game.elimination_notice.show()
	game._set_menu_visible(true)
	check(game.elimination_notice.text.is_empty() and not game.elimination_notice.visible, "Menu entry clears old elimination banner")
	menu.cards[5].pressed.emit(); game._confirm_start()
	check(not game.elimination_assist.enabled, "Next race starts with assistance off")
	game._reset(); menu.cards[0].pressed.emit()
	check(not menu.elimination_assist_toggle.visible, "Scratch setup hides elimination-only option")
	game.free()
	print("ELIMINATION_CORRECTIONS failures=", failures)
	quit(0 if failures == 0 else 1)
