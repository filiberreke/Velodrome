extends Control
## Scalable history postcard: past sessions in a table, with a clock.
const Style := preload("res://menu_theme.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	draw_style_box(Style.panel(Style.PALE, Style.LINE, 0, 12), Rect2(Vector2.ZERO, size))
	var factor := minf(size.x / 200.0, size.y / 160.0)
	draw_set_transform((size - Vector2(200, 160) * factor) * .5, 0, Vector2.ONE * factor)
	draw_style_box(Style.panel(Style.PAPER, Style.LINE, 0, 8), Rect2(16, 20, 168, 120))
	draw_style_box(Style.panel(Style.BLUE, Color.TRANSPARENT, 0, 6), Rect2(16, 20, 168, 26))
	for x in [27, 77, 140]: draw_line(Vector2(x, 33), Vector2(x + 26, 33), Style.PAPER, 3, true)
	for row in range(3):
		var y := 64.0 + row * 27
		draw_line(Vector2(26, y), Vector2(52, y), Style.MUTED, 3, true)
		draw_line(Vector2(77, y), Vector2(125, y), Style.BLUE if row == 0 else Style.MUTED, 3, true)
		draw_line(Vector2(142, y), Vector2(171, y), Style.WOOD, 3, true)
		if row < 2: draw_line(Vector2(23, y + 13), Vector2(176, y + 13), Style.LINE, 1, true)
	draw_line(Vector2(65, 50), Vector2(65, 133), Style.LINE, 1, true)
	draw_circle(Vector2(162, 126), 26, Style.PAPER)
	draw_arc(Vector2(162, 126), 25, 0, TAU, 64, Style.BLUE, 3, true)
	draw_line(Vector2(162, 126), Vector2(162, 111), Style.BLUE, 3, true)
	draw_line(Vector2(162, 126), Vector2(175, 131), Style.BLUE, 3, true)
	draw_circle(Vector2(162, 126), 2.5, Style.WOOD)
