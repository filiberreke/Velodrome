extends Node2D
## A single 2D stadium graphics canvas; no extra 3D camera or HUD duplication.
const LOGO := preload("res://assets/boarding/velodrome-boarding.png")
const W := 1536.0
const H := 512.0
var font: Font = ThemeDB.fallback_font
var current := {}
var previous := {}
var fade := 1.0
var age := 0.0
var transition_key := ""

func present(data: Dictionary, elapsed: float, delta: float) -> void:
	var key: String = str(data.state) + ":" + str(data.moment) + ":" + str(data.get("page", 0))
	if data.badge == "WINNAAR": key += ":confirmed"
	if key != transition_key:
		previous = current.duplicate(true)
		fade = 0.0 if not current.is_empty() else 1.0
		transition_key = key
	current = data
	age = elapsed
	fade = minf(1.0, fade + delta / 0.45)
	queue_redraw()

func text(value: String, at: Vector2, max_width: float, size: int, tint: Color) -> void:
	var display := value
	var actual := size
	while actual > 26 and font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > max_width: actual -= 2
	if font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > max_width:
		while display.length() > 1 and font.get_string_size(display + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > max_width: display = display.left(display.length() - 1)
		display += "…"
	draw_string(font, at, display, HORIZONTAL_ALIGNMENT_LEFT, max_width, actual, tint)

func layer(data: Dictionary, alpha: float) -> void:
	if data.is_empty() or alpha <= 0: return
	var white := Color(0.96, 0.98, 1.0, alpha)
	var soft := Color(0.64, 0.79, 0.87, alpha)
	var gold := Color(0.95, 0.75, 0.37, alpha)
	if data.state == "INTRO":
		var reveal := smoothstep(0.0, 1.3, age)
		draw_texture_rect(LOGO, Rect2(300, 85 - (1.0 - reveal) * 18, 936, 312), false, Color(1, 1, 1, alpha * reveal))
		text(data.headline, Vector2(48, 62), 1440, 40, white)
		text(data.footer, Vector2(48, 475), 1440, 40, gold)
		return
	draw_texture_rect(LOGO, Rect2(32, 16, 204, 68), false, Color(1, 1, 1, alpha))
	text(data.title, Vector2(280, 65), 1200, 34, soft)
	text(data.badge, Vector2(42, 140), 1440, 34, gold)
	var rows: Array = data.rows
	var burst: bool = age < 1.25 and (data.state in ["SPRINT", "LAP_GAIN"] or data.badge == "WINNAAR")
	var full_hero: bool = burst or rows.is_empty() or data.moment in ["final_lap", "sprint"]
	text(data.headline, Vector2(42, 295 if full_hero else 265), 1450 if full_hero else 740, 174 if full_hero else 116, white)
	if not full_hero:
		draw_line(Vector2(790, 164), Vector2(790, 398), Color(0.3, 0.7, 0.8, alpha * 0.5), 2)
		var step := 60.0 if rows.size() > 3 else 78.0
		for i in rows.size():
			var row := str(rows[i])
			if row.contains("\n"):
				var parts := row.split("\n")
				text(parts[0], Vector2(830, 202 + i * 110), 664, 46, gold if i == 0 else white)
				text(parts[1], Vector2(830, 245 + i * 110), 664, 32, soft)
			else:
				text(row, Vector2(830, 202 + i * step), 664, 48, gold if i == 0 else white)
	text(data.footer, Vector2(42, 469), 1450, 34, soft)

func _draw() -> void:
	if current.is_empty(): return
	var spectacle: bool = current.state in ["SPRINT", "LAP_GAIN", "FINISH"] or current.moment == "final_lap"
	var accent := Color("f2c05e") if spectacle else Color("4ed6d9")
	for i in 8:
		draw_rect(Rect2(0, i * 64, W, 64), Color(0.018 + i * 0.002, 0.045 + i * 0.003, 0.09 + i * 0.005))
	for i in 13:
		var x := float(i) * 160.0 - (fmod(age * 165.0, 160.0) if spectacle and age < 8.0 else 0.0)
		draw_line(Vector2(x - 100, H), Vector2(x + 200, 0), Color(accent, 0.08 if spectacle else 0.025), 16)
	draw_rect(Rect2(0, 0, W, 6), accent)
	draw_rect(Rect2(0, H - 6, W, 6), accent)
	if spectacle and age < 1.2:
		var sweep := fmod(age * 1600, W + 200) - 200
		draw_rect(Rect2(sweep, 6, 120, H - 12), Color(accent, 0.18))
	if current.state == "FINISH" and current.badge == "WINNAAR" and age < 9.0:
		for i in 32:
			var x := fposmod(i * 113.0 + sin(age + i) * 25, W)
			var y := fposmod(i * 71.0 + age * (36 + i % 5 * 8), H)
			draw_rect(Rect2(x, y, 8, 4), Color(accent if i % 2 else Color.WHITE, 0.65))
	var blend := fade * fade * (3.0 - 2.0 * fade)
	if fade < 1.0: layer(previous, 1.0 - blend)
	layer(current, blend)
