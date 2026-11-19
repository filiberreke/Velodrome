extends SceneTree
## Batch entry point for tools/export-mode-previews.sh.

const MODES := [
	"scratch", "points", "elimination", "keirin", "pursuit", "team_pursuit",
	"time_trial", "madison", "tempo", "free_training", "derny_training", "flying_training",
]


func _initialize() -> void:
	export_previews.call_deferred()


func export_previews() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		fail("Pass one absolute output directory after --.")
		return
	if DisplayServer.get_name() == "headless":
		fail("Godot's headless display driver cannot render 3D. Use Xvfb or a graphics display.")
		return
	var preview := load("res://mode_preview.gd") as GDScript
	if preview == null or not preview.can_instantiate():
		fail("Cannot load mode_preview.gd. Check the Godot asset import.")
		return

	var output_dir := args[0]
	var error := DirAccess.make_dir_recursive_absolute(output_dir)
	if error != OK:
		fail("Cannot create %s: %s" % [output_dir, error_string(error)])
		return

	var captures: Dictionary[String, Image] = {}
	for mode: String in MODES:
		var viewport: SubViewport = preview.make(root, mode)
		# Draw the SubViewport without presenting the root window.
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await process_frame
		RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		viewport.queue_free()
		if image == null or image.is_empty() or image.get_width() < 640 or image.get_height() < 420:
			fail("Invalid viewport capture for %s." % mode)
			return
		if not has_visible_content(image):
			fail("Capture for %s appears blank." % mode)
			return
		captures[mode] = image

	for mode: String in captures:
		var image := captures[mode]
		var path := output_dir.path_join(mode + ".png")
		error = image.save_png(path)
		if error != OK:
			fail("Cannot save %s: %s" % [path, error_string(error)])
			return
		print("%s (%d×%d)" % [path, image.get_width(), image.get_height()])
	quit()


func has_visible_content(image: Image) -> bool:
	var first_pixel := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0 and pixel != first_pixel:
				return true
	return false


func fail(message: String) -> void:
	printerr(message)
	quit(1)
