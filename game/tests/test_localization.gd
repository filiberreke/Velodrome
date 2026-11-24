extends SceneTree

class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(0)

const ConfigPaths := preload("res://config_paths.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func check_catalog() -> void:
	var file := FileAccess.open("res://translations/translations.csv", FileAccess.READ)
	check(file != null, "Translation catalog is available")
	if file == null:
		return
	check(file.get_csv_line() == PackedStringArray(["keys", "en", "nl"]), "Translation catalog columns are stable")
	var seen := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		check(row.size() == 3, "Catalog entries have one message for each locale")
		if row.size() != 3:
			continue
		check(not seen.has(row[0]) and not row[0].is_empty(), "Each key is unique and nonempty")
		seen[row[0]] = true
		for column in [1, 2]:
			check(not row[column].strip_edges().is_empty(), "Missing translation for " + row[0])
	check(seen.size() >= 850, "The existing catalog is covered")

func run() -> void:
	check_catalog()
	var path := ConfigPaths.user_path("display_settings.cfg")
	var previous := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var preferences := ConfigFile.new()
	preferences.set_value("interface", "language", "en")
	preferences.set_value("display", "fullscreen", false)
	preferences.save(path)

	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var settings = game.get_node("GameSettings")
	check(TranslationServer.get_locale() == "en", "Saved English locale is active at startup")
	check(game.setup_panel.page_title.tr(game.setup_panel.page_title.text) == "Welcome to Velodrome", "English main menu is translated")
	check(game.setup_panel.hub_button.tooltip_text.contains("Races"), "English race tile is translated")
	check(settings.language_choice.selected == 0, "Settings show the active language")
	var jury = preload("res://points_race_rules.gd").new()
	var notifications = preload("res://points_notifications.gd").new()
	jury.reset(4, 40)
	check(notifications.collect(jury, 2250) == ["Intermediate sprint in 1 lap!"], "English sprint notice is formatted")

	game.start_state = "RACING"
	game.running = true
	game.clock = 25.0
	settings.toggle_menu()
	settings.language_choice.select(1)
	settings._on_apply()
	await process_frame
	check(TranslationServer.get_locale() == "nl", "Applying settings activates Dutch")
	check(game.start_state == "RACING" and not game.race_paused and game.clock == 25.0, "Changing language resumes the same race")
	check(game.setup_panel.hub_button.tooltip_text.contains("Wedstrijden"), "Existing race tile translates after switching language")
	game.exit_menu.show_pause()
	check(game.exit_menu.heading.tr(game.exit_menu.heading.text) == "Wedstrijd gepauzeerd", "Existing pause menu uses Dutch")
	notifications.reset()
	check(notifications.collect(jury, 2250) == ["Tussensprint over 1 ronde!"], "Dutch sprint notice is formatted")
	game.free()

	TranslationServer.set_locale("en")
	var restarted := Game.new()
	root.add_child(restarted)
	check(TranslationServer.get_locale() == "nl", "Dutch survives reloading the game")
	restarted.free()
	if not previous.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(previous)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LOCALIZATION_OK" if failures == 0 else "LOCALIZATION_FAILED")
	quit(0 if failures == 0 else 1)
