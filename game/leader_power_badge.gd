extends Node3D
## Camera-facing, fixed-scale power readout, one per AI-led team.
var viewport: SubViewport
var power_label: Label
var power_bar: ProgressBar
var rider_id := -1

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 92)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var panel := PanelContainer.new()
	panel.size = Vector2(320, 92)
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.13, 0.16, 0.19, 0.82)
	shell.set_corner_radius_all(12)
	shell.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", shell)
	viewport.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	power_label = Label.new()
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_font_size_override("font_size", 32)
	power_label.add_theme_color_override("font_color", Color("f3f5fa"))
	column.add_child(power_label)
	power_bar = ProgressBar.new()
	power_bar.max_value = 1000.0
	power_bar.show_percentage = false
	power_bar.custom_minimum_size.y = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.06, 0.08, 0.65)
	track.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("51d7df")
	fill.set_corner_radius_all(6)
	power_bar.add_theme_stylebox_override("background", track)
	power_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(power_bar)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.0035
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.layers = 2
	add_child(sprite)
	hide()

func show_power(id: int, watts: float, location: Vector3, active: bool) -> void:
	rider_id = id if active else -1
	visible = active
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		return
	global_position = location + Vector3.UP * 2.12
	power_label.text = "%.0f W" % maxf(0.0, watts)
	power_bar.value = maxf(0.0, watts)
