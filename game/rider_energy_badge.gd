extends Node3D
## Actual AI Wprime reserve. Human Wprime stays unknown unless it is modeled.
class Battery extends Control:
	var reserve := -1.0
	func _draw() -> void:
		var box := Rect2(2,3,size.x-12,size.y-6)
		draw_rect(box,Color("263846"))
		draw_rect(box,Color("c1d4df"),false,2.0)
		draw_rect(Rect2(size.x-10,size.y*0.3,7,size.y*0.4),Color("c1d4df"))
		if reserve >= 0.0:
			var colour := Color("55dca1") if reserve > 0.3 else (Color("ffc45b") if reserve > 0.15 else Color("ff7272"))
			draw_rect(Rect2(5,6,maxf(0.0,(size.x-18)*clampf(reserve,0.,1.)),size.y-12),colour)
var viewport: SubViewport
var watts_label: Label
var name_label: Label
var reserve_label: Label
var battery: Battery

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,140)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var panel := PanelContainer.new()
	panel.size = Vector2(320,140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.10,0.14,0.9)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel",style)
	viewport.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",24)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	watts_label = Label.new()
	watts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watts_label.add_theme_font_size_override("font_size",30)
	column.add_child(watts_label)
	var row := HBoxContainer.new()
	column.add_child(row)
	battery = Battery.new()
	battery.custom_minimum_size = Vector2(192,30)
	row.add_child(battery)
	reserve_label = Label.new()
	reserve_label.add_theme_font_size_override("font_size",22)
	row.add_child(reserve_label)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.0065
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.layers = 2
	add_child(sprite)
	hide()

func show_rider(power: float, reserve: float, location: Vector3, active: bool, score: int = 0, points_mode: bool = false, rider_name: String = "") -> void:
	visible = active
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active: return
	global_position = location+Vector3.UP*3.0
	name_label.text = rider_name
	name_label.visible = not rider_name.is_empty()
	watts_label.text = "%.0f W" % maxf(0.0,power)
	if points_mode: watts_label.text += " · %d pt" % score
	reserve_label.text = "%d%%" % roundi(100.*clampf(reserve,0.,1.)) if reserve >= 0.0 else "W′ —"
	battery.reserve = reserve
	battery.queue_redraw()
