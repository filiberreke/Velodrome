extends RefCounted
## ZWO reader for the Velodrome training engine. Durations are seconds,
## power values are FTP fractions, not absolute watts.
const BLOCKS := ["Warmup", "Cooldown", "SteadyState", "Ramp", "FreeRide", "IntervalsT"]
var error := ""
var name := ""
var description := ""
var author := ""
var blocks: Array[Dictionary] = []

func _number(attrs: Dictionary, key: String, fallback: float = -1.0) -> float:
	if not attrs.has(key): return fallback
	var value := str(attrs[key])
	return float(value) if value.is_valid_float() else -1.0

func _attrs(parser: XMLParser) -> Dictionary:
	var result := {}
	for i in range(parser.get_attribute_count()):
		result[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
	return result

func _append(kind: String, attrs: Dictionary) -> bool:
	if kind == "IntervalsT":
		var count := int(_number(attrs, "Repeat"))
		var on_time := _number(attrs, "OnDuration")
		var off_time := _number(attrs, "OffDuration")
		var on_power := _number(attrs, "OnPower")
		var off_power := _number(attrs, "OffPower")
		if count < 1 or count > 500 or on_time <= 0 or off_time <= 0 or on_power < 0 or off_power < 0:
			error = "Ongeldige IntervalsT-waarden"
			return false
		for i in range(count):
			blocks.append({"kind":"SteadyState", "duration":on_time, "power_low":on_power, "power_high":on_power, "events":[]})
			blocks.append({"kind":"SteadyState", "duration":off_time, "power_low":off_power, "power_high":off_power, "events":[]})
		return true
	var duration := _number(attrs, "Duration")
	var low := _number(attrs, "PowerLow", _number(attrs, "Power", 0.0))
	var high := _number(attrs, "PowerHigh", _number(attrs, "Power", low))
	if duration <= 0 or duration > 86400 or low < 0 or high < 0:
		error = "Ongeldige duur of vermogenswaarde in " + kind
		return false
	blocks.append({"kind":kind, "duration":duration, "power_low":low, "power_high":high, "events":[],
		"ftptest":attrs.get("ftptest", "0") == "1", "ramptest":attrs.get("ramptest", "0") == "1"})
	return true

func parse(xml: String) -> bool:
	error = ""
	name = ""
	description = ""
	author = ""
	blocks.clear()
	var parser := XMLParser.new()
	if parser.open_buffer(xml.to_utf8_buffer()) != OK:
		error = "XML kan niet geopend worden"
		return false
	var field := ""
	var active := false
	var total := 0.0
	while true:
		var status := parser.read()
		if status == ERR_FILE_EOF: break
		if status != OK:
			error = "Ongeldige XML"
			return false
		var kind := parser.get_node_name()
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if kind in ["name", "description", "author"]: field = kind
				elif kind in BLOCKS:
					if not _append(kind, _attrs(parser)): return false
					total += float(blocks[-1]["duration"]) if kind != "IntervalsT" else float(_number(_attrs(parser), "Repeat")) * (_number(_attrs(parser), "OnDuration") + _number(_attrs(parser), "OffDuration"))
					if total > 86400:
						error = "Training duurt langer dan 24 uur"
						return false
					active = true
				elif kind == "textevent" and active and not blocks.is_empty():
					var a := _attrs(parser)
					var offset := _number(a, "timeoffset")
					if offset >= 0 and offset <= float(blocks[-1]["duration"]):
						blocks[-1]["events"].append({"time":offset, "message":str(a.get("message", ""))})
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				match field:
					"name": name += parser.get_node_data()
					"description": description += parser.get_node_data()
					"author": author += parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if kind == field: field = ""
				if kind in BLOCKS: active = false
	if blocks.is_empty():
		error = "Geen ondersteunde trainingsblokken gevonden"
		return false
	return true

func duration() -> float:
	var total := 0.0
	for block in blocks: total += float(block.duration)
	return total
