extends SceneTree
const Catalog := preload("res://rider_catalog.gd")
const Migration := preload("res://tools/rider_catalog_migration.gd")
const Omnium := preload("res://omnium/omnium_catalog.gd")
const Manager := preload("res://omnium/omnium_manager.gd")
const Selection := preload("res://omnium/omnium_selection.gd")
const MEN := "res://config/omnium_mannen_24_riders_config.cfg"
const WOMEN := "res://config/omnium_vrouwen_24_riders_config.cfg"
var folder := ProjectSettings.globalize_path("user://catalog_test_%s" % Time.get_ticks_usec())

func _initialize() -> void:
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	test_migration()
	test_conflicts()
	test_snapshot()
	for file in DirAccess.get_files_at(folder):
		assert(DirAccess.remove_absolute(folder.path_join(file)) == OK)
	assert(DirAccess.remove_absolute(folder) == OK)
	print("PASS rider catalog migration, conflicts and saved omnium snapshots")
	quit()

func fixture(name: String, content: String) -> String:
	var path := folder.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
	return path

func test_migration() -> void:
	var source := """[player]
skinsuit_png="user://custom.png"
[rider_01]
id="personal"
category=" Women "
country="JAP"
country_kit="italy"
record_250m_s=20.1
cp_factor=1.1
hair_style="ponytail"
hip_width=0.3
"""
	var personal := fixture("personal.cfg", source)
	var result := Migration.merge(PackedStringArray([personal, MEN, WOMEN]))
	assert(result.errors.is_empty(), "\n".join(result.errors))
	var combined: ConfigFile = result.config
	assert(combined.get_sections().size() == 50)
	assert(FileAccess.get_file_as_string(personal) == source)
	assert(combined.get_value("player", "skinsuit_png") == "user://custom.png")
	var entry := Catalog.entry(combined, 1, 1)
	assert(entry.id == "personal" and entry.country == "japan")
	assert(entry.category == "women" and entry.jersey.category == entry.category)
	assert(entry.jersey.country_kit == "italy" and entry.jersey.hair_style == "ponytail")
	assert(is_equal_approx(entry.records.record_250m_s, 20.1))
	assert(is_equal_approx(entry.cp_factor, 1.1) and is_equal_approx(entry.morphs.HipWidth, 0.3))
	var implicit := fixture("implicit-profile.cfg", "[rider_104]\nid=\"legacy_tt\"\ncountry=\"france\"\n")
	var implicit_result := Migration.merge(PackedStringArray([personal, implicit, WOMEN]))
	assert(implicit_result.errors.is_empty())
	assert(Catalog.entry(implicit_result.config, 104, 2).profile == 1)
	var sample := ConfigFile.new()
	assert(Catalog.read_config("res://config/riders_config.example.cfg", sample).is_empty())
	for path in [MEN, WOMEN]:
		var legacy := ConfigFile.new()
		assert(Catalog.read_config(path, legacy).is_empty())
		for section in legacy.get_sections():
			assert(combined.get_section_keys(section) == legacy.get_section_keys(section))
			for key in legacy.get_section_keys(section):
				assert(combined.get_value(section, key) == legacy.get_value(section, key))
				assert(sample.get_value(section, key) == legacy.get_value(section, key))

func test_conflicts() -> void:
	var cfg := ConfigFile.new()
	var multiline := fixture("multiline.cfg", "[rider_01]\nname=\"Naam\n[rider_02]\nname=nog steeds tekst\"\n[rider_02]\nname=\"Tweede renner\"\n")
	assert(Catalog.read_config(multiline, cfg).is_empty())
	assert(cfg.get_value("rider_02", "name") == "Tweede renner")
	var repeated := fixture("repeated.cfg", "\uFEFF[rider_01]\nid=\"first\"\n[rider_01]\nid=\"second\"\n")
	assert(Catalog.read_config(repeated, cfg).contains("Dubbele sectie"))
	var duplicate_key := fixture("duplicate_key.cfg", "[rider_01]\nid=\"first\"\nid=\"second\"\n")
	assert(Catalog.read_config(duplicate_key, cfg).contains("Dubbele sleutel"))
	assert(cfg.parse("[rider_01]\nid=\"same\"\n[rider_02]\nid=\"same\"\n") == OK)
	assert(Catalog.validate(cfg).contains("Dubbele ID"))
	cfg.set_value("rider_02", "id", "distinct")
	cfg.set_value("rider_02", "category", "mixed")
	assert(Catalog.validate(cfg).contains("Ongeldige categorie"))
	cfg.erase_section("rider_02")
	cfg.set_value("rider_1", "id", "alias")
	assert(Catalog.validate(cfg).contains("Ongeldige rennersectie"))
	var personal := fixture("conflicting.cfg", "[rider_100]\nid=\"omnium_por_100\"\ncountry=\"belgium\"\n")
	var result := Migration.merge(PackedStringArray([personal, MEN, WOMEN]))
	var errors := "\n".join(result.errors)
	assert(result.config == null and errors.contains("Dubbele sectie") and errors.contains("Dubbele ID"))
	assert(errors.contains("verschillende waarden: country") and errors.contains(personal))

func test_snapshot() -> void:
	var catalog := Omnium.new()
	assert(catalog.load_catalog(), catalog.error)
	var human := {"id":"player", "country":"belgium", "name":"Speler", "is_player":true, "profile":0}
	var riders: Array = [human]
	var original := ConfigFile.new()
	assert(Catalog.read_config(MEN, original).is_empty())
	for slot in range(100, 108):
		var entry := Catalog.entry(original, slot, 1)
		if entry.country != human.country:
			riders.append(entry)
	riders[1].name = "Persoonlijke naam uit oude snapshot"
	riders[1].jersey.visor = "donker"
	riders[1].records.best_5s_w = 915.0
	var old := {
		"id":"legacy_omnium", "status":"active", "riders":riders, "format":"women", "strength":80,
		"started":100, "last_seen":200, "last_finish":200, "attempt":{},
		"results":[{"discipline":"scratch", "order":riders.map(func(rider): return rider.id)}],
		"energy":{riders[1].id:{"reserve":0.5, "timestamp":200}},
	}
	var archived := old.duplicate(true)
	archived.status = "stopped"
	archived.ended = 201
	var contents := JSON.stringify({"version":1, "active":old, "archive":[archived]})
	var primary := fixture("state.json", contents)
	var backup := fixture("state.json.bak", contents)
	var manager := Manager.new()
	manager.store.folder = folder
	assert(manager.load_session(202))
	assert(catalog.load_catalog(), catalog.error)
	assert(manager.state == JSON.parse_string(contents))
	var selection := Selection.new()
	selection.copy_from(manager.state.archive[0], human)
	assert(selection.riders[1].name == old.riders[1].name)
	assert(selection.riders[1].jersey.visor == "donker")
	assert(selection.riders[1].records.best_5s_w == 915)
	selection.riders[1].jersey.visor = "doorzichtig"
	assert(manager.state.archive[0].riders[1].jersey.visor == "donker")
	assert(FileAccess.get_file_as_string(primary) == contents)
	assert(FileAccess.get_file_as_string(backup) == contents)
	fixture("state.json", "corrupt")
	assert(manager.load_session(202) and manager.state == JSON.parse_string(contents))
	assert(FileAccess.get_file_as_string(backup) == contents)
