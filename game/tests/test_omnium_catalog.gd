extends SceneTree
const Catalog := preload("res://omnium/omnium_catalog.gd")
func _initialize() -> void:
	var catalog = Catalog.new()
	assert(catalog.load_catalog(), catalog.error)
	assert(catalog.entries.size() == 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var player := {"id":"player", "country":"belgium", "name":"Speler"}
	for category in ["men", "women", "mixed"]:
		for count in range(12, 25):
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
	print("PASS omnium catalog: three categories, 12–24 riders")
	quit()
