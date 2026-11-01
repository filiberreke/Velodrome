extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1920,1080)
	var menu = preload("res://race_menu.gd").new(); root.add_child(menu)
	menu.select_mode(5)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://verification/elimination_corrections")
	root.get_texture().get_image().save_png("res://verification/elimination_corrections/settings.png")
	print("ELIMINATION_SETTINGS_CAPTURE_OK")
	quit()
