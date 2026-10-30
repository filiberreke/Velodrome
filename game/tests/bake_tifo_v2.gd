extends SceneTree
func _initialize() -> void:
	var image := Image.new()
	assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/branding/velodrome_tifo.svg")) == OK)
	assert(image.get_width() == 4096 and image.get_height() == 1024)
	assert(image.save_png("res://assets/branding/velodrome_tifo_v2.png") == OK)
	print("TIFO_V2_BAKE_OK 4096x1024")
	quit()
