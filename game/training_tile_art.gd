extends Control
## Resolution-independent miniature workout chart for the training tile.
const Style := preload("res://menu_theme.gd")
func _ready() -> void:
	resized.connect(queue_redraw)
func _draw() -> void:
	var area := Rect2(Vector2(0, size.y * .18), Vector2(size.x, size.y * .64))
	draw_style_box(Style.panel(Style.PALE, Style.LINE, 0, 12), area)
	var origin := area.position + Vector2(18, 24)
	var width := area.size.x - 36
	var height := maxf(20, area.size.y - 50)
	for level in [.25, .5, .75]:
		var y: float = origin.y + height * float(level)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), Style.LINE, 1, true)
	var base := origin.y + height
	var x := origin.x
	var sections := [[.18, .25, .55, Color("54b87a")], [.18, .65, .65, Color("439ee9")], [.08, .35, .35, Color("9aaab9")]]
	for i in range(3):
		sections.append([.07, .95, .95, Color("e5767b")])
		sections.append([.04, .35, .35, Color("9aaab9")])
	sections.append([.23, .55, .2, Color("56b7e8")])
	for section in sections:
		var span: float = width * float(section[0])
		var points := PackedVector2Array([Vector2(x, base), Vector2(x, base - height * float(section[1])), Vector2(x + span, base - height * float(section[2])), Vector2(x + span, base)])
		draw_colored_polygon(points, section[3])
		x += span
	draw_line(Vector2(origin.x, base), Vector2(origin.x + width, base), Style.MUTED, 1, true)
