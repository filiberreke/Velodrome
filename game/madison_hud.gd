extends Control
## Spatial timing marker freezes on GRAB; width then follows available momentum.
var state: Dictionary = {}
var caption: Label
var hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -300; offset_right = 300
	offset_top = 250; offset_bottom = 405
	caption = Label.new()
	caption.position = Vector2(20, 10)
	caption.add_theme_font_size_override("font_size", 23)
	add_child(caption)
	hint = Label.new()
	hint.position = Vector2(20, 112)
	hint.add_theme_font_size_override("font_size", 18)
	add_child(hint)

func update_state(value: Dictionary) -> void:
	state = value
	visible = not value.is_empty()
	if not visible: return
	var active: bool = state.active
	var phase_names := {"APPROACH":"Naderen", "GRAB":"Grijpen", "SLING":"Slingeren", "RELEASE":"Loslaten", "SEPARATE":"Uit elkaar rijden"}
	caption.text = "MADISON · %s · %s" % ["Advanced" if state.advanced else "Easy · max 70%", phase_names.get(state.phase, "Naderen") if active else "Naderen"]
	if not active: hint.text = state.message + " · ← → sturen"
	elif state.phase == "APPROACH": hint.text = "A: grijpen" if state.can_grab else "Nader binnen handbereik · ← → sturen"
	elif state.phase in ["GRAB", "SLING"]: hint.text = "A loslaten: %d%%" % roundi(state.efficiency * 100) if state.advanced else "Automatische slinger · %d%%" % roundi(state.efficiency * 100)
	else: hint.text = state.message
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	draw_style_box(preload("res://menu_theme.gd").panel(), Rect2(Vector2.ZERO, size))
	var bar := Rect2(20, 57, size.x - 40, 36)
	draw_rect(bar, Color("c6cbd0"))
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.72, 0), Vector2(bar.size.x * 0.16, bar.size.y)), Color("8dc799"))
	var centre: float = bar.position.x + bar.size.x * float(state.approach_t)
	var width: float = maxf(4.0, bar.size.x * 0.35 * float(state.efficiency))
	var left: float = clampf(centre - width * 0.5, bar.position.x, bar.end.x - width)
	draw_rect(Rect2(left, bar.position.y, width, bar.size.y), Color("256da5"))
	draw_line(Vector2(centre, 51), Vector2(centre, 99), Color("152b43"), 3.0)
