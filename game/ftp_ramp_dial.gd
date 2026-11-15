extends Control
## Step countdown inspired by the existing derny training dial.
const Palette := preload("res://menu_theme.gd")
var current_w := 0
var next_w := 100
var seconds_left := 300.0
var phase := "WARMUP"

func _ready() -> void:
	custom_minimum_size = Vector2(0, 280)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_step(watts: int, following: int, seconds: float, current_phase: String) -> void:
	current_w = watts
	next_w = following
	seconds_left = maxf(0.0, seconds)
	phase = current_phase
	queue_redraw()

func _draw() -> void:
	draw_style_box(Palette.panel(Color(0.96, 0.945, 0.906, 0.78), Palette.LINE, 0, 12), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	draw_string(font, Vector2(20, 32), "VOLGENDE STAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	var center := Vector2(size.x * 0.5, 141)
	var radius := 74.0
	draw_arc(center, radius, 0.0, TAU, 96, Palette.LINE, 10.0, true)
	var total: float = 300.0 if phase == "WARMUP" else (1200.0 if phase == "TWENTY" else 60.0)
	var progress := clampf(1.0 - seconds_left / total, 0.0, 1.0) if phase != "CONNECTING" else 0.0
	if progress > 0.001:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, Palette.BLUE, 10.0, true)
	var current_text := "VRIJ" if phase in ["WARMUP","TWENTY"] else ("%d W" % current_w if phase == "RAMP" else "ERG")
	draw_string(font, Vector2(center.x - 100, center.y + 10), current_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 37, Palette.INK)
	var caption := "20 min vrije test" if phase == "TWENTY" else ("Opwarming" if phase == "WARMUP" else ("Bevestigen..." if phase == "CONNECTING" else "Huidig doel"))
	draw_string(font, Vector2(center.x - 95, center.y + 35), caption, HORIZONTAL_ALIGNMENT_CENTER, 190, 17, Palette.MUTED)
	var display_seconds := ceili(seconds_left)
	var upcoming := "Nog %02d:%02d · richtlijn %.0f W" % [display_seconds / 60, display_seconds % 60, float(next_w)] if phase == "TWENTY" else "Volgende stap %d W over %02d:%02d" % [next_w, display_seconds / 60, display_seconds % 60]
	if phase == "CONNECTING": upcoming = "Wachten op ERG-bevestiging"
	draw_string(font, Vector2(12, size.y - 25), upcoming, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 18, Palette.INK)
