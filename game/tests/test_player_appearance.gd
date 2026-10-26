extends SceneTree
const Appearance = preload("res://player_appearance.gd")
const Visual = preload("res://rider_visual.gd")
var failures := 0

class SettingsUnderTest extends "res://display_settings.gd":
	func _apply_display() -> void: pass
	func _load_settings() -> void: pass
	func _save_settings() -> void: pass
	func _load_rider_profile() -> void: pass
	func _save_rider_profile() -> void: pass

class Host extends Node:
	var player_appearance = Appearance.new("user://test_player_appearance.cfg")
	var player_display_name := "Testspeler"
	var player_weight_kg := 75.0
	var player
	func get_player_appearance_base() -> Dictionary:
		return {"country_kit": "belgium", "helmet_png": "", "visor": "doorzichtig"}
	func apply_player_appearance() -> void:
		Appearance.apply_to_rider(player, player_appearance.resolve(get_player_appearance_base()))

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var path := "user://test_player_appearance.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var prefs = Appearance.new(path)
	prefs.load_preferences()
	check(prefs.suit_id == "configured", "Missing preferences must inherit config")
	check(prefs.suit_options.size() == 13, "Eleven country suits plus defaults required")
	var base := {"country_kit": "belgium", "skinsuit_png": "custom.png", "helmet_png": "custom_helmet.png", "visor": "doorzichtig"}
	check(prefs.resolve(base) == base, "Configured appearance changed")
	var fallback: Dictionary = prefs.resolve(base, "default", "default", "donker")
	check(fallback.skinsuit_png == "" and fallback.country_kit == "" and fallback.helmet_png == "", "Default colors not restored")
	check(base.skinsuit_png == "custom.png", "Base config mutated")
	check(prefs.save_choices("italy", "france", "donker") == OK, "Save failed")
	var restored = Appearance.new(path)
	restored.load_preferences()
	check(restored.suit_id == "italy" and restored.helmet_id == "france" and restored.visor_id == "donker", "Restart lost choices")
	var invalid := ConfigFile.new()
	invalid.set_value("appearance", "suit", "unknown")
	invalid.set_value("appearance", "helmet", "unknown")
	invalid.set_value("appearance", "visor", "unknown")
	invalid.save(path)
	restored.load_preferences()
	check(restored.suit_id == "configured" and restored.helmet_id == "configured" and restored.visor_id == "configured", "Invalid preference fallback failed")
	prefs.settings_path = "user://missing_directory/test.cfg"
	check(prefs.save_choices("germany", "white", "doorzichtig") != OK and prefs.suit_id == "italy", "Failed save changed active choices")
	for pursuit in [false, true]:
		var host := Host.new()
		root.add_child(host)
		host.player = Visual.new()
		host.player.set_meta("pursuit_mode", pursuit)
		Appearance.prepare_rider(host.player, host.player_appearance.resolve(host.get_player_appearance_base()))
		host.add_child(host.player)
		var ai = Visual.new()
		ai.set_meta("pursuit_mode", pursuit)
		host.add_child(ai)
		var original_materials: Array[Material] = []
		for surface in ai.body_mesh.mesh.get_surface_count():
			original_materials.append(ai.body_mesh.get_surface_override_material(surface))
		var settings := SettingsUnderTest.new()
		host.add_child(settings)
		await process_frame
		check(settings.visor_choice.item_count == 2, "Exactly two visor options required")
		settings.toggle_menu()
		check(settings._choice_id(settings.visor_choice) == "doorzichtig", "Configured clear visor not reflected")
		settings._select_id(settings.suit_choice, "italy")
		settings.suit_choice.item_selected.emit(settings.suit_choice.selected)
		check(host.player.country_kit == "belgium", "Draft changed player")
		settings._close_settings()
		settings.toggle_menu()
		check(settings._choice_id(settings.suit_choice) == "configured", "Cancel retained draft")
		settings._select_id(settings.suit_choice, "netherlands")
		settings._select_id(settings.helmet_choice, "united_states")
		settings._select_id(settings.visor_choice, "donker")
		settings._on_appearance_draft(0)
		host.player._play_pose(2)
		host.player.cadence_phase = 1.4
		host.player.body_mesh.set_blend_shape_value(0, 0.6)
		settings._on_apply()
		check(not settings.panel_root.visible and not settings.appearance_preview.active, "Apply did not close/stop preview")
		check(host.player.skinsuit_png.ends_with("netherlands/skinsuit.png"), "Player suit not applied")
		check(host.player.helmet_png.ends_with("united_states/helmet.png") and host.player.visor == "donker", "Helmet/visor not applied")
		check(host.player.current_pose == 2 and host.player.cadence_phase == 1.4, "Apply reset animation")
		check(is_equal_approx(host.player.body_mesh.get_blend_shape_value(0), 0.6), "Apply reset morph")
		for surface in original_materials.size():
			check(ai.body_mesh.get_surface_override_material(surface) == original_materials[surface], "AI changed")
		var respawn = Visual.new()
		respawn.set_meta("pursuit_mode", pursuit)
		host.player_appearance.load_preferences()
		Appearance.prepare_rider(respawn, host.player_appearance.resolve(host.get_player_appearance_base()))
		host.add_child(respawn)
		check(respawn.skinsuit_png == host.player.skinsuit_png and respawn.helmet_png == host.player.helmet_png, "Respawn lost attire")
		settings.toggle_menu()
		host.player_appearance.settings_path = "user://missing_directory/test.cfg"
		settings._select_id(settings.suit_choice, "germany")
		settings._on_apply()
		check(settings.panel_root.visible and not settings.appearance_status.text.is_empty(), "Save failure not shown")
		check(host.player.skinsuit_png.ends_with("netherlands/skinsuit.png"), "Failed save changed player")
		settings._sync_appearance_controls()
		if not pursuit and DisplayServer.get_name() != "headless":
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://player_settings.png")
			settings.appearance_preview.set_back_view(true)
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://player_settings_back.png")
		settings._close_settings()
		for rider in [host.player, ai, respawn, settings.appearance_preview.rider]:
			Appearance.apply_to_rider(rider, {})
		host.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Player appearance settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
