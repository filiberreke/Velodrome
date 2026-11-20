extends RefCounted
const Paths := preload("res://config_paths.gd")
const FILENAME := "riders_config.cfg"
const Countries := preload("res://rennersboxen/race_countries.gd")
const CP := [0.0, 265.0, 240.0, 250.0]
const WPRIME := [0.0, 24120.4, 30638.0, 32658.4]
const PMAX := [0.0, 856.79, 1661.88, 1149.10]
const TYPES := ["Speler", "Tijdrijder", "Sprinter", "Aanvaller"]
const MORPHS := {"shoulder_width":"ShoulderWidth", "torso_mass":"TorsoMass", "hip_width":"HipWidth", "thigh_mass":"ThighMass", "calf_mass":"CalfMass", "arm_mass":"ArmMass"}

static func load_config(cfg: ConfigFile) -> String:
	var path := Paths.resolve_project(FILENAME, true)
	if path.is_empty():
		cfg.clear()
		return "Rennersconfiguratie ontbreekt: " + FILENAME
	var error := read_config(path, cfg)
	if error.is_empty():
		error = validate(cfg)
	else:
		cfg.clear()
	return "" if error.is_empty() else "%s: %s" % [path, error]

static func read_config(path: String, cfg: ConfigFile) -> String:
	cfg.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Kon configuratie niet openen: " + path
	var source := file.get_as_text().trim_prefix("\uFEFF")
	var error := cfg.parse(source)
	if error != OK:
		cfg.clear()
		return "Ongeldige CFG (%d)" % error
	# ConfigFile merges repeated headers and keys. Check before using its values.
	var section := ""
	var seen := {}
	var keys := {}
	# Mask strings (including multiline values) and comments before scanning headers.
	var quoted_or_comment := RegEx.new()
	quoted_or_comment.compile('("(?:[^"\\\\]|\\\\[\\s\\S])*")|(;)[^\\r\\n]*')
	var structure := quoted_or_comment.sub(source, "$2", true)
	for raw_line in structure.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("["):
			var end := line.find("]")
			if end < 0: continue
			var header := line.substr(1, end - 1)
			if not cfg.has_section(header): continue
			if seen.has(header): return "Dubbele sectie [%s]" % header
			section = header
			seen[section] = true
			keys.clear()
		elif not section.is_empty() and not line.begins_with(";"):
			var delimiter := line.find("=")
			if delimiter < 0: continue
			var key := line.left(delimiter).strip_edges()
			if not cfg.has_section_key(section, key): continue
			if keys.has(key): return "Dubbele sleutel %s in [%s]" % [key, section]
			keys[key] = true
	return ""

static func validate(cfg: ConfigFile) -> String:
	var ids := {}
	for section in cfg.get_sections():
		if not section.begins_with("rider_"): continue
		var slot := rider_slot(section)
		if slot == 0:
			return "Ongeldige rennersectie [%s] (gebruik rider_01, rider_02, …)" % section
		var category := normalized_category(cfg, section)
		if category not in ["men", "women"]:
			return "Ongeldige categorie in [%s] (verwacht men of women)" % section
		var country: Variant = cfg.get_value(section, "country", "")
		if not country is String or (not country.strip_edges().is_empty() and Countries.valid_country(country).is_empty()):
			return "Ongeldig land in [%s]" % section
		var raw_id: Variant = cfg.get_value(section, "id", section)
		if not raw_id is String:
			return "Ongeldige ID in [%s]" % section
		var id := stable_id(cfg, section)
		if id == "player":
			return "Gereserveerde ID in [%s]: player" % section
		if ids.has(id):
			return "Dubbele ID %s in [%s] en [%s]" % [id, ids[id], section]
		ids[id] = section
	return ""

static func rider_slot(section: String) -> int:
	if not section.begins_with("rider_"): return 0
	var suffix := section.substr(6)
	if not suffix.is_valid_int(): return 0
	var slot := int(suffix)
	return slot if slot > 0 and section == "rider_%02d" % slot else 0

static func stable_id(cfg: ConfigFile, section: String) -> String:
	var id := String(cfg.get_value(section, "id", section)).strip_edges()
	return section if id.is_empty() else id

static func normalized_category(cfg: ConfigFile, section: String) -> String:
	var value: Variant = cfg.get_value(section, "category", "men")
	return value.strip_edges().to_lower() if value is String else ""

static func profile_kind(cfg: ConfigFile, section: String, fallback: int) -> int:
	var value: Variant = cfg.get_value(section, "profile", "")
	if value is String:
		match value.to_lower():
			"tt", "tijdrijder", "time_trialist": return 1
			"sprinter": return 2
			"aanvaller", "attacker": return 3
	return fallback

static func factor(cfg: ConfigFile, section: String, key: String) -> float:
	var value = cfg.get_value(section, key, 1.0)
	if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0: return 1.0
	return clampf(float(value), 0.1, 3.0)

static func entry(cfg: ConfigFile, index: int, default_profile: int) -> Dictionary:
	var section := "rider_%02d" % index
	var kind := profile_kind(cfg, section, default_profile)
	var outfit := {}
	for key in ["country", "number", "jersey_color", "jersey_secondary", "shorts_color", "helmet_color", "jersey_design", "country_kit", "skinsuit_png", "helmet_png", "visor", "hair_style", "hair_color"]:
		if cfg.has_section_key(section, key): outfit[key] = cfg.get_value(section, key)
	var country := Countries.from_kit(outfit)
	if country.is_empty(): country = Countries.Box.COUNTRIES[(index - 1) % Countries.Box.COUNTRIES.size()]
	outfit["country"] = country
	var shapes := {}
	for key in MORPHS:
		if cfg.has_section_key(section, key):
			var value = cfg.get_value(section, key, 0.0)
			if (value is float or value is int) and is_finite(float(value)): shapes[MORPHS[key]] = clampf(float(value), -1.0, 1.0)
	var cp := factor(cfg, section, "cp_factor")
	var peak := factor(cfg, section, "max_power_factor")
	var reserve := factor(cfg, section, "w_prime_factor")
	var category := normalized_category(cfg, section)
	outfit["category"] = category
	var name := String(cfg.get_value(section, "name", TYPES[kind] + " %02d" % index)).strip_edges()
	var id := stable_id(cfg, section)
	var records := {}
	for key in ["record_250m_s", "record_1000m_s", "record_4000m_s", "best_5s_w", "best_15s_w", "best_60s_w"]:
		var value = cfg.get_value(section, key, 0.0)
		if (value is float or value is int) and is_finite(float(value)) and float(value) > 0: records[key] = float(value)
	return {"id":id, "slot":index, "name":name if not name.is_empty() else TYPES[kind], "profile":kind, "category":category, "country":country, "jersey":outfit, "morphs":shapes,
		"cp_factor":cp, "max_power_factor":peak, "w_prime_factor":reserve, "cp_w":CP[kind]*cp, "max_power_w":maxf(CP[kind]*cp+1.0, PMAX[kind]*peak), "w_prime_j":WPRIME[kind]*reserve,
		"portrait_path":String(cfg.get_value(section, "portrait_path", "")), "portrait_url":String(cfg.get_value(section, "portrait_url", "")), "records":records}
