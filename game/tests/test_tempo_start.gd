extends SceneTree
const TempoAI := preload("res://tempo_ai.gd")

class Game extends "res://main.gd":
	func _ready() -> void:
		super._ready()
		bridge_devices.set_process(false)
		bridge_devices.socket.close()
		bridge_devices.panel_root.hide()
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass

var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(3): await process_frame

func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var menu = game.setup_panel
	var roster = menu.startlist_page
	for scenario in [[16, 40], [6, 10], [16, 120]]:
		menu.select_mode(8)
		menu.count_input.value = scenario[0]
		menu.laps_input.value = scenario[1]
		check(not menu.start_button.disabled, "Tempo settings allow proceeding to start list")
		menu.start_button.pressed.emit()
		await settle()
		check(menu.page == 5 and game.start_state == "SETUP", "Tempo opens start list before launching")
		check(roster.can_start() and not roster.start_button.disabled, "Valid tempo roster enables Start wedstrijd")
		check(roster.lineup.size() == scenario[0] - 1, "Tempo has the configured opponent count")
		var replacement: Dictionary = roster.available_candidates()[-1].duplicate(true)
		check(roster.replace_opponent(0, replacement), "Tempo opponent can be replaced")
		var original: Dictionary = roster.lineup[1].duplicate(true)
		roster.lineup[1] = roster.lineup[0].duplicate(true)
		check(not roster.can_start(), "Duplicate tempo opponents block starting")
		roster.lineup[1] = {"id": "unknown"}
		check(not roster.can_start(), "Unknown tempo opponent blocks starting")
		roster.lineup[1] = original
		var last: Dictionary = roster.lineup.pop_back()
		check(not roster.can_start(), "Incomplete tempo roster blocks starting")
		roster.lineup.append(last)
		menu.update_bridge_status(true, false, true)
		check(not roster.can_start() and roster.start_button.disabled, "Unavailable bridge blocks tempo start")
		roster.start_button.pressed.emit()
		check(game.start_state == "SETUP", "Blocked tempo start cannot emit a launch")
		menu.update_bridge_status(false, false, false)
		check(roster.can_start() and not roster.start_button.disabled, "Bridge recovery enables tempo start")
		roster.start_button.pressed.emit()
		await settle()
		check(game.start_state in ["INTRO", "WAIT_STOP"], "Tempo start launches the normal race start flow")
		check(game.race_mode == 8 and game.rider_count == scenario[0] and game.race_laps == scenario[1], "Tempo discipline, field and laps reach the race unchanged")
		if game.start_state not in ["INTRO", "WAIT_STOP"] or game.race_mode != 8:
			break
		check(game.startlist_mode == 8 and game.rider_identities[1].id == replacement.id, "Selected tempo opponent reaches the race")
		check(game.x_ai is TempoAI and game.x_ai.jury == game.tempo_rules, "Tempo uses its own AI and jury")
		check(game.tempo_rules.points.size() == scenario[0] and game.tempo_rules.laps == scenario[1], "Tempo jury uses configured field and race length")
		game.broadcast_intro.finish()
		game.watts = 250.0
		check(not game._start_requires_standstill() and game._start_conditions_met(), "Tempo allows pedalling before the neutral lap")
		game.trainer_seen = true
		game.connected = true
		game.trainer_ready = true
		game.trainer_speed_kmh = 20.0
		check(game._start_conditions_met() and game._final_start_speed_ok(), "Ready moving trainer can start tempo")
		game.connected = false
		check(not game._start_conditions_met(), "Disconnected trainer still blocks tempo countdown")
		game.trainer_seen = false
		game._begin_riding()
		check(game.start_state == "NEUTRAL", "Tempo begins with its neutral lap")
		game._reset()
	# No extra discipline becomes playable through the roster guard.
	menu.select_mode(8)
	menu.show_startlist()
	for mode in [1, 2, 4, 7, 9]:
		menu.selected = mode
		check(not roster.can_start(), "Non-startlist mode stays blocked: %d" % mode)
	menu.selected = 8
	menu.page = 2
	check(not roster.can_start(), "Tempo cannot start from the wrong page")
	game.free()
	print("TEMPO_START failures=", failures)
	quit(0 if failures == 0 else 1)
