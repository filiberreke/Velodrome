extends RefCounted
## Player-only choices. Independent from display settings and personal race configs.
const SAVE_PATH := "user://config/player_appearance.cfg"
const KEYS := ["country_kit", "skinsuit_png", "helmet_png", "visor"]
const COUNTRY_NAMES := {
	"denmark": "COUNTRY_DENMARK", "portugal": "Portugal", "italy": "COUNTRY_ITALY",
	"great_britain": "COUNTRY_GREAT_BRITAIN", "australia": "COUNTRY_AUSTRALIA",
	"new_zealand": "COUNTRY_NEW_ZEALAND", "germany": "COUNTRY_GERMANY", "france": "COUNTRY_FRANCE",
	"netherlands": "COUNTRY_NETHERLANDS", "united_states": "COUNTRY_UNITED_STATES","spain": "COUNTRY_SPAIN",
"switzerland": "COUNTRY_SWITZERLAND",
"poland": "COUNTRY_POLAND",
"japan": "Japan",
"china": "China",
"czechia": "COUNTRY_CZECHIA",
"austria": "COUNTRY_AUSTRIA",
"kazakhstan": "COUNTRY_KAZAKHSTAN",
"mexico": "Mexico",
"argentina": "COUNTRY_ARGENTINA",
"turkey": "COUNTRY_TURKIYE",
"venezuela": "Venezuela",
"ireland": "COUNTRY_IRELAND",
"colombia": "Colombia",
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
		{"id": "configured", "label": "APPEARANCE_CURRENT_SELECTION", "path": ""},
		{"id": "default", "label": "APPEARANCE_DEFAULT_COLOURS", "path": ""},
		{"id": "belgium", "label": "RIDER_BELGIUM", "path": "res://assets/riders/national_kits/belgium/skinsuit.png"},
	]
	helmet_options = [
		{"id": "configured", "label": "APPEARANCE_CURRENT_SELECTION", "path": ""},
		{"id": "default", "label": "APPEARANCE_DEFAULT_COLOURS", "path": ""},
		{"id": "white", "label": "APPEARANCE_WHITE", "path": "res://assets/riders/national_kits/denmark/helmet.png"},
	]
	# Use resource paths directly so exported builds do not depend on raw JSON inclusion.
	for id in COUNTRY_NAMES:
		var folder := "res://assets/riders/national_kits/%s/" % id
		if ResourceLoader.exists(folder + "skinsuit.png"):
			suit_options.append({"id": id, "label": COUNTRY_NAMES[id], "path": folder + "skinsuit.png"})
		# Plain white shells are represented by a single clear option.
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
	var error: Error = preload("res://config_paths.gd").load_user(cfg, "player_appearance.cfg") if settings_path == SAVE_PATH else cfg.load(settings_path)
	if error != OK: return
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
	if settings_path == SAVE_PATH: preload("res://config_paths.gd").user_path("player_appearance.cfg")
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
