extends Label
## Three seconds total: quick pop, readable hold, then drift/fade upper right.
const DURATION := 3.0
var pending: Array[String] = []
var age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 54)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 3)
	hide()

func clear() -> void:
	pending.clear()
	text = ""
	age = 0.0
	hide()

func enqueue(message: String) -> void:
	pending.append(message)
	if not visible: _next()

func _next() -> void:
	if pending.is_empty():
		hide()
		return
	text = pending.pop_front()
	age = 0.0
	show()
	_present()

func _process(delta: float) -> void:
	if not visible: return
	age += delta
	if age >= DURATION:
		_next()
	else: _present()

func _present() -> void:
	var viewport_size := get_viewport_rect().size
	var exit_phase := clampf((age - 2.15) / .85, 0.0, 1.0)
	var pop := clampf(age / .22, 0.0, 1.0)
	var zoom := lerpf(.7, 1.0, 1.0 - pow(1.0 - pop, 3.0))
	var font_size := mini(54, maxi(24, int(viewport_size.x / 25)))
	add_theme_font_size_override("font_size", font_size)
	size = Vector2(viewport_size.x * .9, 110)
	pivot_offset = size * .5
	scale = Vector2.ONE * zoom
	position = Vector2(viewport_size.x * .05, viewport_size.y * .34) + Vector2(viewport_size.x * .38, -viewport_size.y * .3) * exit_phase * exit_phase
	modulate.a = 1.0 - exit_phase
