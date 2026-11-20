extends RefCounted
## Convert explicit input files in order, keeping every original section and value.
const Catalog := preload("res://rider_catalog.gd")

static func merge(paths: PackedStringArray) -> Dictionary:
	var combined := ConfigFile.new()
	var errors := PackedStringArray()
	var sections := {}
	var ids := {}
	for source_index in range(paths.size()):
		var path := paths[source_index]
		var cfg := ConfigFile.new()
		var error := Catalog.read_config(path, cfg)
		if error.is_empty():
			error = Catalog.validate(cfg)
		if not error.is_empty():
			errors.append("%s: %s" % [path, error])
			continue
		for section in cfg.get_sections():
			var origin := "%s [%s]" % [path, section]
			var values := {}
			for key in cfg.get_section_keys(section):
				values[key] = cfg.get_value(section, key)
			var slot := Catalog.rider_slot(section)
			if source_index > 0 and slot > 0 and Catalog.profile_kind(cfg, section, 0) == 0:
				# The old omnium loader always fell back to the time-trialist profile.
				if values.get("profile", "") == "":
					values["profile"] = "tt"
				else:
					errors.append("Onbekend profiel in %s (oude terugval: tt)" % origin)
			if sections.has(section):
				errors.append("Dubbele sectie: %s en %s" % [sections[section], origin])
			else:
				sections[section] = origin
				for key in values:
					combined.set_value(section, key, values[key])
			if slot == 0: continue
			var id := Catalog.stable_id(cfg, section)
			if ids.has(id):
				var previous: Dictionary = ids[id]
				var fields := PackedStringArray()
				for key in values:
					if previous.fields.has(key) and previous.fields[key] != values[key]:
						fields.append(key)
				if not fields.is_empty():
					fields.sort()
				var details := " (verschillende waarden: %s)" % ", ".join(fields) if not fields.is_empty() else ""
				errors.append("Dubbele ID %s: %s en %s%s" % [id, previous.origin, origin, details])
			else:
				ids[id] = {"origin": origin, "fields": values}
	return {"config": combined if errors.is_empty() else null, "errors": errors}
