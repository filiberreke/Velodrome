extends Node3D
## Explicit adapter: caller supplies country IDs from its actual start list.
## It never guesses a country from jersey colours, rider names or profile numbers.

const Box = preload("res://rennersboxen/rider_box.gd")
var boxes: Array[Node3D] = []
var assigned_countries: Array[String] = []

func _ready() -> void:
	for i in range(6):
		var box := Box.new()
		box.country = Box.COUNTRIES[i]
		# Local +Z opening faces world -X, toward the back straight.
		# Zone depth 3.8 m: world x [-16.50, -12.70].
		box.position = Vector3(-14.60,0,-25.0+10.0*i)
		box.rotation.y = -PI/2.0
		add_child(box)
		boxes.append(box)
		assigned_countries.append(box.country)

func configure(start_list: Array[String], player_country: String, mode: String = "mass", racing_countries: Array[String] = []) -> bool:
	# Validate before mutating any displayed assignment.
	if player_country not in Box.COUNTRIES or boxes.size()!=6: return false
	if mode not in ["mass","pursuit","team_pursuit"]: return false
	for id in start_list+racing_countries:
		if id not in Box.COUNTRIES: return false
	var counts: Dictionary = {}
	for id in start_list: counts[id] = int(counts.get(id,0))+1
	var ranked: Array = counts.keys()
	# Equal frequency: canonical country ID alphabetic, stable for every client.
	ranked.sort_custom(func(a,b): return int(counts[a])>int(counts[b]) if counts[a]!=counts[b] else a<b)
	var selected: Array[String] = []
	for id in ranked.slice(0,6): selected.append(id)
	if player_country not in selected:
		if selected.size()==6: selected[5] = player_country
		else: selected.append(player_country)
	if mode!="mass":
		# Every racing country must get a physical box even if outside the top six.
		var required: Array[String] = [player_country]
		for id in racing_countries:
			if id not in required: required.append(id)
		if required.size()>6: return false
		for id in required:
			if id not in selected:
				if selected.size()<6: selected.append(id)
				else:
					for j in range(5,-1,-1):
						if selected[j] not in required:
							selected[j] = id
							break
	# Keep six physical cabins when a small start list contains fewer countries.
	# With fewer distinct countries, zero-count countries complete the six-box row.
	for id in Box.COUNTRIES:
		if selected.size()==6: break
		if id not in selected: selected.append(id)
	assigned_countries = selected
	for i in range(6):
		var active := i<selected.size()
		boxes[i].visible = active
		if active:
			boxes[i].set_country(selected[i])
			boxes[i].set_open(mode=="mass" or selected[i] in racing_countries)
	return true
