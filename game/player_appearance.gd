extends RefCounted
## Player-only choices. Independent from display settings and personal race configs.
const SAVE_PATH := "user://player_appearance.cfg"
const KEYS := ["country_kit", "skinsuit_png", "helmet_png", "visor"]
const COUNTRY_NAMES := {
	"denmark": "Denemarken", "portugal": "Portugal", "italy": "Italië",
	"great_britain": "Groot-Brittannië", "australia": "Australië",
	"new_zealand": "Nieuw-Zeeland", "germany": "Duitsland", "france": "Frankrijk",
	"netherlands": "Nederland", "united_states": "Verenigde Staten",
}
var settings_path: String
var suit_id := "configured"
var helmet_id := "configured"
var visor_id := "configured"
var suit_options: Array[Dictionary] = []
var helmet_options: Array[Dictionary] = []

func _init(path: String = SAVE_PATH) -> void:
	settings_path = path
	suit_options = [
		{"id": "configured", "label": "Bestaande keuze", "path": ""},
		{"id": "default", "label": "Standaardkleuren", "path": ""},
		{"id": "belgium", "label": "België", "path": "res://assets/riders/national_kits/belgium/skinsuit.png"},
	]
	helmet_options = [
		{"id": "configured", "label": "Bestaande keuze", "path": ""},
		{"id": "default", "label": "Standaardkleuren", "path": ""},
		{"id": "white", "label": "Wit", "path": "res://assets/riders/national_kits/denmark/helmet.png"},
	]
	# Use resource paths directly so exported builds do not depend on raw JSON inclusion.
	for id in COUNTRY_NAMES:
		var folder := "res://assets/riders/national_kits/%s/" % id
		if ResourceLoader.exists(folder + "skinsuit.png"):
			suit_options.append({"id": id, "label": COUNTRY_NAMES[id], "path": folder + "skinsuit.png"})
		# Plain white shells are represented by a single clear option.
		if id in ["great_britain", "new_zealand", "france", "netherlands", "united_states"]:
			if ResourceLoader.exists(folder + "helmet.png"):
				helmet_options.append({"id": id, "label": COUNTRY_NAMES[id], "path": folder + "helmet.png"})

func _find(options: Array[Dictionary], id: String) -> Dictionary:
	for option in options:
		if option.id == id: return option
	return options[0]

func load_preferences() -> void:
	# Reset first: missing/invalid files must never keep a previous user's choices.
	suit_id = "configured"
	helmet_id = "configured"
	visor_id = "configured"
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK: return
	suit_id = String(_find(suit_options, str(cfg.get_value("appearance", "suit", "configured"))).id)
	helmet_id = String(_find(helmet_options, str(cfg.get_value("appearance", "helmet", "configured"))).id)
	var saved := str(cfg.get_value("appearance", "visor", "configured"))
	visor_id = saved if saved in ["configured", "donker", "doorzichtig"] else "configured"

func save_choices(suit: String, helmet: String, visor: String) -> Error:
	var next_suit := String(_find(suit_options, suit).id)
	var next_helmet := String(_find(helmet_options, helmet).id)
	var next_visor := visor if visor in ["donker", "doorzichtig", "configured"] else "configured"
	var cfg := ConfigFile.new()
	cfg.set_value("appearance", "suit", next_suit)
	cfg.set_value("appearance", "helmet", next_helmet)
	cfg.set_value("appearance", "visor", next_visor)
	var error := cfg.save(settings_path)
	if error == OK:
		suit_id = next_suit
		helmet_id = next_helmet
		visor_id = next_visor
	return error

func resolve(base: Dictionary, suit: String = "", helmet: String = "", visor: String = "") -> Dictionary:
	if suit.is_empty(): suit = suit_id
	if helmet.is_empty(): helmet = helmet_id
	if visor.is_empty(): visor = visor_id
	var result := base.duplicate(true)
	var selected_suit := _find(suit_options, suit)
	if selected_suit.id != "configured":
		result["country_kit"] = ""
		result["skinsuit_png"] = selected_suit.path
	var selected_helmet := _find(helmet_options, helmet)
	if selected_helmet.id != "configured": result["helmet_png"] = selected_helmet.path
	if visor in ["donker", "doorzichtig"]: result["visor"] = visor
	return result

static func prepare_rider(rider: Node, config: Dictionary) -> void:
	for key in KEYS: rider.set_meta(key, String(config.get(key, "")))

static func apply_to_rider(rider: Node, config: Dictionary) -> void:
	var png := String(config.get("skinsuit_png", ""))
	if not png.is_empty(): rider.call("set_skinsuit_png", png)
	else: rider.call("set_country_kit", String(config.get("country_kit", "")))
	rider.call("set_helmet_png", String(config.get("helmet_png", "")))
	rider.call("set_visor", String(config.get("visor", "")))
