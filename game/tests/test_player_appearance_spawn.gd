extends SceneTree
## Exercise the actual main.gd spawn/apply methods without trainer/network startup.
const Appearance = preload("res://player_appearance.gd")
var failures := 0
class SpawnHost extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _profile(_i): return 0
	func _rider_name(i): return str(i)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for mode in [0, 4, 5]:
		var host = SpawnHost.new()
		host.player_appearance = Appearance.new("user://test_spawn_appearance.cfg")
		host.rider_count = 2; host.team_size = 1
		host.rider_identities.assign([{},{}])
		host.rider_kits.assign([{}, {"country_kit":"belgium"}])
		host.rider_config_ready = true
		root.add_child(host)
		host.race_mode = mode
		host.rider_config.set_value("player", "country_kit", "belgium")
		host.rider_config.set_value("rider_01", "country_kit", "belgium")
		host.player_appearance.save_choices("portugal", "france", "doorzichtig")
		host._spawn_peloton()
		var player = host.bikes[0].get_child(0)
		var ai = host.bikes[1].get_child(0)
		check(player.skinsuit_png.ends_with("portugal/skinsuit.png"), "Player preferences lost on spawn")
		check(player.helmet_png.ends_with("france/helmet.png") and player.visor == "doorzichtig", "Player helmet/visor lost on spawn")
		check(ai.country_kit == "belgium" and ai.skinsuit_png == "", "AI config overridden")
		check(bool(player.get_meta("pursuit_mode")) == (mode in [4, 5]), "Wrong rig selected")
		host.player_appearance.save_choices("germany", "white", "donker")
		player._play_pose(1)
		host.apply_player_appearance()
		check(player.current_pose == 1 and player.skinsuit_png.ends_with("germany/skinsuit.png"), "Live update lost pose or outfit")
		check(ai.country_kit == "belgium", "Live update changed AI")
		Appearance.apply_to_rider(player, {})
		Appearance.apply_to_rider(ai, {})
		host.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_spawn_appearance.cfg"))
	print("Player appearance main spawn: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
