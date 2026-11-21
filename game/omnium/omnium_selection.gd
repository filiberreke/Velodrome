extends RefCounted
## Editable draft. No active tournament exists until explicit confirmation.
const MAX_OPPONENTS := 23
var riders: Array[Dictionary] = []
var format_id := "short"
var strength := 80.0
var catalog = preload("res://omnium/omnium_catalog.gd").new()

func replace(slot: int, entry: Dictionary) -> bool:
	if slot <= 0 or slot >= riders.size(): return false
	for candidate in catalog.candidates(riders, "mixed", slot):
		if candidate.id == entry.get("id"):
			riders[slot] = candidate.duplicate(true); return true
	return false

func remove(slot: int) -> bool:
	if slot <= 0 or slot >= riders.size() or riders.size() <= 1: return false
	riders.remove_at(slot)
	return true

func opponent_count() -> int:
	var count := 0
	for rider in riders:
		if not rider.get("is_player", false): count += 1
	return count

func can_add() -> bool:
	var players := 0
	for rider in riders:
		if rider.get("is_player", false): players += 1
	return players == 1 and opponent_count() < MAX_OPPONENTS and riders.size() < MAX_OPPONENTS + 1

func add(entry: Dictionary) -> bool:
	if not can_add() or entry.get("is_player", false): return false
	for candidate in catalog.candidates(riders):
		if candidate.id == entry.get("id"):
			riders.append(candidate.duplicate(true)); return true
	return false

func copy_from(tournament: Dictionary, player: Dictionary) -> void:
	riders.clear()
	var human := player.duplicate(true); human["is_player"] = true
	riders.append(human)
	for rider in tournament.get("riders", []):
		if rider.get("is_player", false) or rider.get("id") == human.id or rider.get("country") == human.country: continue
		if riders.size() >= MAX_OPPONENTS + 1: break
		riders.append(rider.duplicate(true))
	strength = clampf(float(tournament.get("strength", 80)), 40, 120)
	format_id = String(tournament.get("format", "short"))
