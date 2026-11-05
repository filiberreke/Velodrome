extends StyleBox
## A focus frame outside the control: four light pixels, then four navy pixels.
## Neither layer fills the control or changes its layout or selected state.
const GAP := 4.0
const WIDTH := 4.0
var outer := StyleBoxFlat.new()
var spacer := StyleBoxFlat.new()

func _init(radius: int = 9) -> void:
	outer.draw_center = false
	outer.border_color = Color("122c50")
	outer.set_border_width_all(int(WIDTH))
	outer.set_corner_radius_all(radius + int(GAP + WIDTH))
	spacer.draw_center = false
	spacer.border_color = Color("fffdf8")
	spacer.set_border_width_all(int(GAP))
	spacer.set_corner_radius_all(radius + int(GAP))
	set_content_margin_all(0)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(GAP + WIDTH)

func _draw(canvas_item: RID, rect: Rect2) -> void:
	outer.draw(canvas_item, rect.grow(GAP + WIDTH))
	spacer.draw(canvas_item, rect.grow(GAP))
