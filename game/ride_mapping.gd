extends RefCounted
## Physical identity is independent of actions and their triggering edge.
const PATH := "user://ride_button_mapping.json"
const VERSION := 1
const BUTTONS := ["UP", "DOWN", "LEFT", "RIGHT", "A", "B", "Y", "Z", "SHIFT_UP_LEFT", "SHIFT_DOWN_LEFT", "SHIFT_UP_RIGHT", "SHIFT_DOWN_RIGHT", "POWER_LEFT", "POWER_RIGHT", "ONOFF_LEFT", "ONOFF_RIGHT"]
const ACTIONS := {
	"menu": {"up":"Omhoog", "down":"Omlaag", "left":"Links", "right":"Rechts", "accept":"Bevestigen", "back":"Terug", "settings":"Instellingen / sluiten"},
	"race": {"camera_previous":"Vorige camera", "camera_next":"Volgende camera", "look_back":"Achteruitkijken", "rider_info":"Naam / wattage / energie", "pause":"Pauze"},
	"arcade": {"special_left":"Speciale actie links (toekomstig)", "special_right":"Speciale actie rechts (toekomstig)"}
}
const KEYS := {"up":"UP", "down":"DOWN", "left":"LEFT", "right":"RIGHT", "accept":"A", "back":"B", "settings":"Z", "camera_previous":"UP", "camera_next":"DOWN", "look_back":"B", "rider_info":"Y", "pause":"Z"}
var profiles: Dictionary = defaults()
var status := ""
var customized := false

static func physical(button: String) -> String:
	return button.replace("DROP_LEFT", "POWER_LEFT").replace("DROP_RIGHT", "POWER_RIGHT")

static func display(button: String) -> String:
	return button.replace("POWER_LEFT", "DROP_LEFT").replace("POWER_RIGHT", "DROP_RIGHT")

static func defaults() -> Dictionary:
	var result := {"menu":{}, "race":{}, "arcade":{}}
	for context in result:
		for action in ACTIONS[context]:
			result[context][action] = {"button": KEYS.get(action, ""), "trigger":"hold" if action == "look_back" else "press"}
	return result

func validate(data: Variant) -> String:
	if not data is Dictionary or data.size() != ACTIONS.size(): return "Ongeldige contexten"
	for context in ACTIONS:
		if not data.get(context) is Dictionary or data[context].size() != ACTIONS[context].size(): return "Onvolledig profiel: " + context
		var used := {}
		for action in ACTIONS[context]:
			var binding: Variant = data[context].get(action)
			if not binding is Dictionary: return "Ongeldige actie: " + action
			var button: Variant = binding.get("button")
			var trigger: Variant = binding.get("trigger")
			if not button is String or (button != "" and button not in BUTTONS): return "Onbekende fysieke knop"
			if trigger not in ["press", "release", "hold"] or (trigger == "hold") != (action == "look_back"): return "Ongeldig drukgedrag"
			if button != "" and used.has(button): return "Conflict: %s is al toegewezen aan %s" % [display(button), ACTIONS[context][used[button]]]
			used[button] = action
	return ""

func assign(context: String, action: String, button: String, trigger: String) -> String:
	if not ACTIONS.has(context) or not ACTIONS[context].has(action): return "Onbekende actie"
	var candidate := profiles.duplicate(true)
	candidate[context][action] = {"button":physical(button), "trigger":trigger}
	var error := validate(candidate)
	if error.is_empty():
		profiles = candidate
		customized = true
	return error

func reset(context: String = "") -> void:
	if context.is_empty(): profiles = defaults()
	elif ACTIONS.has(context): profiles[context] = defaults()[context]
	customized = true

func action_for(context: String, button: String) -> String:
	for action in profiles.get(context, {}):
		if profiles[context][action].button == physical(button): return action
	return ""

func save(path: String = PATH) -> Error:
	var error := validate(profiles)
	if not error.is_empty(): return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":VERSION, "profiles":profiles}, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return write_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_settings(path: String = PATH, legacy_path: String = "") -> void:
	profiles = defaults()
	customized = false
	status = ""
	if FileAccess.file_exists(path):
		var parser := JSON.new()
		var parsed := parser.parse(FileAccess.get_file_as_string(path))
		var data: Variant = parser.data if parsed == OK else null
		if data is Dictionary and data.get("version") == VERSION and validate(data.get("profiles")).is_empty():
			profiles = data.profiles
			customized = true
		else: status = "Opgeslagen mapping ongeldig; standaardbediening actief. Bestand blijft bewaard."
		return
	if not legacy_path.is_empty() and FileAccess.file_exists(legacy_path):
		var parser := JSON.new()
		var parsed := parser.parse(FileAccess.get_file_as_string(legacy_path))
		var legacy: Variant = parser.data if parsed == OK else null
		if not legacy is Dictionary:
			status = "Oude mapping ongeldig; standaardbediening actief."
			return
		for value in legacy.values():
			if value not in ["LEFT", "RIGHT", "UP", "DOWN", "A", "B", "Y", "Z", ""]:
				status = "Oude mapping bevat onbekende acties; standaardbediening actief."
				return
		var candidate := defaults()
		for context in ["menu", "race"]:
			for button in legacy:
				# Old shift aliases belong to trainer gearing, never menu navigation.
				if button not in ["UP", "DOWN", "LEFT", "RIGHT", "A", "B", "Y", "Z"]: continue
				for action in candidate[context]:
					if candidate[context][action].button == button: candidate[context][action].button = ""
			for button in legacy:
				if button not in ["UP", "DOWN", "LEFT", "RIGHT", "A", "B", "Y", "Z"]: continue
				for action in candidate[context]:
					if KEYS.get(action) == legacy[button]: candidate[context][action].button = button
		var error := validate(candidate)
		if error.is_empty(): profiles = candidate
		else: status = "Oude mapping bevat conflicten; standaardbediening actief."
