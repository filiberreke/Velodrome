extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
func _initialize() -> void:
	var catalog = Catalog.new()
	assert(catalog.load_catalog(), catalog.error)
	assert(catalog.entries.size() > 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var player := {"id":"player", "country":"belgium", "name":"Speler"}
	for category in ["men", "women", "mixed"]:
		for count in range(8, 25):
			var lineup: Array = catalog.generate(player, count, category, rng)
			assert(lineup.size() == count)
			var countries := {}
			for rider in lineup:
				assert(not countries.has(rider.country))
				countries[rider.country] = true
				assert(rider.get("is_player", false) or category == "mixed" or rider.category == category)
			assert(lineup[0].is_player)
			var original: String = catalog.entries[0].name
			lineup[1].name = "Gewijzigd"
			assert(catalog.entries[0].name == original)
	assert(catalog.generate(player, 7, "mixed", rng).is_empty())
	assert(catalog.generate(player, 25, "mixed", rng).is_empty())
	var small: Array[Dictionary] = catalog.generate(player, 8, "women", rng)
	catalog.entries.assign(small.slice(1))
	catalog.entries.append(small[1].duplicate(true))
	catalog.entries[-1].id = "same_country_reserve"
	assert(catalog.available_count(player, "mixed") == 8)
	assert(catalog.available_count(player, "men") == 1)
	assert(catalog.generate(player, 8, "mixed", rng).size() == 8)
	assert(catalog.generate(player, 9, "mixed", rng).is_empty())
	print("PASS omnium catalog: three categories, 8–24 riders and catalogue size independent of lineup size")
	quit()
