extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(int(OS.get_cmdline_user_args()[0]))
	func _save_recording(_reason: String) -> void: pass
var g
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func wait_for(marker: String, condition: Callable) -> void:
	print("RIDE_FLOW_" + marker)
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		g._physics_process(0.01)
		await process_frame
	if not condition.call(): failures += 1; push_error("UDP flow timeout: " + marker)
func run_test() -> void:
	g = Game.new()
	root.add_child(g)
	g.set_physics_process(false)
	await process_frame; await process_frame
	g.trainer_control.port = int(OS.get_cmdline_user_args()[1])
	var settings = g.get_node("GameSettings")
	await wait_for("SETTINGS", func(): return settings.panel_root.visible)
	await wait_for("CLOSE", func(): return not settings.panel_root.visible)
	g.setup_panel.cards[0].grab_focus()
	await wait_for("SELECT", func(): return g.setup_panel.page == 2)
	g.setup_panel.start_button.grab_focus()
	await wait_for("CONFIG", func(): return g.setup_panel.page == 5)
	g.setup_panel.startlist_page.start_button.grab_focus()
	await wait_for("START", func(): return g.start_state == "INTRO")
	# Neutralised starts now accept a rolling rider and immediately count down.
	await wait_for("SKIP", func(): return not g.broadcast_intro.active and g.start_state == "COUNTDOWN")
	g.start_state = "RACING"; g.running = true
	await wait_for("LOOK_DOWN", func(): return g.look_back_held)
	await wait_for("LOOK_UP", func(): return not g.look_back_held)
	await wait_for("PAUSE", func(): return g.race_paused)
	await wait_for("RESUME", func(): return not g.race_paused)
	g.finished = true; g.finish_overlay.show()
	await wait_for("RESULTS", func(): return g.start_state == "SETUP")
	g.free()
	await process_frame
	print("VIRTUAL_BRIDGE_OK RIDE_PHASE2_UDP failures=%d" % failures)
	quit(0 if failures == 0 else 1)
