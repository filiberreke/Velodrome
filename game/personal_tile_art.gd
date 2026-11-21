extends Control
## Vector illustrations in the native ivory/blue Velodrome menu palette.
const Style = preload("res://menu_theme.gd")
@export_enum("rider", "palmares", "rides") var kind := "rider"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_style_box(Style.panel(Style.PALE, Style.LINE, 0, 12), Rect2(Vector2.ZERO, size))
	var c := Vector2(w * 0.5, h * 0.48)
	if kind == "palmares":
		draw_rect(Rect2(c + Vector2(-67, 44), Vector2(44, 38)), Style.BLUE)
		draw_rect(Rect2(c + Vector2(-22, 24), Vector2(44, 58)), Style.BLUE.lightened(0.17))
		draw_rect(Rect2(c + Vector2(23, 52), Vector2(44, 30)), Style.BLUE)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-31,-42),c+Vector2(31,-42),c+Vector2(24,-12),c+Vector2(0,2),c+Vector2(-24,-12)]), Style.WOOD)
		draw_arc(c+Vector2(-30,-28), 13, PI*0.5, PI*1.5, 24, Style.WOOD, 5, true)
		draw_arc(c+Vector2(30,-28), 13, -PI*0.5, PI*0.5, 24, Style.WOOD, 5, true)
		draw_line(c, c+Vector2(0,22), Style.WOOD, 6, true)
		draw_line(c+Vector2(-18,22), c+Vector2(18,22), Style.WOOD, 5, true)
	elif kind == "rides":
		var panel := Rect2(c+Vector2(-102,-67), Vector2(204,143))
		draw_style_box(Style.panel(Style.PAPER, Style.LINE, 0, 9), panel)
		for i in range(3):
			var y := panel.position.y + 28 + i*39
			draw_circle(Vector2(panel.position.x+23,y), 9, Style.BLUE if i==0 else Style.WOOD)
			draw_rect(Rect2(Vector2(panel.position.x+43,y-8),Vector2(112-i*13,5)),Style.INK)
			draw_rect(Rect2(Vector2(panel.position.x+43,y+3),Vector2(73+i*8,4)),Style.MUTED)
			if i<2: draw_line(Vector2(panel.position.x+14,y+19),Vector2(panel.end.x-14,y+19),Style.LINE,1)
	else:
		draw_circle(c+Vector2(0,-48), 24, Style.BLUE)
		draw_arc(c+Vector2(0,-48), 26, PI, TAU, 30, Style.WOOD, 6, true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-51,57),c+Vector2(-39,-11),c+Vector2(-18,-23),c+Vector2(18,-23),c+Vector2(39,-11),c+Vector2(51,57)]),Style.BLUE)
		draw_line(c+Vector2(-40,8),c+Vector2(40,8),Style.WOOD,6,true)
		draw_circle(c+Vector2(76,-42),15,Style.PAPER)
		draw_arc(c+Vector2(76,-42),9,0,TAU,28,Style.BLUE,3,true)
		draw_circle(c+Vector2(76,1),15,Style.PAPER)
		draw_line(c+Vector2(67,1),c+Vector2(85,1),Style.WOOD,4,true)
