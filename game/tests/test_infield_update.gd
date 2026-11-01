extends SceneTree
const Layout := preload("res://infield_layout.gd")
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _load_rider_config() -> void:
		rider_config = ConfigFile.new()
		rider_config_ready = true
		rider_config.set_value("player", "country_kit", "belgium")
		rider_config.set_value("rider_14", "name", "Gekozen renner")
		rider_config.set_value("rider_14", "country_kit", "france")
		rider_config.set_value("rider_22", "name", "Extra renner")
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_test() -> void:
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var field: Node3D = game.arena.get_node("LevendigMiddenterrein")
	print("SUPPORTERS=", field.supporter_count, " RAIL=", field.rail_supporter_count)
	check(field.supporter_count >= 4 * 478, "At least four times the previous entire infield population")
	for p in field.supporter_positions:
		check(Layout.inset(p) >= 2.7, "Supporters stay behind the relocated fence")
		check(not Layout.coach_gate(p, 0.2), "Supporters leave coach access corridors open")
	check(Layout.inset(field.flag_node.position) < 2.45, "Flag marshal remains on the safety strip")
	var row: Node3D = field.get_node("Rennersboxen")
	for i in row.boxes.size():
		check(is_equal_approx(row.boxes[i].position.x, Layout.BOX_X), "Boxes move exactly two metres inward")
		var coach: Node3D = row.crews[i].get_node("Trainer")
		check(Layout.inset(coach.global_position) > 0.1 and Layout.inset(coach.global_position) < 2.45, "Coach is on the safety strip")
	for z in Layout.GATE_Z:
		var p := Vector3(-15.55, 0, z)
		check(Layout.coach_gate(p), "A gate connects each gap between boxes")
		# Inspect real rendered glass triangles at every coach access point.
		var glass: MeshInstance3D = game.arena.get_node("Glazen binnenboarding")
		var vertices: PackedVector3Array = glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0, vertices.size(), 6):
			var center := (vertices[i] + vertices[i + 5]) * 0.5
			check(not Layout.coach_gate(center), "Glass mesh leaves real gate openings")
	var options = game.setup_panel.pursuit_options
	check(options.ai_entries.size() == 16, "All fifteen AI slots and extra configured riders are selectable")
	for i in options.ai_entries.size():
		if options.ai_entries[i].slot == 14: options.ai_choice.select(i)
	game.pursuit_opponent_config = options.selected_ai()
	game.race_mode = 4
	game._configure_peloton()
	check(game.rider_names[1] == "Gekozen renner", "Selected opponent survives spawning")
	check(game.bikes[1].get_child(0).country_kit == "france", "Selected opponent keeps the chosen slot's actual outfit")
	var team = game.setup_panel.team_options
	check(team.ai_entries.size() == 11, "All eleven national teams can be selected")
	for size in [3, 4]:
		for entry in team.ai_entries:
			game.team_size = size
			game.race_mode = 5
			game.pursuit_opponent_country = entry.country
			game._configure_peloton()
			check(game.rider_count == size * 2, "Both teams contain exactly three or four riders")
			for i in range(size):
				check(game.bikes[i].get_child(0).country_kit == "belgium", "Player team uses a single country and outfit")
			for i in range(size, size * 2):
				check(game.bikes[i].get_child(0).country_kit == entry.country, "Every opponent uses the selected national team outfit")
	game.player_appearance.suit_id = "italy"
	game.apply_player_appearance()
	for i in range(4):
		check(game.bikes[i].get_child(0).skinsuit_png.ends_with("italy/skinsuit.png"), "Changing the player outfit updates every teammate")
	game.free()
	print("INFIELD_UPDATE failures=", failures)
	quit(0 if failures == 0 else 1)
