extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var output := "res://verification/rider_profiles/"
	DirAccess.make_dir_recursive_absolute(output)
	var game := Screen.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.setup_panel.select_mode(1)
	for i in range(5): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"pursuit_selection.png")
	game.setup_panel.pursuit_options.open_picker()
	for i in range(8): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"rider_passports.png")
	var overlay: CanvasLayer = root.get_child(root.get_child_count()-1)
	var picker = overlay.get_child(0)
	picker.search.text = "Filippa"
	picker.apply_filter()
	for i in range(4): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"filtered_passport.png")
	overlay.free()
	game.pursuit_opponent_config = game.setup_panel.pursuit_options.selected_ai()
	game.race_mode = 4
	game._configure_peloton()
	game._prepare_pursuit({},265)
	game._set_menu_visible(false)
	game._update_visuals(0.0)
	game.broadcast_intro.start()
	game.broadcast_intro.advance(9.0)
	game.broadcast_intro.apply_camera()
	for i in range(8): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"pursuit_intro_passport.png")
	assert(game.broadcast_intro.opponent_card.passport.entry.id == game.pursuit_opponent_config.id)
	print("RIDER_PROFILES_CAPTURES_OK")
	quit()
