extends RefCounted
const Countries := preload("res://rennersboxen/race_countries.gd")
const CP := [0.0, 265.0, 240.0, 250.0]
const WPRIME := [0.0, 24120.4, 30638.0, 32658.4]
const PMAX := [0.0, 856.79, 1661.88, 1149.10]
const TYPES := ["Speler", "Tijdrijder", "Sprinter", "Aanvaller"]
const MORPHS := {"shoulder_width":"ShoulderWidth", "torso_mass":"TorsoMass", "hip_width":"HipWidth", "thigh_mass":"ThighMass", "calf_mass":"CalfMass", "arm_mass":"ArmMass"}

static func factor(cfg: ConfigFile, section: String, key: String) -> float:
	var value = cfg.get_value(section, key, 1.0)
	if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0: return 1.0
	return clampf(float(value), 0.1, 3.0)

static func entry(cfg: ConfigFile, index: int, default_profile: int) -> Dictionary:
	var section := "rider_%02d" % index
	var kind := default_profile
	match String(cfg.get_value(section, "profile", "")).to_lower():
		"tt", "tijdrijder", "time_trialist": kind = 1
		"sprinter": kind = 2
		"aanvaller", "attacker": kind = 3
	var outfit := {}
	for key in ["country", "number", "jersey_color", "jersey_secondary", "shorts_color", "helmet_color", "jersey_design", "country_kit", "skinsuit_png", "helmet_png", "visor"]:
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
	var name := String(cfg.get_value(section, "name", TYPES[kind] + " %02d" % index)).strip_edges()
	var id := String(cfg.get_value(section, "id", section)).strip_edges()
	if id.is_empty(): id = section
	var records := {}
	for key in ["record_250m_s", "record_1000m_s", "record_4000m_s", "best_5s_w", "best_15s_w", "best_60s_w"]:
		var value = cfg.get_value(section, key, 0.0)
		if (value is float or value is int) and is_finite(float(value)) and float(value) > 0: records[key] = float(value)
	return {"id":id, "slot":index, "name":name if not name.is_empty() else TYPES[kind], "profile":kind, "country":country, "jersey":outfit, "morphs":shapes,
		"cp_factor":cp, "max_power_factor":peak, "w_prime_factor":reserve, "cp_w":CP[kind]*cp, "max_power_w":maxf(CP[kind]*cp+1.0, PMAX[kind]*peak), "w_prime_j":WPRIME[kind]*reserve,
		"portrait_path":String(cfg.get_value(section, "portrait_path", "")), "portrait_url":String(cfg.get_value(section, "portrait_url", "")), "records":records}
