extends Node
## Read-only race feed + presentation + one shared, throttled 2D render target.
signal stadium_cue(kind: String, payload: Dictionary)
const Feed := preload("res://infinity_race_feed.gd")
const Model := preload("res://infinity_scoreboard_model.gd")
const Canvas := preload("res://infinity_scoreboard_canvas.gd")
var feed := Feed.new()
var model := Model.new()
var screen: Node3D
var game: Node3D
var viewport: SubViewport
var canvas: Node2D
var data := {}
var poll_elapsed := 0.1
var render_elapsed := 0.1
var render_count := 0
var suspended := false
var cue_age := 10.0

func setup(owner_screen: Node3D, owner_game: Node3D) -> void:
	screen = owner_screen; game = owner_game
	viewport = SubViewport.new()
	viewport.name = "Scoreboard2D"
	viewport.size = Vector2i(1536, 512)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	canvas = Canvas.new()
	viewport.add_child(canvas)
	model.stadium_cue.connect(_on_cue)
	screen.set_content(viewport.get_texture())
	screen.set_scoreboard_layout(true)

func _on_cue(kind: String, payload: Dictionary) -> void:
	cue_age = 0.0
	stadium_cue.emit(kind, payload)

func _process(delta: float) -> void:
	if suspended or not is_instance_valid(game) or viewport == null: return
	poll_elapsed += delta
	render_elapsed += delta
	cue_age += delta
	if poll_elapsed >= 0.1 or data.is_empty():
		poll_elapsed = 0.0
		data = feed.sample(game)
	model.update(data, delta)
	var animated: bool = (model.state == Model.INTRO and model.age < 2.0) or (model.remaining > 0.0 and not model.moment.is_empty()) or (model.state == Model.FINISH and model.age < 9.0) or canvas.fade < 1.0
	var interval := 1.0 / (30.0 if animated else 8.0)
	if render_elapsed >= interval:
		canvas.present(model.view(), model.age, render_elapsed)
		render_elapsed = 0.0
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		render_count += 1
	# A brief response on the EXISTING emissive ring edge only, no Light3D.
	screen.set_edge_reaction(maxf(0.0, 1.0 - cue_age / 1.4))

func resume_scoreboard() -> void:
	suspended = false
	screen.set_content(viewport.get_texture())
	poll_elapsed = 0.1

func suspend_scoreboard() -> void:
	suspended = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.set_edge_reaction(0.0)
