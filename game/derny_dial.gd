extends Control
const Style := preload("res://menu_theme.gd")
var kmh := 0.0
var fraction := 0.0
var remaining := 60
var approach := false
func _ready() -> void:
	custom_minimum_size = Vector2(0,260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func update_dial(speed: float, progress: float, seconds: int, runup: bool) -> void:
	kmh = speed; fraction = clampf(progress,0,1); remaining = seconds; approach = runup
	queue_redraw()
func _draw() -> void:
	draw_style_box(Style.panel(Color(.96,.945,.906,.78),Style.LINE,0,12),Rect2(Vector2.ZERO,size))
	var font := get_theme_default_font()
	draw_string(font,Vector2(20,30),"Derny",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Style.INK)
	var center := Vector2(size.x*.5,140)
	var radius := 78.0
	draw_arc(center,radius,0,TAU,96,Style.LINE,10,true)
	if fraction > .001: draw_arc(center,radius,-PI/2,-PI/2+TAU*fraction,96,Style.BLUE,10,true)
	draw_string(font,Vector2(center.x-105,center.y+3),"%.1f km/u" % kmh,HORIZONTAL_ALIGNMENT_CENTER,210,30,Style.INK)
	draw_string(font,Vector2(center.x-90,center.y+30),"Aanloop" if approach else "nog %d s" % remaining,HORIZONTAL_ALIGNMENT_CENTER,180,17,Style.MUTED)
	for i in range(2):
		var x := center.x-70+i*100
		draw_string(font,Vector2(x,size.y-29),"−" if i == 0 else "+",HORIZONTAL_ALIGNMENT_CENTER,40,24,Style.INK)
		draw_string(font,Vector2(x,size.y-9),"←" if i == 0 else "→",HORIZONTAL_ALIGNMENT_CENTER,40,20,Style.INK)
