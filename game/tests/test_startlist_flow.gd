extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in range(3): await process_frame
func click(button: Button) -> void:
	await settle()
	var position := button.get_global_rect().get_center()
	check(button.is_visible_in_tree() and not button.disabled, "Mouse target is visible and enabled: " + button.text)
	check(root.get_visible_rect().encloses(button.get_global_rect()), "Mouse target fits inside test viewport: " + button.text)
	var motion := InputEventMouseMotion.new(); motion.position = position; root.push_input(motion, true)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position = position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down; root.push_input(event, true)
	await settle()
func run_test() -> void:
	root.size = Vector2i(1920, 1080)
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	await settle()
	var menu = game.setup_panel
	menu.select_mode(0)
	await click(menu.start_button)
	var roster = menu.startlist_page
	check(menu.page == 5 and game.start_state == "SETUP", "Actual settings click opens a second page without starting")
	check(roster.lineup.size() == 7 and roster.grid.get_child_count() == 7 and roster.can_start(), "All opponents have profile cards")
	check(roster.pool.size() >= 24 and roster.available_candidates().size() >= 17, "Default roster has reserve choices")
	var chosen: Dictionary = roster.available_candidates()[0].duplicate(true)
	var previous: String = roster.lineup[0].id
	check(not roster.replace_opponent(0, roster.lineup[1]), "Already selected opponents cannot be duplicated")
	check(not roster.replace_opponent(0, {"id":"unknown"}), "Unknown profiles cannot enter the race")
	roster.open_picker(0)
	await settle()
	check(roster.active_picker.entries.size() == roster.available_candidates().size(), "Replacement picker contains only unused riders")
	for entry in roster.active_picker.entries: check(entry.id not in roster._chosen_ids(), "No chosen identity is offered again")
	roster.active_picker.selected.emit(chosen)
	roster.active_picker.layer.queue_free()
	await settle()
	check(roster.lineup[0].id == chosen.id, "Picker replaces the requested opponent")
	var restored := false
	for entry in roster.available_candidates():
		if entry.id == previous: restored = true
	check(restored, "Replaced identity becomes available again")
	roster.back()
	check(menu.page == 2 and menu.settings_page.visible, "Start list returns to editable match settings")
	menu.count_input.value = 12
	menu.show_startlist()
	check(roster.lineup.size() == 11 and roster.lineup[0].id == chosen.id, "Increasing field size preserves selected opponents")
	menu.update_bridge_status(false,false,true)
	check(roster.start_button.disabled, "Unavailable trainer connection blocks start list start")
	menu.update_bridge_status(false,false,false)
	await click(roster.start_button)
	check(game.start_state != "SETUP" and game.rider_count == 12, "Actual start-list mouse click launches the configured race")
	check(game.rider_identities[1].id == chosen.id and game.rider_profiles[1] == chosen.profile, "Selected profile and identity reach the game")
	check(is_equal_approx(game.x_ai.cp[1] / game.rider_forms[1], float(chosen.cp_w)*game.ai_difficulty/100.), "Selected physiology and AI strength reach the actual AI")
	game.broadcast_intro.finish(); game._reset()
	for mode in [3,5]:
		for amount in ([16] if mode == 3 else [4,12,16]):
			menu.select_mode(mode)
			if mode == 3: menu.count_input.value = amount
			else:
				for i in menu.elimination_count_picker.item_count:
					if menu.elimination_count_picker.get_item_id(i) == amount: menu.elimination_count_picker.select(i)
			menu.show_startlist()
			check(roster.lineup.size() == amount - 1 and roster.grid.get_child_count() == amount - 1, "Complete start list for %d riders in mode %d" % [amount,mode])
			check(roster.available_candidates().size() > 0, "Even a full field can change an opponent")
			var replacement: Dictionary = roster.available_candidates()[-1].duplicate(true)
			check(roster.replace_opponent(amount - 2, replacement), "Last opponent can be changed")
			await settle()
			check(root.get_visible_rect().encloses(roster.start_button.get_global_rect()), "Start action remains visible for largest field")
			await click(roster.start_button)
			check(game.rider_count == amount and game.race_mode == (1 if mode == 3 else 2), "Start list keeps the requested discipline and field size")
			check(game.rider_identities.size() == amount and game.rider_identities[amount - 1].id == replacement.id, "Last replacement is present in the running race")
			game.broadcast_intro.finish(); game._reset()
	menu.select_mode(1)
	await settle()
	check(menu.pursuit_flow.match_art.get_global_rect().position.x < menu.pursuit_flow.distance_options.get_global_rect().position.x, "Pursuit uses image left and settings right")
	check(menu.pursuit_flow.match_title.text == "Achtervolging", "Pursuit shows discipline title")
	menu.select_mode(2)
	menu.pursuit_flow.advanced_toggle.button_pressed = true; menu.pursuit_flow.advanced.show()
	await settle()
	check(menu.pursuit_flow.match_title.text == "Ploegenachtervolging", "Team pursuit has its own image, title and description")
	check(root.get_visible_rect().encloses(menu.pursuit_flow.proceed_button.get_global_rect()), "Expanded team settings and navigation fit the viewport")
	menu.show_records()
	var page = menu.records_page
	page.mode_buttons[2].pressed.emit()
	check(page.mode_choice.get_selected_id() == 7 and page.shown.is_empty() and page.category.text.begins_with("Tijdrit"), "Time trial has its own implemented record category")
	check(not page.size_box.visible and page.distance_caption.visible and page.start_choice.visible, "Time trial records expose distance and start type, without squad size")
	check(page.distance_choice.get_item_id(0) == 500 and page.distance_choice.get_item_id(1) == 1000, "Time trial record filters use the supported 500 m and 1 km distances")
	page.mode_buttons[0].pressed.emit()
	check(page.distance_caption.visible, "Existing record filters restore when returning")
	menu.hide()
	game.finish_overlay.show()
	game._update_visuals(0.0)
	var podium := game.find_child("Podium",true,false) as Node3D
	check(podium != null and game.camera.global_position.is_equal_approx(podium.to_global(Vector3(-5.3,3.5,7.0))), "Results camera faces the real podium")
	check(game.camera.unproject_position(podium.global_position).x > 1400.0, "Podium stays visible beside the results sheet")
	game.free()
	print("STARTLIST_FLOW failures=",failures)
	quit(0 if failures == 0 else 1)
