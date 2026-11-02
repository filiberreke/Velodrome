extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.setup_panel.select_mode(1)
	game.setup_panel.pursuit_flow.next_step()
	game._confirm_start()
	game.broadcast_intro.finish()
	game._update_visuals(0.0)
	var start = game.pursuit_start
	check(start.gates.size() == 2, "Two opposing pursuit start devices")
	check(not start.released, "Stop check and countdown keep clamps closed")
	for rider in range(2):
		var gate: Node3D = start.gates[rider]
		check(gate.find_child("Helper_Left", true, false) != null and gate.find_child("Helper_Right", true, false) != null, "Two helpers per device")
		var bike: Node3D = game.bikes[rider]
		var held_axle := gate.to_global(Vector3(0, .335, 0))
		var bike_axle := bike.to_global(Vector3(0, .335, -.4))
		check(held_axle.distance_to(bike_axle) < 0.001, "Clamp aligns with actual rear axle")
		var normal: Vector3 = start.surface_basis(game, game._rider_distance(rider, 0.0), game.lane_offsets[rider]).y
		check(normal.y > .9, "Surface normal points above the track")
		check(gate.global_basis.y.distance_to(normal) < 0.001 and bike.global_basis.y.distance_to(normal) < 0.001, "Device and held rider follow track bank")
	var our_shirt := start.gates[0].find_child("Helper_Left_shirt", true, false) as MeshInstance3D
	var their_shirt := start.gates[1].find_child("Helper_Left_shirt", true, false) as MeshInstance3D
	check(our_shirt.get_active_material(0) is ShaderMaterial, "Helpers have independent team shirt materials")
	check(not our_shirt.get_active_material(0).get_shader_parameter("use_atlas"), "Untextured rider palettes remain supported")
	check((our_shirt.get_active_material(0).get_shader_parameter("team_color") as Color).is_equal_approx(Color("eac736")), "Default helpers match the actual rider color")
	game.player_appearance.suit_id = "belgium"
	game.apply_player_appearance()
	game.bikes[1].get_child(0).set_country_kit("netherlands")
	start.refresh_kits(game)
	check(our_shirt.get_active_material(0).get_shader_parameter("team_atlas") == load("res://assets/riders/national_kits/belgium/skinsuit.png"), "Player's selected Belgian outfit updates both helpers")
	check(their_shirt.get_active_material(0).get_shader_parameter("team_atlas") == load("res://assets/riders/national_kits/netherlands/skinsuit.png"), "Opponent helpers independently wear Netherlands outfit")
	var custom := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	custom.fill(Color("6936a5"))
	custom.save_png("user://helper_custom_team_test.png")
	game.bikes[0].get_child(0).set_skinsuit_png("user://helper_custom_team_test.png")
	start.refresh_kits(game)
	var custom_atlas: Texture2D = our_shirt.get_active_material(0).get_shader_parameter("team_atlas")
	check(custom_atlas != null and custom_atlas.get_image().get_pixel(0, 0).is_equal_approx(Color("6936a5")), "External custom team PNG reaches helper shirts")
	check(their_shirt.get_active_material(0).get_shader_parameter("team_atlas") != custom_atlas, "Custom player team never recolors opponent helpers")
	for gate: Node3D in start.gates:
		var left_shirt := gate.find_child("Helper_Left_shirt", true, false) as MeshInstance3D
		var right_shirt := gate.find_child("Helper_Right_shirt", true, false) as MeshInstance3D
		check(left_shirt.get_active_material(0) == right_shirt.get_active_material(0), "Both helpers at each rider share that rider's team shirt")
	game.start_state = "COUNTDOWN"
	game.countdown = 2.0
	game._update_visuals(.3)
	check(not start.released and start.elapsed == 0.0, "Countdown does not release early")
	game.start_state = "WAIT_STOP"
	game._update_visuals(.2)
	check(not start.released, "Aborted countdown remains clamped")
	game._begin_riding()
	check(start.released and game.start_state == "RACING" and game.clock == 0.0, "GO releases devices without delaying race clock")
	game._update_visuals(.18)
	var machine: Node3D = start.gates[0].find_child("StartGate_ROOT", true, false)
	var left: Node3D = start.gates[0].find_child("Left_Clamp_SLIDE", true, false)
	check(left.position.x < -.10 and machine.position.length() < .001, "Clamps open before helpers withdraw")
	var old_elapsed: float = start.elapsed
	game.race_paused = true
	game._physics_process(.3)
	check(start.elapsed == old_elapsed, "Pause freezes helpers and device")
	game.race_paused = false
	game._update_visuals(1.05)
	check(absf(machine.position.z + 1.1) < .001, "Helpers withdraw the device 1.10 m")
	game._update_visuals(1.0)
	check(not start.gates[0].visible and not start.gates[1].visible, "Equipment clears before the next lap")
	game._restart_same_race()
	game._update_visuals(0.0)
	check(start.gates.size() == 2 and not start.released and start.gates[0].visible, "Restart restores closed gates and helpers")
	game._reset()
	check(start.gates.is_empty(), "Reset removes pursuit equipment")
	game.setup_panel.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.finish()
	game._update_visuals(.1)
	check(start.gates.is_empty(), "Scratch does not receive pursuit start devices")
	game.free()
	print("PURSUIT_START_OK" if failures == 0 else "PURSUIT_START_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
