extends "res://rennersboxen/six_boxes.gd"

const Countries = preload("res://rennersboxen/race_countries.gd")
var game: Node3D
var _last_mode := ""
var crews: Array[Node3D] = []

func setup(host: Node3D, shared_kit: RefCounted) -> void:
	game = host
	for box in boxes:
		var crew := preload("res://rennersboxen/box_people.gd").new()
		crew.name = "BoxPeople"
		box.add_child(crew)
		crew.setup(box,shared_kit)
		crews.append(crew)
	game.infield_riders_changed.connect(refresh)
	call_deferred("refresh")

func refresh() -> void:
	if not is_instance_valid(game):return
	var data := Countries.roster(game)
	if not configure(data.start_list,data.player,data.mode,data.racing):return
	for i in range(boxes.size()):crews[i].configure(assigned_countries[i],boxes[i].is_active())
	# A new heat must immediately hide non-racing boxes before the countdown.
	if _last_mode!=data.mode:
		for i in range(boxes.size()):boxes[i].set_open(data.mode=="mass" or assigned_countries[i] in data.racing,0.0)
	_last_mode = data.mode
