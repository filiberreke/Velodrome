extends RefCounted
const Formats := preload("res://omnium/omnium_formats.gd")
const Recovery := preload("res://omnium/energy_recovery.gd")
const Store := preload("res://omnium/omnium_store.gd")
const DAY := 86400
var store = Store.new()
var state := {"version":1, "active":{}, "archive":[]}
var error := ""
var clock_warning := ""

func load_session(now: int) -> bool:
	state = store.load_state()
	return check_deadline(now)

func _commit(candidate: Dictionary) -> bool:
	if not store.save_state(candidate): error = store.error; return false
	state = candidate
	error = ""
	return true

func create(riders: Array, format_id: String, strength: float, now: int) -> bool:
	if not state.active.is_empty() or not Formats.FORMATS.has(format_id): return false
	if riders.size() < 12 or riders.size() > 24 or strength < 40 or strength > 120: return false
	var ids := {}; var countries := {}; var players := 0
	for rider in riders:
		var id := String(rider.get("id", "")); var country := String(rider.get("country", ""))
		if id.is_empty() or country.is_empty() or ids.has(id) or countries.has(country): return false
		ids[id] = true; countries[country] = true
		if rider.get("is_player", false): players += 1
	if players != 1: return false
	var next := state.duplicate(true)
	next.active = {"id":str(now) + "_" + str(Time.get_ticks_usec()), "status":"active", "riders":riders.duplicate(true), "format":format_id, "strength":strength, "started":0, "last_finish":0, "last_seen":now, "results":[], "energy":{}, "attempt":{}}
	return _commit(next)

func deadline() -> int:
	var active: Dictionary = state.active
	if active.is_empty() or int(active.started) == 0: return 0
	var total := int(active.started) + 28 * DAY
	return mini(total, int(active.last_finish) + 14 * DAY) if int(active.last_finish) > 0 else total

func check_deadline(now: int) -> bool:
	if state.active.is_empty(): return true
	if now < int(state.active.last_seen): clock_warning = "De systeemklok is achteruit versprongen."
	if deadline() > 0 and now > deadline(): return archive("expired", deadline())
	return true

func begin_attempt(now: int) -> Dictionary:
	if not check_deadline(now) or state.active.is_empty(): return {}
	var next := state.duplicate(true)
	if int(next.active.started) == 0: next.active.started = now
	next.active.last_seen = now
	var attempt := {"id":str(now) + "_" + str(Time.get_ticks_usec()), "discipline":Formats.DISCIPLINES[next.active.results.size()], "started":now}
	next.active.attempt = attempt
	return attempt.duplicate(true) if _commit(next) else {}

func abort_attempt() -> bool:
	if state.active.is_empty(): return false
	var next := state.duplicate(true); next.active.attempt = {}
	return _commit(next)

func finish_attempt(attempt_id: String, result: Dictionary, energy: Dictionary, now: int) -> bool:
	if not check_deadline(now) or state.active.is_empty(): return false
	var active: Dictionary = state.active
	if active.attempt.get("id", "") != attempt_id or result.get("discipline") != active.attempt.get("discipline"): return false
	var expected: Array = []
	for rider in active.riders: expected.append(String(rider.id))
	var order: Array = result.get("order", []).duplicate()
	if order.size() != expected.size(): return false
	for id in order:
		if not expected.has(id): return false
		expected.erase(id)
	var next := state.duplicate(true)
	next.active.results.append(result.duplicate(true)); next.active.energy = energy.duplicate(true)
	next.active.last_finish = now; next.active.last_seen = now; next.active.attempt = {}
	if next.active.results.size() == 4:
		next.active.status = "completed"; next.active.ended = now
		next.archive.append(next.active.duplicate(true)); next.active = {}
	return _commit(next)

func recovered_energy(now: int) -> Dictionary:
	var output := {}
	if state.active.is_empty(): return output
	for id in state.active.energy:
		var value: Dictionary = state.active.energy[id]
		output[id] = Recovery.recovered_reserve(float(value.reserve), maxf(0, now - int(value.timestamp)))
	return output

func archive(reason: String, now: int) -> bool:
	if state.active.is_empty() or reason not in ["stopped", "expired"]: return false
	var next := state.duplicate(true)
	next.active.status = reason; next.active.ended = now; next.active.attempt = {}
	next.archive.append(next.active.duplicate(true)); next.active = {}
	return _commit(next)

# Validate an editable setup using the same rules as initial creation.
func update_setup(riders: Array, format_id: String, strength: float, now: int) -> bool:
	if state.active.is_empty() or int(state.active.started) != 0: return false
	# No disk write during validation.
	if riders.size() < 12 or riders.size() > 24 or not Formats.FORMATS.has(format_id) or strength < 40 or strength > 120: return false
	var ids := {}; var countries := {}; var players := 0
	for rider in riders:
		var id := String(rider.get("id", "")); var country := String(rider.get("country", ""))
		if id.is_empty() or country.is_empty() or ids.has(id) or countries.has(country): return false
		ids[id] = true; countries[country] = true
		if rider.get("is_player", false): players += 1
	if players != 1: return false
	var next := state.duplicate(true)
	next.active.riders = riders.duplicate(true); next.active.format = format_id
	next.active.strength = strength; next.active.last_seen = now
	return _commit(next)
