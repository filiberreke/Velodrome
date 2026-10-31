extends Node3D
## EuroMax Cycling commentary booth with both commentators.
## Use announce(who, stream) for a frontal announcement shot, or set talking on the commentators directly.

@export var glass_visible := true:
	set(v):
		glass_visible = v
		_apply_glass()
## Switch the AnnouncementCamera on when an announcement starts.
@export var use_announcement_camera := true

@onready var links: Node3D = $CommentatorLinks
@onready var rechts: Node3D = $CommentatorRechts
@onready var cam: Camera3D = $AnnouncementCamera

const SHOTS := {
	"duo": [Vector3(0.0, 1.30, 2.45), Vector3(0.0, 1.18, 0.0), 40.0],
	"links": [Vector3(-0.52, 1.22, 1.55), Vector3(-0.52, 1.20, 0.2), 32.0],
	"rechts": [Vector3(0.52, 1.22, 1.55), Vector3(0.52, 1.20, 0.2), 32.0],
}

func _ready() -> void:
	_apply_glass()

func _apply_glass() -> void:
	var g := find_child("BoothGlass", true, false)
	if g:
		g.visible = glass_visible

## who: "links", "rechts" or "duo". stream may be null (procedural talking for `seconds`).
func announce(who: String, stream: AudioStream = null, seconds := 4.0) -> void:
	frame_shot(who)
	if use_announcement_camera:
		cam.make_current()
	var speakers := [links, rechts] if who == "duo" else [links if who == "links" else rechts]
	for c in speakers:
		if stream:
			c.speak(stream)
		else:
			c.talking = true
	if stream == null:
		await get_tree().create_timer(seconds).timeout
		for c in speakers:
			c.talking = false

func frame_shot(who: String) -> void:
	var s: Array = SHOTS.get(who, SHOTS["duo"])
	cam.global_position = to_global(s[0])
	cam.look_at(to_global(s[1]), Vector3.UP)
	cam.fov = s[2]
