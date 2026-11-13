extends RefCounted
## Presentation only: the race remains frozen in INTRO until the normal start gate.
const APPROACH := 0.0
const WELCOME_END := 2.2
const DURATION := 26.0
const PURSUIT_DURATION := 28.0
const SIMPLE_DURATION := 2.5
const OPPONENT_START := 8.0
const OPPONENT_END := 10.0
const WELCOME := "Welkom bij Velodrome!"
const DISCIPLINES := {0: "scratch", 1: "puntenkoers", 3: "keirin", 4: "achtervolging", 5: "ploegenachtervolging", 6: "ploegkoers"}

static func welcome_for_mode(mode: int) -> String:
	if not DISCIPLINES.has(mode): return WELCOME
	return "Welkom bij de volgende wedstrijd: de %s!" % DISCIPLINES[mode]

# Lifetime is one game process/session, deliberately not cleared by cancel/reset.
var shown_this_session := false
var duration := DURATION
var opponent_card: PanelContainer
var light_show: Node3D
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
	opponent_card = preload("res://intro_opponent_card.gd").new()
	screen.add_child(opponent_card)
	opponent_card.setup(game)
	light_show = preload("res://intro_light_show.gd").new()
	light_show.setup(game)
	overlay.hide()

func start() -> void:
	# Only an accepted first start consumes the intro, including a manual skip.
	# Keep the normal finish path for subsequent events and mode switches.
	var settings := game.get_node_or_null("GameSettings")
	var repeat_intro: bool = settings != null and settings.always_show_intro
	var show_intro := repeat_intro or not shown_this_session
	shown_this_session = true
	subtitle.text = WELCOME
	duration = SIMPLE_DURATION if game.arena.simple_infield else (PURSUIT_DURATION if game.race_mode in [4, 5] else DURATION)
	original_cull_mask = game.camera.cull_mask
	game.camera.set_cull_mask_value(2, false)
	elapsed = 0.0
	active = true
	holding_chase = false
	game.start_state = "INTRO"
	game.look_back_held = false
	game.bikes[0].show()
	game._set_race_hud_visible(false)
	if not show_intro:
		finish()
		return
	if not game.arena.simple_infield:
		if game.race_mode in [4, 5]: opponent_card.prepare()
		light_show.start()
	overlay.show()
	_update_dialogue()

func cancel() -> void:
	if (active or holding_chase) and is_instance_valid(game): game.camera.cull_mask = original_cull_mask
	active = false
	holding_chase = false
	if is_instance_valid(overlay): overlay.hide()
	_stop_speaking()
	light_show.stop()
	opponent_card.clear()

func finish() -> void:
	if not active: return
	active = false
	holding_chase = true
	overlay.hide()
	_stop_speaking()
	light_show.stop()
	opponent_card.clear()
	# Reuse the existing live-trainer stop gate; never start a race directly.
	game.start_state = "WAIT_STOP"
	game.zero_stable = 0.0
	game._set_race_hud_visible(true)
	if game.result_panel != null: game.result_panel.hide()

func advance(delta: float) -> void:
	if not active: return
	elapsed = minf(elapsed + delta, duration)
	_update_dialogue()
	if elapsed >= duration: finish()

func _stop_speaking() -> void:
	if is_instance_valid(suite):
		suite.set_speaking(0, false)
		suite.set_speaking(1, false)

func opponent_visible(time: float) -> bool:
	return game.race_mode in [4, 5] and time >= OPPONENT_START and time < OPPONENT_END

func _update_dialogue() -> void:
	if game.arena.simple_infield:
		caption_panel.visible = true
		subtitle.text = welcome_for_mode(game.race_mode)
		opponent_card.hide()
		return
	caption_panel.visible = elapsed < 5.5
	subtitle.text = WELCOME if elapsed < WELCOME_END else welcome_for_mode(game.race_mode)
	if is_instance_valid(suite):
		suite.set_speaking(0, elapsed < WELCOME_END)
		suite.set_speaking(1, elapsed >= WELCOME_END and elapsed < 5.5)
	opponent_card.visible = opponent_visible(elapsed)
	if opponent_card.visible:
		opponent_card.reset_size()
		var viewport_size := game.get_viewport().get_visible_rect().size
		# Card occupies the left third; the opponent is framed to its right.
		opponent_card.position = Vector2(28, maxf(70, (viewport_size.y - opponent_card.size.y) * 0.5))
	light_show.update_show(elapsed, duration, sample(elapsed).target)

static func smooth_phase(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func chase_pose() -> Dictionary:
	var s: float = game._rider_distance(0, game.distances[0])
	var lane: float = game.lane_offsets[0]
	return {"position": game._at(s - 3.0, lane) + Vector3.UP * 2.3,
		"target": game.bikes[0].position + Vector3.UP * 1.1 + game._direction(s, lane) * 3.0, "fov": 66.0}

func _close_pose() -> Dictionary:
	if not is_instance_valid(suite):
		return chase_pose()
	var tr: Transform3D = suite.global_transform
	return {"position": tr * Vector3(0.0, 2.15, 4.6), "target": tr * Vector3(0.0, 1.65, 0.0), "fov": 52.0}

func opponent_pose() -> Dictionary:
	var team: bool = game.race_mode == 5
	var first: int = game.team_size if team else 1
	var count: int = game.team_size if team else 1
	var center := Vector3.ZERO
	for i in range(first, first + count): center += game.bikes[i].position
	center /= float(count)
	var s: float = game._rider_distance(first, game.distances[first])
	var forward: Vector3 = game._direction(s, game.lane_offsets[first])
	var inward: Vector3 = (game._at(s, 0.0) - game._at(s, 1.0)).normalized()
	var pos := center - forward * (10.0 if team else 7.0) + inward * (12.0 if team else 9.0)
	pos.y = 7.0
	var target := center + Vector3.UP * 1.0
	# Offset the subject to screen-right, keeping the card clear of all riders.
	var right := (target - pos).normalized().cross(Vector3.UP).normalized()
	target -= right * (3.2 if team else 2.4)
	return {"position": pos, "target": target, "fov": 48.0 if team else 42.0}

func tour_start() -> float:
	return 12.0 if game.race_mode in [4, 5] else 10.0

func flight_knots() -> Array:
	var start: Vector3 = _close_pose().position
	var b := tour_start()
	var entry: Vector3 = game._at(125.0, 4.0)
	entry.y = 7.8
	var bend: Vector3 = game._at(147.15, 4.5)
	bend.y = 11.0
	var bend_exit: Vector3 = game._at(165.0, 4.0)
	bend_exit.y = 8.5
	var points: Array
	if game.race_mode in [4, 5]:
		points = [[WELCOME_END, start], [4.8, Vector3(24, 11, -40)],
			[6.3, Vector3(-8, 10, -32)], [OPPONENT_START, opponent_pose().position],
			[OPPONENT_END, opponent_pose().position], [b, entry]]
	else:
		# Cross the infield, then follow the back straight past the open boxes.
		points = [[WELCOME_END, start], [3.8, Vector3(0, 10, -27)],
			[5.6, Vector3(-20.0, 4.8, -20.0)],
			[8.0, Vector3(-20.0, 5.8, 15.0)], [b, entry]]
	# A wide, moving arc keeps scenery in context: no zooms or subject holds.
	# Pass the interview tent on its OPEN west side, not its opaque east wall.
	points.append_array([[b + 3.0, bend], [b + 5.5, bend_exit],
		[b + 7.5, Vector3(15.8, 5.4, 41.0)],
		[b + 10.0, Vector3(5.0, 2.75, 26.0)],
		[b + 11.0, Vector3(5.2, 2.70, 19.0)],
		[b + 12.0, Vector3(13.0, 2.65, 12.0)], [duration, chase_pose().position]])
	return points

func _velocity(points: Array, i: int) -> Vector3:
	if i == 0 or i == points.size() - 1: return Vector3.ZERO
	if game.race_mode in [4, 5] and points[i][0] in [OPPONENT_START, OPPONENT_END]: return Vector3.ZERO
	if i == points.size() - 2:
		# A direct, monotonically descending final leg beside the press tent.
		return (points[-1][1] - points[i][1]) / (points[-1][0] - points[i][0])
	var velocity: Vector3 = (points[i + 1][1] - points[i - 1][1]) / (points[i + 1][0] - points[i - 1][0])
	var before_y: float = (points[i][1].y - points[i-1][1].y) / (points[i][0] - points[i-1][0])
	var after_y: float = (points[i+1][1].y - points[i][1].y) / (points[i+1][0] - points[i][0])
	# Limit vertical tangents so a shallow descent never dips and rises again.
	if before_y * after_y <= 0.0:
		velocity.y = 0.0
	else:
		var limit := 3.0 * minf(absf(before_y), absf(after_y))
		velocity.y = clampf(velocity.y, -limit, limit)
	return velocity

func _hermite(a: Vector3, b: Vector3, va: Vector3, vb: Vector3, span: float, u: float) -> Vector3:
	return (2*u*u*u - 3*u*u + 1) * a + (u*u*u - 2*u*u + u) * span * va + (-2*u*u*u + 3*u*u) * b + (u*u*u - u*u) * span * vb

func flight_position(time: float) -> Vector3:
	var points := flight_knots()
	for i in range(points.size() - 1):
		if time <= points[i + 1][0]:
			var span: float = points[i + 1][0] - points[i][0]
			var u := clampf((time - points[i][0]) / span, 0.0, 1.0)
			return _hermite(points[i][1], points[i+1][1], _velocity(points, i), _velocity(points, i+1), span, u)
	return points[-1][1]

func focus_keys() -> Array:
	var b := tour_start()
	var close := _close_pose()
	var keys: Array = [[WELCOME_END, close.target, 52.0]]
	if game.race_mode in [4, 5]:
		var opponent := opponent_pose()
		keys.append_array([[4.8, Vector3(0, 7, 0), 64.0],
			[OPPONENT_START, opponent.target, opponent.fov], [OPPONENT_END, opponent.target, opponent.fov]])
	else:
		keys.append_array([[3.8, Vector3(-12, 2.5, -17), 64.0],
			[5.6, Vector3(-12.6, 1.8, -10), 64.0],
			[8.0, Vector3(-12.6, 2.2, 24), 64.0]])
	keys.append_array([[b, Vector3(-5, 5, 58), 64.0],
		[b + 3.0, Vector3(-3, 10.0, 64), 64.0],
		[b + 5.5, Vector3(35, 10.0, 52), 64.0],
		[b + 7.5, Vector3(7.8, 1.4, 37.0), 64.0],
		[b + 10.0, Vector3(9.5, 1.4, 23.5), 64.0],
		[b + 12.0, chase_pose().target, 66.0], [duration, chase_pose().target, 66.0]])
	return keys

func sample(time: float) -> Dictionary:
	if game.arena.simple_infield:
		return chase_pose()
	var close := _close_pose()
	if time <= WELCOME_END: return close
	var pos := flight_position(time)
	var keys := focus_keys()
	for i in range(keys.size() - 1):
		if time <= keys[i + 1][0]:
			var span: float = keys[i+1][0] - keys[i][0]
			var weight := clampf((time - keys[i][0]) / span, 0.0, 1.0)
			# Interpolate heading and elevation, never a world-space point that
			# can pass under/through the moving camera during a turn.
			var a: Vector3 = (keys[i][1] - flight_position(keys[i][0])).normalized()
			var b: Vector3 = (keys[i+1][1] - flight_position(keys[i+1][0])).normalized()
			var yaw_a := atan2(a.x, -a.z)
			var yaw_delta := wrapf(atan2(b.x, -b.z) - yaw_a, -PI, PI)
			var eased := smooth_phase(weight)
			var yaw := yaw_a + yaw_delta * eased
			var pitch_a := asin(clampf(a.y, -1.0, 1.0))
			var pitch_b := asin(clampf(b.y, -1.0, 1.0))
			if keys[i][0] >= tour_start():
				pitch_a = maxf(pitch_a, deg_to_rad(-20.0))
				pitch_b = maxf(pitch_b, deg_to_rad(-20.0))
			var pitch := lerpf(pitch_a, pitch_b, eased)
			# Wide turns stay near the horizon, showing the stadium between views.
			if keys[i][0] >= tour_start():
				var outward := sin(PI * weight) * smoothstep(0.7, 1.7, absf(yaw_delta))
				pitch = lerpf(pitch, deg_to_rad(-3.0), outward)
			var view := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
			var target := pos + view * 20.0
			return {"position": pos, "target": target, "fov": lerpf(keys[i][2], keys[i+1][2], smooth_phase(weight))}
	return chase_pose()

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
	if active and opponent_card.visible: opponent_card.update_portraits()
	return true


