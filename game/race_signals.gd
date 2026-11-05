extends Control
## Screen-space race cues. Presentation never advances the race or its jury.
const MenuStyle := preload("res://menu_theme.gd")
const BELL_DURATION := 2.8
var countdown_label: Label
var bell: TextureRect
var bell_age := BELL_DURATION
var last_lap_announced := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label = Label.new()
	countdown_label.name = "ScreenCountdown"
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.add_theme_font_override("font", MenuStyle.heading())
	countdown_label.add_theme_font_size_override("font_size", 310)
	countdown_label.add_theme_color_override("font_color", MenuStyle.PAPER)
	countdown_label.add_theme_color_override("font_outline_color", MenuStyle.INK)
	countdown_label.add_theme_constant_override("outline_size", 12)
	countdown_label.add_theme_color_override("font_shadow_color", MenuStyle.BLUE)
	countdown_label.add_theme_constant_override("shadow_offset_y", 10)
	add_child(countdown_label)
	bell = TextureRect.new()
	bell.name = "LastLapBell"
	bell.texture = preload("res://assets/branding/hud_last_lap_bell.png")
	bell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bell)
	resized.connect(_layout_bell)
	_layout_bell()
	clear()

func _layout_bell() -> void:
	if bell == null: return
	var edge := minf(430.0, minf(size.x * 0.44, size.y * 0.58))
	bell.size = Vector2.ONE * edge
	bell.position = (size - bell.size) * 0.5
	bell.pivot_offset = Vector2(edge * 0.5, edge * 0.17)

func clear() -> void:
	last_lap_announced = false
	bell_age = BELL_DURATION
	if countdown_label != null:
		countdown_label.text = ""
		countdown_label.hide()
	if bell != null:
		bell.hide()
		bell.rotation = 0.0
		bell.modulate.a = 1.0

func set_countdown(value: String) -> void:
	countdown_label.text = value
	countdown_label.visible = not value.is_empty()
	var start_signal := value in ["START!", "GO!"]
	countdown_label.add_theme_font_size_override("font_size", 190 if start_signal else 310)
	countdown_label.add_theme_color_override("font_color", MenuStyle.GOLD if start_signal else MenuStyle.PAPER)

func update_last_lap(active: bool, remaining_m: float, length_m: float, finished: bool) -> void:
	if finished or not active:
		bell.hide()
		bell_age = BELL_DURATION
		return
	if not last_lap_announced and length_m > 250.0 and remaining_m > 0.0 and remaining_m <= 250.0:
		last_lap_announced = true
		bell_age = 0.0
		bell.modulate.a = 1.0
		bell.show()

func _process(delta: float) -> void:
	if bell_age >= BELL_DURATION: return
	bell_age = minf(BELL_DURATION, bell_age + delta)
	bell.rotation = deg_to_rad(17.0) * sin(bell_age * TAU / 0.72)
	bell.modulate.a = clampf((BELL_DURATION - bell_age) / 0.35, 0.0, 1.0)
	bell.visible = bell_age < BELL_DURATION and countdown_label.text.is_empty()
