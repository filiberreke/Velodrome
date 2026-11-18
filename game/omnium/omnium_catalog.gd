extends RefCounted
const Catalog := preload("res://rider_catalog.gd")
const Paths := preload("res://config_paths.gd")
const Countries := preload("res://rennersboxen/race_countries.gd")
const FILES := ["omnium_mannen_24_riders_config.cfg", "omnium_vrouwen_24_riders_config.cfg"]
var entries: Array[Dictionary] = []
var error := ""

func load_catalog() -> bool:
	var loaded: Array[Dictionary] = []
	var seen := {}
	for filename in FILES:
		var config := ConfigFile.new()
		if Paths.load_project(config, filename) != OK:
			error = "Rennersconfiguratie ontbreekt: " + filename; return false
		var count := 0
		var countries := {}
		for section in config.get_sections():
			if not section.begins_with("rider_"): continue
			var suffix := section.trim_prefix("rider_")
			if not suffix.is_valid_int(): error = "Ongeldige rennersectie: " + section; return false
			var entry := Catalog.entry(config, int(suffix), 1)
			var country := Countries.valid_country(String(config.get_value(section, "country", "")))
			if country.is_empty() or seen.has(entry.id) or countries.has(country):
				error = "Ongeldige of dubbele renner/land: " + section; return false
			seen[entry.id] = true; countries[country] = true
			loaded.append(entry); count += 1
		if count != 24: error = "Verwacht 24 renners in " + filename; return false
	entries = loaded
	error = ""
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
