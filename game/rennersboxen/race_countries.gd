extends RefCounted
## Resolve national kit IDs and explicit race country metadata, never jersey colours/names.
const Box = preload("res://rennersboxen/rider_box.gd")
const CODES := {"BEL":"belgium","NED":"netherlands","FRA":"france","ITA":"italy","GER":"germany","GBR":"great_britain","DEN":"denmark","AUS":"australia","NZL":"new_zealand","POR":"portugal","USA":"united_states"}

static func valid_country(value: String) -> String:
	var id := value.strip_edges().to_lower()
	if id in Box.COUNTRIES:return id
	return String(CODES.get(value.strip_edges().to_upper(),""))

static func from_kit(config: Dictionary) -> String:
	var explicit := valid_country(String(config.get("country","")))
	if not explicit.is_empty():return explicit
	var file := String(config.get("skinsuit_png","")).replace("\\","/")
	# A custom PNG filename is not evidence of nationality; only this game's national kit folder is.
	var parts := file.split("/")
	for i in range(parts.size()-1):
		if parts[i]=="national_kits":return valid_country(parts[i+1])
	return valid_country(String(config.get("country_kit","")))

static func configured_country(game: Node, index: int) -> String:
	var section := "player" if index==0 else "rider_%02d" % index
	var kit: Dictionary = {}
	if bool(game.get("rider_config_ready")):
		var config: ConfigFile = game.get("rider_config")
		for key in ["country","country_kit","skinsuit_png"]:
			kit[key] = config.get_value(section,key,"")
	if index==0:
		var appearance: RefCounted = game.get("player_appearance")
		# The selected player outfit takes priority over personal config defaults.
		var resolved: Dictionary = appearance.resolve(game.call("get_player_appearance_base"))
		var selected := from_kit(resolved)
		if not selected.is_empty():return selected
	# For an AI, prefer explicit nationality, then the actually applied visual kit.
	var explicit := valid_country(String(kit.get("country","")))
	if not explicit.is_empty():return explicit
	var bikes: Array = game.get("bikes")
	if index<bikes.size() and is_instance_valid(bikes[index]) and bikes[index].get_child_count()>0:
		var visual: Node = bikes[index].get_child(0)
		var actual := from_kit({"skinsuit_png":visual.get("skinsuit_png"),"country_kit":visual.get("country_kit")})
		if not actual.is_empty():return actual
	return from_kit(kit)

static func roster(game: Node) -> Dictionary:
	var player := configured_country(game,0)
	if player.is_empty():player = "belgium"
	var count := int(game.get("rider_count"))
	var mode := int(game.get("race_mode"))
	var countries: Array[String] = []
	if mode==5:
		var team_size := int(game.get("team_size"))
		var opponent := ""
		for i in range(team_size,count):
			opponent = configured_country(game,i)
			if not opponent.is_empty():break
		if opponent.is_empty():opponent = "netherlands"
		for i in range(count):countries.append(player if i<team_size else opponent)
	else:
		for i in range(count):
			var id := player if i==0 else configured_country(game,i)
			# Legacy profiles have no nationality field: stable event defaults give them one.
			# Explicit national kits always override this fallback; rider appearance is preserved.
			if id.is_empty():id = Box.COUNTRIES[i % Box.COUNTRIES.size()]
			countries.append(id)
	var riding: Array[String] = []
	if mode in [4,5]:
		for id in countries:
			if id not in riding:riding.append(id)
	return {"start_list":countries,"player":player,"mode":"team_pursuit" if mode==5 else ("pursuit" if mode==4 else "mass"),"racing":riding}
