extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(1920, 1080)
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var menu = game.setup_panel
	menu.show_ftp()
	menu.ftp_page.set_process(false)
	# Training starts while already pedalling. No zero-speed/power precondition.
	game._process_bridge_packet({"type":"telemetry", "valid":true, "power_w":180.0, "speed_kmh":25.0, "cadence_rpm":85.0, "sample_id":1, "power_sample_id":1, "power_age_s":0.0, "gear":4})
	menu.ftp_page.begin()
	await process_frame
	var scene = game.training_environment
	check(scene != null and scene.active, "Free warmup opens training scene directly")
	check(game.start_state == "SETUP" and not game.broadcast_intro.active, "No intro, countdown to a race or standstill check")
	check(menu.session_panel.visible and not menu.menu_margin.visible, "Compact training HUD leaves stadium in view")
	check(scene.camp.name == "EigenPloegtent", "Exactly one own team tent")
	check(scene.coach.get_meta("role") == "coach" and scene.mechanic.get_meta("role") == "mechanic", "Only a coach and watching mechanic accompany player")
	check(not game.arena.get_node("LevendigMiddenterrein").is_visible_in_tree(), "All race-day infield people, journalists, boxes and kiosks hidden")
	check(not game.arena.get_node("EuroMaxCyclingCommentaryBox").is_visible_in_tree(), "Broadcast studio hidden")
	for person in get_nodes_in_group("stadium_people"):
		check(scene.is_ancestor_of(person) or not person.is_visible_in_tree(), "No public in stands or infield")
	var point: Vector3 = game._at(scene.start_distance, 1.18)
	check(point.x < -18.0 and absf(point.z - scene.CAMP.z) <= 1.0, "Starts alongside own tent on western straight")
	check(point.distance_to(game._at(0.0, 1.18)) > 10.0, "Training spawn is separate from finish line")
	var before: float = scene.distance
	game._process_bridge_packet({"type":"telemetry", "valid":true, "power_w":180.0, "speed_kmh":25.0, "cadence_rpm":85.0, "sample_id":2, "power_sample_id":2, "power_age_s":0.0, "gear":4})
	scene.advance(1.0)
	check(scene.distance > before, "Existing measured trainer speed moves only the player")
	for i in range(game.bikes.size()):
		check(game.bikes[i].visible == (i == 0), "No AI or other riders during training")
	menu.ftp_page.stop_button.grab_focus()
	game.ride_mapping.assign("menu", "confirm", "SHIFT_UP_RIGHT", "press")
	game._ride_action("A", "SHIFT_UP_RIGHT")
	check(menu.ftp_page.test.phase == "WARMUP", "Physical shifting cannot activate mapped Stop button")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.test-user/training.png"))
	menu.ftp_page.leave()
	check(not scene.active and not scene.visible and menu.page == 6 and menu.menu_margin.visible, "Leaving training restores menu environment")
	menu.show_choices()
	game._set_menu_visible(false)
	check(game.arena.get_node("LevendigMiddenterrein").visible, "Race scenery restored for existing events")
	check(not scene.visible, "Training tent never leaks into races")
	game.queue_free()
	await process_frame
	print("TRAINING_ENVIRONMENT failures=", failures)
	quit(0 if failures == 0 else 1)
