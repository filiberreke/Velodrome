extends RefCounted
const Catalog := preload("res://rider_catalog.gd")
const Countries := preload("res://rennersboxen/race_countries.gd")
var entries: Array[Dictionary] = []
var error := ""

func load_catalog() -> bool:
	entries.clear()
	var config := ConfigFile.new()
	error = Catalog.load_config(config)
	if not error.is_empty(): return false
	for section in config.get_sections():
		var slot := Catalog.rider_slot(section)
		if slot > 0:
			entries.append(Catalog.entry(config, slot, 1 + ((slot - 1) % 3)))
	return true

func candidates(lineup: Array, category: String = "mixed", replacing: int = -1) -> Array[Dictionary]:
	var countries := {}; var ids := {}
	for i in range(lineup.size()):
		if i == replacing: continue
		countries[String(lineup[i].country)] = true
		ids[String(lineup[i].id)] = true
	var result: Array[Dictionary] = []
	for entry in entries:
		if category != "mixed" and entry.category != category: continue
		if not countries.has(entry.country) and not ids.has(entry.id): result.append(entry.duplicate(true))
	return result

func available_count(player: Dictionary, category: String) -> int:
	var countries := {}
	for entry in candidates([player], category):
		countries[entry.country] = true
	return mini(24, 1 + countries.size())

func generate(player: Dictionary, count: int, category: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count < 8 or count > 24 or category not in ["men", "women", "mixed"]: return result
	var human := player.duplicate(true)
	human["is_player"] = true
	if String(human.get("id", "")).is_empty() or Countries.valid_country(String(human.get("country", ""))).is_empty(): return result
	result.append(human)
	while result.size() < count:
		var available := candidates(result, category)
		if available.is_empty(): return []
		result.append(available[rng.randi_range(0, available.size() - 1)])
	return result
