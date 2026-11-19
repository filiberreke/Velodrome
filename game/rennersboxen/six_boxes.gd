extends Node3D
## Explicit adapter: caller supplies country IDs from its actual start list.
## It never guesses a country from jersey colours, rider names or profile numbers.

const Box = preload("res://rennersboxen/rider_box.gd")
var boxes: Array[Node3D] = []
var assigned_countries: Array[String] = []

func _ready() -> void:
	for i in range(9):
		var box := Box.new()
		box.visual_seed = randi()
		box.country = Box.COUNTRIES[i]
		# Local +Z opening faces world -X, toward the back straight.
		# Row moved two metres inward; the front rail meets the new perimeter.
		box.position = Vector3(preload("res://infield_layout.gd").BOX_X, 0, -24.8 + 5.7 * float(i) + 2.0 * float(i / 3))
		box.rotation.y = -PI/2.0
		add_child(box)
		boxes.append(box)
		assigned_countries.append(box.country)

func configure(start_list: Array[String], player_country: String, mode: String = "mass", racing_countries: Array[String] = []) -> bool:
	# Validate before mutating any displayed assignment.
	if player_country not in Box.COUNTRIES or boxes.size()!=9: return false
	if mode not in ["mass","pursuit","team_pursuit","time_trial"]: return false
	for id in start_list+racing_countries:
		if id not in Box.COUNTRIES: return false
	var counts: Dictionary = {}
	for id in start_list: counts[id] = int(counts.get(id,0))+1
	var ranked: Array = counts.keys()
	# Equal frequency: canonical country ID alphabetic, stable for every client.
	ranked.sort_custom(func(a,b): return int(counts[a])>int(counts[b]) if counts[a]!=counts[b] else a<b)
	var selected: Array[String] = []
	for id in ranked.slice(0,9): selected.append(id)
	if player_country not in selected:
		if selected.size()==9: selected[8] = player_country
		else: selected.append(player_country)
	if mode!="mass":
		# Every racing country must get a physical box even if outside the top six.
		var required: Array[String] = [player_country]
		for id in racing_countries:
			if id not in required: required.append(id)
		if required.size()>9: return false
		for id in required:
			if id not in selected:
				if selected.size()<9: selected.append(id)
				else:
					for j in range(8,-1,-1):
						if selected[j] not in required:
							selected[j] = id
							break
	# Keep nine physical cabins when a small start list contains fewer countries.
	# With fewer distinct countries, zero-count countries complete the nine-box row.
	for id in Box.COUNTRIES:
		if selected.size()==9: break
		if id not in selected: selected.append(id)
	assigned_countries = selected
	for i in range(9):
		var active := i<selected.size()
		boxes[i].visible = active
		if active:
			boxes[i].bike_variant = "track" if mode=="mass" else "pursuit"
			boxes[i].set_country(selected[i])
			boxes[i].set_open(mode=="mass" or selected[i] in racing_countries)
	return true
