extends RefCounted
## Shared imported resources: explicit preloads also include every flag in exports.
const TEXTURES := {
	"belgium": preload("res://assets/flags/belgium.png"),
	"netherlands": preload("res://assets/flags/netherlands.png"),
	"france": preload("res://assets/flags/france.png"),
	"italy": preload("res://assets/flags/italy.png"),
	"germany": preload("res://assets/flags/germany.png"),
	"great_britain": preload("res://assets/flags/great_britain.png"),
	"denmark": preload("res://assets/flags/denmark.png"),
	"australia": preload("res://assets/flags/australia.png"),
	"new_zealand": preload("res://assets/flags/new_zealand.png"),
	"portugal": preload("res://assets/flags/portugal.png"),
	"united_states": preload("res://assets/flags/united_states.png"),
	"spain": preload("res://assets/flags/spain.png"),
	"switzerland": preload("res://assets/flags/switzerland.png"),
	"poland": preload("res://assets/flags/poland.png"),
	"japan": preload("res://assets/flags/japan.png"),
	"china": preload("res://assets/flags/china.png"),
	"czechia": preload("res://assets/flags/czechia.png"),
	"austria": preload("res://assets/flags/austria.png"),
	"kazakhstan": preload("res://assets/flags/kazakhstan.png"),
	"mexico": preload("res://assets/flags/mexico.png"),
	"argentina": preload("res://assets/flags/argentina.png"),
	"turkey": preload("res://assets/flags/turkey.png"),
	"venezuela": preload("res://assets/flags/venezuela.png"),
	"ireland": preload("res://assets/flags/ireland.png"),
	"colombia": preload("res://assets/flags/colombia.png"),
}

static func texture(country: String) -> Texture2D:
	# An unknown ID must never silently become another nation's flag.
	return TEXTURES.get(country) as Texture2D
