extends RefCounted
## Shared lifecycle only. Discipline controllers reuse the existing race motors.
const Formats := preload("res://omnium/omnium_formats.gd")
const Scores := preload("res://omnium/omnium_scoring.gd")
var context := {}
var attempt := {}
var manager
var committed := false
var finish_energy := {}
var error := ""
var hud: Control
# Optional deterministic clock for recovery/integration tests; production uses UTC.
var clock_source: Callable

func discipline() -> String: return ""
func stage() -> int: return -1
func mode() -> int: return -1
func elimination_interval_m() -> float: return 500.0

func now_unix() -> int:
	return int(clock_source.call()) if clock_source.is_valid() else int(Time.get_unix_time_from_system())

func enabled() -> bool:
	return not context.is_empty()

func start(game: Node, owner_manager) -> bool:
	if enabled(): return false
	var now := now_unix()
	if not owner_manager.check_deadline(now) or owner_manager.state.active.is_empty(): return false
	if owner_manager.state.active.results.size() != stage():
		error = "Deze discipline is nog niet aan de beurt."; return false
	if not game._piste_start_blocker().is_empty():
		error = game._piste_start_blocker(); return false
	game._reset()
	manager = owner_manager
	attempt = manager.begin_attempt(now)
	if attempt.is_empty(): error = manager.error; return false
	context = manager.state.active.duplicate(true)
	committed = false; finish_energy.clear(); error = ""
	game.race_mode = mode()
	game.race_laps = Formats.race_laps(String(context.format), discipline(), context.riders.size())
	game.rider_count = context.riders.size()
	game.ai_difficulty = float(context.strength)
	if not game.trainer_seen: game.demo_launch_watts = float(game.setup_panel.demo_power_input.value)
	game.selected_startlist.clear(); game.startlist_mode = -1
	game.replay_setup.clear()
	game._configure_peloton()
	game._tt_prepare_event()
	game.trainer_control.arm()
	game.zero_stable = 0.0
	game._set_menu_visible(false)
	game.broadcast_intro.start()
	if is_instance_valid(game.race_overlay):
		hud = load("res://omnium/omnium_hud.gd").new()
		game.race_overlay.add_child(hud)
	return true

func apply_reserves(game: Node) -> void:
	if not enabled(): return
	var reserves: Dictionary = manager.recovered_energy(now_unix())
	for i in range(1, game.rider_count):
		var id := String(game.rider_identities[i].id)
		game.x_ai.wprime[i] = game.x_ai.wmax[i] * clampf(float(reserves.get(id, 1.0)), 0.0, 1.0)

func order(game: Node) -> Array[int]:
	var indices: Array[int] = []
	for i in range(game.rider_count): indices.append(i)
	indices.sort_custom(func(a: int, b: int): return game._race_better(a, b))
	return indices

func sample(game: Node) -> void:
	if not enabled() or committed or game.start_state != "RACING": return
	var now := now_unix()
	if not manager.state.active.is_empty() and manager.deadline() > 0 and now > manager.deadline():
		manager.check_deadline(now)
	if manager.state.active.is_empty():
		error = "Het omnium is verlopen. Deze wedstrijd telt niet mee."
		return
	for i in range(1, game.rider_count):
		var id := String(game.rider_identities[i].id)
		if game.finish_times[i] >= 0.0 and not finish_energy.has(id):
			finish_energy[id] = {"reserve":clampf(game.x_ai.wprime[i] / maxf(1.0, game.x_ai.wmax[i]), 0.0, 1.0), "wprime_j":game.x_ai.wprime[i], "capacity_j":game.x_ai.wmax[i], "timestamp":now}
	if not game._all_riders_finished(): return
	committed = manager.finish_attempt(String(attempt.id), result_data(game), finish_energy, now)
	if committed: error = ""
	if not committed:
		error = manager.error
		if manager.state.active.is_empty(): error = "Het omnium is verlopen. Deze wedstrijd telt niet mee."

func standings(game: Node) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not enabled(): return rows
	var totals := Scores.totals(context.riders, context.results)
	var indices := order(game)
	var credits: Array[int] = game._lap_credits()
	for place in range(indices.size()):
		var i: int = indices[place]
		var rider: Dictionary = game.rider_identities[i]
		rows.append({"id":rider.id, "name":rider.name, "country":rider.country, "score":int(totals[rider.id]) + Scores.place_points(place + 1), "player":i == 0, "laps":credits[i]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score)
	return rows

func update_hud(game: Node) -> void:
	if enabled() and is_instance_valid(hud): hud.update_standings(standings(game))

func may_leave(game: Node) -> bool:
	if not enabled(): return true
	sample(game)
	if game.finish_times[0] >= 0.0 and not committed and not manager.state.active.is_empty():
		error = "De uitslag wordt nog aangevuld." if not game._all_riders_finished() else "Opslaan mislukt: " + manager.error
		return false
	if not committed and not manager.state.active.is_empty():
		if not manager.abort_attempt(): error = manager.error; return false
	return true

func clear() -> void:
	if is_instance_valid(hud): hud.queue_free()
	hud = null; context = {}; attempt = {}; finish_energy.clear(); committed = false

func result_data(game: Node) -> Dictionary:
	var ids: Array = []; var times := {}
	for i in order(game):
		var id := String(game.rider_identities[i].id)
		ids.append(id); times[id] = game.finish_times[i]
	return {"discipline":discipline(), "order":ids, "finish_times":times}
