extends SceneTree
## Real spawn/materials, including default palette and live appearance changes.
class Pair extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _load_rider_config() -> void: rider_config_ready = true

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func same_equipment(game, context: String) -> void:
	var player = game.bikes[0].get_child(0)
	var partner = game.bikes[1].get_child(0)
	for key in game.PlayerAppearance.KEYS:
		check(player.get(key) == partner.get(key), "%s: same %s" % [context, key])
	check(game.rider_kits[0].country == game.rider_kits[1].country, context + ": same team country")
	check(game.RaceCountries.configured_country(game, 0) == game.RaceCountries.configured_country(game, 1), context + ": country lookup uses team kit")
	for surface in range(player.body_mesh.mesh.get_surface_count()):
		var original: Material = player.body_mesh.mesh.surface_get_material(surface)
		if original.resource_name in ["skin", "visor"]: continue
		var a: Material = player.body_mesh.get_surface_override_material(surface)
		var b: Material = partner.body_mesh.get_surface_override_material(surface)
		if a == null or b == null:
			check(a == b, context + ": same inherited material")
			continue
		if a is ShaderMaterial or b is ShaderMaterial:
			check(a is ShaderMaterial and b is ShaderMaterial and a.shader == b.shader, context + ": same kit shader")
			continue
		check(a.albedo_color == b.albedo_color, context + ": same equipment colours")
		check(a.albedo_texture == b.albedo_texture, context + ": same equipment texture")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Pair.new()
	root.add_child(game)
	game.race_mode = 6
	game.rider_config.set_value("player", "country_kit", "belgium")
	game.rider_config.set_value("player", "helmet_png", "res://assets/riders/national_kits/france/helmet.png")
	game.rider_config.set_value("player", "visor", "doorzichtig")
	game.rider_config.set_value("rider_01", "country_kit", "netherlands")
	game.rider_config.set_value("rider_01", "country", "netherlands")
	game.rider_config.set_value("rider_01", "visor", "donker")
	game.player_appearance.suit_id = "default"
	game.player_appearance.helmet_id = "default"
	game._configure_peloton()
	same_equipment(game, "Default spawn")
	check(game.rider_names[1] == "Ploegmaat", "Partner is named as a teammate")
	check(game.bikes[1].get_child(0).get_meta("rider_index") == game.rider_profiles[1], "AI keeps its own body and riding profile")
	var partner = game.bikes[1].get_child(0)
	partner._play_pose(1)
	for suit in ["portugal", "configured", "default"]:
		game.player_appearance.suit_id = suit
		game.player_appearance.helmet_id = "france" if suit == "portugal" else "default"
		game.player_appearance.visor_id = "doorzichtig"
		game.apply_player_appearance()
		same_equipment(game, "Live " + suit)
		check(partner.current_pose == 1, "Live kit change preserves teammate animation")
	game.player_appearance.suit_id = "configured"
	game.rider_config.set_value("player", "skinsuit_png", "res://assets/riders/national_kits/germany/skinsuit.png")
	game.apply_player_appearance()
	same_equipment(game, "Custom configured PNG")
	game.replay_setup = {"riders":game.rider_identities.duplicate(true), "forms":game.rider_forms.duplicate()}
	game._restarting_event = true
	game._configure_peloton()
	same_equipment(game, "Restart spawn")
	check(game.bikes[1].get_child(0).skinsuit_png.ends_with("germany/skinsuit.png"), "Restart keeps current player kit")
	game.free()
	await process_frame
	print("MADISON_KIT_OK" if failures == 0 else "MADISON_KIT_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
