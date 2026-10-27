extends RefCounted
## Presentation only: the race remains frozen in INTRO until the normal start gate.
const APPROACH := 4.0
const WELCOME_END := 10.0
const DEPART_END := 14.0
const ORBIT_END := 32.0
const DURATION := 36.0
const WELCOME := "Welkom bij Velodrome! We maken ons klaar voor de volgende wedstrijd."
var active := false
var holding_chase := false
var elapsed := 0.0
var game: Node3D
var suite: Node3D
var overlay: CanvasLayer
var subtitle: Label
var caption_panel: PanelContainer
var original_cull_mask := 1

func setup(owner_game: Node3D) -> void:
	game = owner_game
	suite = game.arena.get_node_or_null("EuroMaxCyclingCommentaryBox")
	overlay = CanvasLayer.new()
	overlay.name = "BroadcastIntroOverlay"
	overlay.layer = 20
	game.add_child(overlay)
	var screen := Control.new()
	overlay.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel = PanelContainer.new()
	screen.add_child(caption_panel)
	caption_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption_panel.offset_left = 24
	caption_panel.offset_right = -24
	caption_panel.offset_top = -150
	caption_panel.offset_bottom = -65
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.07, 0.92)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	caption_panel.add_theme_stylebox_override("panel", style)
	subtitle = Label.new()
	subtitle.text = WELCOME
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	caption_panel.add_child(subtitle)
	var skip := Button.new()
	skip.text = "Intro overslaan  ·  Enter / Spatie"
	screen.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -330
	skip.offset_right = -24
	skip.offset_top = -52
	skip.offset_bottom = -12
	skip.pressed.connect(finish)
	overlay.hide()

func start() -> void:
	original_cull_mask = game.camera.cull_mask
	game.camera.set_cull_mask_value(2, false)
	elapsed = 0.0
	active = true
	holding_chase = false
	game.start_state = "INTRO"
	game.look_back_held = false
	game.bikes[0].show()
	game._set_race_hud_visible(false)
	overlay.show()
	_update_dialogue()

func cancel() -> void:
	if (active or holding_chase) and is_instance_valid(game): game.camera.cull_mask = original_cull_mask
	active = false
	holding_chase = false
	if is_instance_valid(overlay): overlay.hide()
	_stop_speaking()

func finish() -> void:
	if not active: return
	active = false
	holding_chase = true
	overlay.hide()
	_stop_speaking()
	# Reuse the existing live-trainer stop gate; never start a race directly.
	game.start_state = "WAIT_STOP"
	game.zero_stable = 0.0
	game._set_race_hud_visible(true)
	if game.result_panel != null: game.result_panel.hide()

func advance(delta: float) -> void:
	if not active: return
	elapsed = minf(elapsed + delta, DURATION)
	_update_dialogue()
	if elapsed >= DURATION: finish()

func _stop_speaking() -> void:
	if is_instance_valid(suite):
		suite.set_speaking(0, false)
		suite.set_speaking(1, false)

func _update_dialogue() -> void:
	var welcome := elapsed >= APPROACH and elapsed < WELCOME_END
	caption_panel.visible = welcome
	if is_instance_valid(suite):
		suite.set_speaking(0, welcome and elapsed < 6.1)
		suite.set_speaking(1, welcome and elapsed >= 6.1)

static func smooth_phase(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func chase_pose() -> Dictionary:
	var s: float = game._rider_distance(0, game.distances[0])
	var lane: float = game.lane_offsets[0]
	return {"position": game._at(s - 3.0, lane) + Vector3.UP * 2.3,
		"target": game.bikes[0].position + Vector3.UP * 1.1 + game._direction(s, lane) * 3.0, "fov": 66.0}

func orbit_pose(t: float) -> Dictionary:
	# Increasing track distance is explicitly CCW in main._at. Exactly one lap.
	var s: float = game.LAP * smooth_phase(t)
	var pos: Vector3 = game._at(s, 6.0)
	pos.y = lerpf(12.0, 7.0, smooth_phase(t))
	var target: Vector3 = game._at(s + 17.0, 2.0)
	target.y = 2.0
	return {"position": pos, "target": target, "fov": 68.0}

func sample(time: float) -> Dictionary:
	var tr: Transform3D = suite.global_transform
	var close_pos := tr * Vector3(0.0, 2.15, 4.6)
	var close_target := tr * Vector3(0.0, 1.65, 0.0)
	if time < APPROACH:
		var t := smooth_phase(time / APPROACH)
		return {"position": (tr * Vector3(-8.0, 5.0, 13.0)).lerp(close_pos, t), "target": close_target, "fov": lerpf(62.0, 52.0, t)}
	if time < WELCOME_END:
		return {"position": close_pos, "target": close_target, "fov": 52.0}
	if time < DEPART_END:
		var t := smooth_phase((time - WELCOME_END) / (DEPART_END - WELCOME_END))
		var first := orbit_pose(0.0)
		return {"position": close_pos.lerp(first.position, t), "target": close_target.lerp(first.target, t), "fov": lerpf(52.0, 68.0, t)}
	if time < ORBIT_END:
		return orbit_pose((time - DEPART_END) / (ORBIT_END - DEPART_END))
	var last := orbit_pose(1.0)
	var chase := chase_pose()
	var t := smooth_phase((time - ORBIT_END) / (DURATION - ORBIT_END))
	return {"position": last.position.lerp(chase.position, t), "target": last.target.lerp(chase.target, t), "fov": lerpf(68.0, 66.0, t)}

func apply_camera() -> bool:
	if not active and not holding_chase: return false
	if not active and game.start_state not in ["WAIT_STOP", "COUNTDOWN"]:
		holding_chase = false
		game.camera.cull_mask = original_cull_mask
		game.bikes[0].visible = game.camera_mode != 2
		return false
	var pose := sample(elapsed) if active else chase_pose()
	game.camera.global_position = pose.position
	game.camera.look_at(pose.target)
	game.camera.fov = pose.fov
	game.camera_roll = 0.0
	return true

