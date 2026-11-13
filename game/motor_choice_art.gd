extends RefCounted
const Style := preload("res://menu_theme.gd")

static func derny(owner_node: Node) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 300)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	owner_node.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Style.PALE
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_energy = .8
	world.add_child(sky)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	world.add_child(light)
	world.add_child(preload("res://derny_visual.gd").new())
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.position = Vector3(4.8, 2.0, 3.5)
	camera.look_at(Vector3(0, .9, 0))
	camera.current = true
	return viewport.get_texture()

class Heavy extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if size.x <= 0 or size.y <= 0: return
		draw_set_transform(Vector2.ZERO, 0, size / Vector2(240, 130))
		draw_style_box(Style.panel(Style.PALE, Color.TRANSPARENT, 0, 8), Rect2(0, 0, 240, 130))
		for x in [55, 188]:
			draw_circle(Vector2(x, 101), 22, Style.MUTED)
			draw_circle(Vector2(x, 101), 14, Style.IVORY)
			draw_circle(Vector2(x, 101), 4, Style.LINE)
		draw_colored_polygon(PackedVector2Array([Vector2(35, 69), Vector2(64, 58), Vector2(104, 58), Vector2(121, 42), Vector2(156, 39), Vector2(171, 63), Vector2(156, 86), Vector2(87, 91), Vector2(68, 72)]), Style.MUTED)
		draw_line(Vector2(170, 55), Vector2(188, 101), Style.MUTED, 8, true)
		draw_line(Vector2(162, 43), Vector2(174, 26), Style.MUTED, 5, true)
		draw_line(Vector2(170, 28), Vector2(189, 28), Style.MUTED, 5, true)
		draw_style_box(Style.panel(Style.LINE, Color.TRANSPARENT, 0, 4), Rect2(72, 51, 43, 9))
		draw_rect(Rect2(106, 70, 37, 19), Style.LINE)
