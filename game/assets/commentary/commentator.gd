extends Node3D
## EuroMax Cycling commentator: idle/talk animation, blinking and lip-sync on the face blend shapes.
## Attach to an instance of commentator_links.glb or commentator_rechts.glb.
##
## Blend shapes on the mesh: open, wide, round, smile, blink_L, blink_R, brow_up (0..1).
## Lip-sync: call speak(stream) to play a voice line, the mouth follows the loudness of `voice_bus`.
## Without audio, set `talking = true` for procedural "talking" (good for crowd noise / placeholder).

@export var talking := false:
	set(v):
		talking = v
		_update_animation()
## Resting expression (the right commentator has a natural smile).
@export_range(0.0, 1.0) var rest_smile := 0.0
@export_range(0.0, 1.0) var rest_open := 0.0
## Audio bus used for speak(); create a bus named like this, or leave "Master".
@export var voice_bus := "Master"
@export var mouth_gain := 1.0
@export var blink_interval := Vector2(2.2, 5.5)

var _mesh: MeshInstance3D
var _anim: AnimationPlayer
var _player: AudioStreamPlayer3D
var _idx := {}
var _t := 0.0
var _next_blink := 1.5
var _blink_t := -1.0
var _open := 0.0
var _shape := Vector2.ZERO   # (wide, round)
var _shape_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_mesh = _find_mesh(self)
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _mesh:
		for n in ["open", "wide", "round", "smile", "blink_L", "blink_R", "brow_up"]:
			_idx[n] = _mesh.find_blend_shape_by_name(n)
		_enable_vertex_colors()
	if _anim:
		# Godot strips the "_loop" suffix on import (and sets looping); accept both spellings
		for a in ["idle", "talk", "idle_loop", "talk_loop"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_player = AudioStreamPlayer3D.new()
	_player.bus = voice_bus
	add_child(_player)
	_player.position = Vector3(0, 1.15, 0.1)
	_next_blink = _rng.randf_range(blink_interval.x, blink_interval.y)
	_update_animation()

## Play a voice line with lip-sync.
func speak(stream: AudioStream) -> void:
	_player.stream = stream
	_player.bus = voice_bus
	_player.play()
	talking = true
	if not _player.finished.is_connected(_on_voice_done):
		_player.finished.connect(_on_voice_done)

func _on_voice_done() -> void:
	talking = false

func _process(delta: float) -> void:
	if not _mesh:
		return
	_t += delta
	var target_open := 0.0
	if talking:
		if _player.playing:
			var bus := AudioServer.get_bus_index(voice_bus)
			var db := maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.get_bus_peak_volume_right_db(bus, 0))
			target_open = clampf(remap(db, -42.0, -8.0, 0.0, 1.0), 0.0, 1.0) * mouth_gain
		else:
			# procedural syllables: 4-6 per second with pauses between phrases
			var syl := 0.5 + 0.5 * sin(_t * 31.0) * sin(_t * 7.3 + 1.0)
			var phrase := smoothstep(-0.2, 0.4, sin(_t * 1.3) + 0.35 * sin(_t * 0.37))
			target_open = clampf(syl * phrase * 0.85, 0.0, 0.9)
		if _rng.randf() < delta * 6.0:
			_shape_target = Vector2(_rng.randf_range(0.0, 0.6), _rng.randf_range(0.0, 0.5)) if _rng.randf() < 0.6 else Vector2.ZERO
	else:
		_shape_target = Vector2.ZERO
	_open = lerpf(_open, target_open, 1.0 - exp(-delta * 22.0))
	_shape = _shape.lerp(_shape_target, 1.0 - exp(-delta * 10.0))
	_set_shape("open", rest_open + _open * (1.0 - rest_open))
	_set_shape("wide", _shape.x * _open)
	_set_shape("round", _shape.y * _open)
	_set_shape("smile", rest_smile * (1.0 - 0.5 * _open))
	_set_shape("brow_up", 0.35 * _open if talking else 0.0)
	# blinking
	_next_blink -= delta
	if _next_blink <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_next_blink = _rng.randf_range(blink_interval.x, blink_interval.y)
	var b := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		b = sin(clampf(_blink_t / 0.16, 0.0, 1.0) * PI)
		if _blink_t > 0.16:
			_blink_t = -1.0
	_set_shape("blink_L", b)
	_set_shape("blink_R", b)

func _set_shape(shape: String, v: float) -> void:
	var i: int = _idx.get(shape, -1)
	if i >= 0:
		_mesh.set_blend_shape_value(i, v)


func _update_animation() -> void:
	if not _anim:
		return
	var a := "talk" if talking else "idle"
	if not _anim.has_animation(a):
		a += "_loop"
	if _anim.has_animation(a) and _anim.current_animation != a:
		_anim.play(a, 0.4)

## The skin and hair materials carry their detail (lips, stubble, scalp, hair highlights) in vertex colours.
func _enable_vertex_colors() -> void:
	var mesh := _mesh.mesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as BaseMaterial3D
		if m and (m.resource_name.ends_with("_skin") or m.resource_name.ends_with("_hair")):
			if not m.vertex_color_use_as_albedo:
				m = m.duplicate()
				m.vertex_color_use_as_albedo = true
				_mesh.set_surface_override_material(s, m)

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).mesh.get_blend_shape_count() > 0:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null
