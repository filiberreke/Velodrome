extends SceneTree
## Actual compatibility-renderer screenshots plus a measurable camera flyby.
const OUTPUT := "res://verification/commentary_box/"
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D

func _initialize() -> void: call_deferred("run")

func hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control: node.hide()
	for child in node.get_children(): hide_ui(child)

func capture(label: String, position: Vector3, target: Vector3, fov: float = 45.0) -> void:
	camera.position = position; camera.look_at(target); camera.fov = fov
	for i in range(15): await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.save_png(OUTPUT + label + ".png") == OK)
	print("CAPTURE " + label)

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new(); viewport.size = Vector2i(1664,936)
	viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X; root.add_child(viewport)
	stage = Node3D.new(); viewport.add_child(stage)
	var game := preload("res://main.gd").new(); stage.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	await process_frame; game._set_menu_visible(false); hide_ui(game)
	camera = Camera3D.new(); stage.add_child(camera); camera.far = 350; camera.near = 0.05; camera.make_current()
	var suite: Node3D = game.arena.get_node("EuroMaxCyclingCommentaryBox")
	var tr := suite.global_transform
	await capture("Cabine_in_stadion",tr * Vector3(6.3,3.3,9.8),tr * Vector3(0,1.45,0))
	await capture("Commentatoren_close",tr * Vector3(1.7,1.95,4.0),tr * Vector3(0,1.57,-.1),48)
	await capture("Finish_en_tweede_ring",tr * Vector3(-13,10,23),tr * Vector3(0,-1,2),62)
	await capture("Broadcast_details",tr * Vector3(-1.7,1.60,1.15),tr * Vector3(0,1.25,-.55),70)
	var times: Array[float] = []
	for i in range(150):
		var t := float(i) / 149.0
		camera.position = tr * Vector3(lerpf(-4.2,4.2,t),2.0,4.8)
		camera.look_at(tr * Vector3(0,1.45,0)); camera.fov = 48
		var start := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		times.append(float(Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	var stats := {"renderer": RenderingServer.get_current_rendering_method(), "viewport": [1664,936], "frames": times.size(), "median_frame_ms": times[75], "p95_frame_ms": times[142], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open(OUTPUT+"flyby_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"\t")); file.close()
	print("COMMENTARY_FLYBY_OK "+JSON.stringify(stats))
	# Repeat the same path with the suite hidden to isolate its GPU cost.
	suite.hide()
	for i in range(20): await RenderingServer.frame_post_draw
	var baseline: Array[float] = []
	for i in range(150):
		var t := float(i) / 149.0
		camera.position = tr * Vector3(lerpf(-4.2,4.2,t),2.0,4.8)
		camera.look_at(tr * Vector3(0,1.45,0))
		var start := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		baseline.append(float(Time.get_ticks_usec()-start)/1000.0)
	baseline.sort()
	stats["baseline_hidden_median_ms"] = baseline[75]
	stats["baseline_hidden_p95_ms"] = baseline[142]
	stats["baseline_hidden_draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	file = FileAccess.open(OUTPUT+"flyby_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"\t")); file.close()
	viewport.free(); quit()
