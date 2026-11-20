extends SceneTree
const Migration := preload("res://tools/rider_catalog_migration.gd")

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.size() != 3:
		printerr("Gebruik -- <riders_config.cfg> <omnium_mannen.cfg> <omnium_vrouwen.cfg>")
		quit(2)
		return
	var result := Migration.merge(paths)
	if not result.errors.is_empty():
		for error in result.errors:
			printerr(error)
		quit(1)
		return
	print(result.config.encode_to_text())
	quit()
