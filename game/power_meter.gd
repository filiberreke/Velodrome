extends Control
## Presentation only. Watts and the stable team target are supplied by the race.
const INK := Color("f3f5fa")
const GREEN := Color("86f66c")
const RED := Color("ff343e")
const BAR_HEIGHT := 64.0
var watts := 0.0
var target := -1.0
var target_visible := false
var fill_color := Color.WHITE
var value_label: Label
var target_label: Label
var role_label: Label

static func fraction(power: float) -> float:
	var bounded := clampf(power, 0.0, 1500.0)
	return bounded / 600.0 * 0.9 if bounded <= 600.0 else 0.9 + (bounded - 600.0) / 900.0 * 0.1

static func zone_color(power: float) -> Color:
	if power <= 100.0: return Color.WHITE
	if power <= 200.0: return GREEN
	if power <= 300.0: return Color("ffe247")
	if power <= 400.0: return Color("ff922e")
	if power <= 600.0: return RED
	return Color("7b1727")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 146.0
	value_label = _label(42)
	value_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	value_label.offset_bottom = BAR_HEIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_constant_override("outline_size", 6)
	value_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.85))
	target_label = _label(22)
	role_label = _label(17)
	role_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	role_label.offset_top = 116.0
	role_label.offset_bottom = 144.0
	role_label.clip_text = true
	resized.connect(_layout_target)
	set_power(0.0)

func _label(font_size: int) -> Label:
	var item := Label.new()
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", INK)
	item.add_theme_constant_override("outline_size", 3)
	item.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(item)
	return item

func set_power(actual: float, goal: float = -1.0, show_goal: bool = false, role: String = "") -> void:
	watts = maxf(0.0, actual) if is_finite(actual) else 0.0
	target = goal if is_finite(goal) else -1.0
	target_visible = show_goal and target >= 0.0
	fill_color = (GREEN if watts >= target - 20.0 else RED) if target_visible else zone_color(watts)
	if value_label != null:
		value_label.text = "%.0f W" % watts
		target_label.text = "%.0f W" % target if target_visible else ""
		target_label.visible = target_visible
		role_label.text = role
		_layout_target()
	queue_redraw()

func _layout_target() -> void:
	if target_label == null: return
	var label_width := minf(144.0, size.x)
	target_label.position = Vector2(clampf(size.x * fraction(target) - label_width * 0.5, 0.0, maxf(0.0, size.x - label_width)), 84.0)
	target_label.size = Vector2(label_width, 30.0)

func _draw() -> void:
	var rect := Rect2(0, 0, size.x, BAR_HEIGHT)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = Color(0.95, 0.97, 1.0, 0.75)
	outline.set_border_width_all(1)
	outline.set_corner_radius_all(32)
	var width := size.x * fraction(watts)
	if width > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = fill_color
		fill.set_corner_radius_all(32)
		fill.draw(get_canvas_item(), Rect2(0, 0, width, BAR_HEIGHT))
	outline.draw(get_canvas_item(), rect)
	if target_visible:
		var x := size.x * fraction(target)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 68), Vector2(x - 10, 81), Vector2(x + 10, 81)]), RED)
