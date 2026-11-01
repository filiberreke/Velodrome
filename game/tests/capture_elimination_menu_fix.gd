extends SceneTree
func _initialize()->void:call_deferred("capture")
func capture()->void:
	root.size=Vector2i(1920,1080)
	var menu=preload("res://race_menu.gd").new();root.add_child(menu)
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://verification/elimination_menu_fix")
	root.get_texture().get_image().save_png("res://verification/elimination_menu_fix/mode_gallery.png")
	for i in range(7):menu.previews[i].get_texture().get_image().save_png("res://verification/elimination_menu_fix/"+String(menu.MODES[i].key)+".png")
	menu.select_mode(5)
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/elimination_menu_fix/elimination_settings.png")
	print("ELIMINATION_PREVIEW_CAPTURES_OK")
	quit()
