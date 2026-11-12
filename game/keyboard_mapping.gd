extends RefCounted
## Keyboard profiles are independent of the physical Ride mapping.
const PATH := "user://keyboard_mapping.json"
const BASE_ACTIONS := {
	"global": {"settings":"Instellingen openen / sluiten"},
	"menu": {"up":"Omhoog", "down":"Omlaag", "left":"Links", "right":"Rechts", "accept":"Bevestigen", "back":"Terug"},
	"race": {"shift_up":"Opschakelen (zwaarder)", "shift_down":"Afschakelen (lichter)", "steer_left":"Sturen naar links", "steer_right":"Sturen naar rechts", "camera_next":"Volgende camera", "camera_previous":"Vorige camera", "look_back":"Achteruitkijken (vasthouden)", "rider_info":"Naam / wattage / energie", "pause":"Pauze / training stoppen", "power_up":"Simulator: vermogen verhogen", "power_down":"Simulator: vermogen verlagen", "boost":"Simulator: sprint", "tempo_up":"Derny: tempo verhogen", "tempo_down":"Derny: tempo verlagen", "record":"Opname bewaren", "restart":"Herstart / terug naar menu", "developer":"Diagnostiek tonen"}
}
const BASE_KEYS := {
	"global": {"settings":KEY_F10},
	"menu": {"up":KEY_UP,"down":KEY_DOWN,"left":KEY_LEFT,"right":KEY_RIGHT,"accept":KEY_ENTER,"back":KEY_ESCAPE},
	"race": {"shift_up":KEY_UP,"shift_down":KEY_DOWN,"steer_left":KEY_A,"steer_right":KEY_D,"camera_next":KEY_C,"camera_previous":KEY_Q,"look_back":KEY_B,"rider_info":KEY_V,"pause":KEY_ESCAPE,"power_up":KEY_EQUAL,"power_down":KEY_MINUS,"boost":KEY_SPACE,"tempo_up":KEY_RIGHT,"tempo_down":KEY_LEFT,"record":KEY_P,"restart":KEY_R,"developer":KEY_X}
}
const CONTEXTS := ["global","menu","race","simulator","madison_race","madison_simulator"]
const CONTEXT_LABELS := ["Algemeen","Menu","Trainer aangesloten","Zonder trainer (simulator)","Madison: met trainer","Madison: simulator"]

static func actions() -> Dictionary:
	var result := BASE_ACTIONS.duplicate(true)
	result["simulator"] = result.race.duplicate(true)
	for action in ["power_up","power_down","boost"]: result.race.erase(action)
	for action in ["shift_up","shift_down"]: result.simulator.erase(action)
	for profile in ["race","simulator"]:
		result["madison_" + profile] = result[profile].duplicate(true)
		for action in ["tempo_up","tempo_down"]: result["madison_" + profile].erase(action)
		result["madison_" + profile]["madison_grab"] = "Madison: handaflossing (indrukken / loslaten)"
	return result

static func defaults() -> Dictionary:
	var result := BASE_KEYS.duplicate(true)
	result["simulator"] = result.race.duplicate(true)
	for action in ["power_up","power_down","boost"]: result.race.erase(action)
	for action in ["shift_up","shift_down"]: result.simulator.erase(action)
	result.simulator.power_up = KEY_UP
	result.simulator.power_down = KEY_DOWN
	for profile in ["race","simulator"]:
		result["madison_" + profile] = result[profile].duplicate(true)
		for action in ["tempo_up","tempo_down"]: result["madison_" + profile].erase(action)
		result["madison_" + profile].steer_left = KEY_LEFT
		result["madison_" + profile].steer_right = KEY_RIGHT
		result["madison_" + profile]["madison_grab"] = KEY_A
	return result

static var ACTIONS: Dictionary = actions()
static var DEFAULT_KEYS: Dictionary = defaults()
var profiles: Dictionary = DEFAULT_KEYS.duplicate(true)
var enabled := true
var status := ""

func validate(data: Variant) -> String:
	if not data is Dictionary or data.size() != ACTIONS.size(): return "Ongeldige contexten"
	for context in ACTIONS:
		if not data.get(context) is Dictionary or data[context].size() != ACTIONS[context].size(): return "Onvolledige mapping"
		var used := {}
		for action in ACTIONS[context]:
			var key: Variant = data[context].get(action)
			if typeof(key) not in [TYPE_INT,TYPE_FLOAT] or float(key) != floor(float(key)) or key < 0 or key > 0x7fffffff: return "Ongeldige toets"
			if key == 0: continue
			if used.has(int(key)): return "Toets al gebruikt voor " + str(ACTIONS[context][used[int(key)]])
			if context != "global" and data.global.values().has(key): return "Toets al gebruikt voor Instellingen"
			used[int(key)] = action
	return ""

func assign(context: String, action: String, key: int) -> String:
	if not ACTIONS.has(context) or not ACTIONS[context].has(action): return "Onbekende actie"
	var candidate := profiles.duplicate(true)
	candidate[context][action] = key
	var error := validate(candidate)
	if error.is_empty(): profiles = candidate
	return error

func action_for(context: String, event: InputEventKey) -> String:
	var key := int(event.get_keycode_with_modifiers())
	for action in profiles.get(context, {}):
		if int(profiles[context][action]) != 0 and int(profiles[context][action]) == key: return action
	return ""

func caption(context: String, action: String) -> String:
	var key := int(profiles[context][action])
	return {0:"Niet toegewezen",KEY_ESCAPE:"ESC",KEY_UP:"↑",KEY_DOWN:"↓",KEY_LEFT:"←",KEY_RIGHT:"→"}.get(key, OS.get_keycode_string(key))

func menu_hint() -> String:
	return "%s/%s kiezen · %s/%s aanpassen · %s bevestigen · %s terug · %s instellingen" % [caption("menu","up"),caption("menu","down"),caption("menu","left"),caption("menu","right"),caption("menu","accept"),caption("menu","back"),caption("global","settings")]

func apply_ui() -> void:
	for action in ["up","down","left","right","accept","back"]:
		var ui_action: String = "ui_cancel" if action == "back" else "ui_" + action
		for event in InputMap.action_get_events(ui_action):
			if event is InputEventKey: InputMap.action_erase_event(ui_action, event)
		var code := int(profiles.menu[action])
		if enabled and code != 0:
			var event := InputEventKey.new()
			event.keycode = code & KEY_CODE_MASK
			event.shift_pressed = bool(code & KEY_MASK_SHIFT)
			event.ctrl_pressed = bool(code & KEY_MASK_CTRL)
			event.alt_pressed = bool(code & KEY_MASK_ALT)
			event.meta_pressed = bool(code & KEY_MASK_META)
			InputMap.action_add_event(ui_action, event)

func save(path: String = PATH) -> Error:
	if not validate(profiles).is_empty(): return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":1,"enabled":enabled,"profiles":profiles}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK: apply_ui()
	return error

func load_settings(path: String = PATH) -> void:
	profiles = DEFAULT_KEYS.duplicate(true)
	enabled = true
	status = ""
	if not FileAccess.file_exists(path): return
	var parser := JSON.new()
	var parsed := parser.parse(FileAccess.get_file_as_string(path))
	var data: Variant = parser.data if parsed == OK else null
	if data is Dictionary and data.get("version") == 1 and data.get("enabled") is bool and validate(data.get("profiles")).is_empty():
		profiles = data.profiles
		enabled = data.enabled
	else: status = "Opgeslagen mapping ongeldig; standaardtoetsen actief."
