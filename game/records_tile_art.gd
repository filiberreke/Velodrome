extends Control
## Native UI artwork: trophy and podium, no bitmap dependency.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var centre := size * Vector2(0.5, 0.45)
	var gold := Color("f4d46a")
	var teal := Color("51d7df")
	draw_rect(Rect2(centre + Vector2(-64, 40), Vector2(42, 35)), Color("2f6577"))
	draw_rect(Rect2(centre + Vector2(-21, 22), Vector2(42, 53)), Color("3f8d99"))
	draw_rect(Rect2(centre + Vector2(22, 49), Vector2(42, 26)), Color("2f6577"))
	draw_colored_polygon(PackedVector2Array([centre + Vector2(-30, -40), centre + Vector2(30, -40), centre + Vector2(23, -10), centre + Vector2(0, 1), centre + Vector2(-23, -10)]), gold)
	draw_arc(centre + Vector2(-29, -26), 14, PI * 0.5, PI * 1.5, 24, gold, 5, true)
	draw_arc(centre + Vector2(29, -26), 14, -PI * 0.5, PI * 0.5, 24, gold, 5, true)
	draw_line(centre, centre + Vector2(0, 18), gold, 6, true)
	draw_line(centre + Vector2(-17, 18), centre + Vector2(17, 18), gold, 5, true)
	draw_line(centre + Vector2(-85, 78), centre + Vector2(85, 78), teal, 2, true)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color("12283c"); style.set_corner_radius_all(12)
	return style
