extends "res://rennersboxen/six_boxes.gd"

const Countries = preload("res://rennersboxen/race_countries.gd")
var game: Node3D
var _last_mode := ""

func setup(host: Node3D) -> void:
	game = host
	game.infield_riders_changed.connect(refresh)
	call_deferred("refresh")

func refresh() -> void:
	if not is_instance_valid(game):return
	var data := Countries.roster(game)
	if not configure(data.start_list,data.player,data.mode,data.racing):return
	# A new heat must immediately hide non-racing boxes before the countdown.
	if _last_mode!=data.mode:
		for i in range(boxes.size()):boxes[i].set_open(data.mode=="mass" or assigned_countries[i] in data.racing,0.0)
	_last_mode = data.mode
