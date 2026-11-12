extends HBoxContainer
## Vector flames avoid platform-dependent emoji glyphs.
const Style := preload("res://menu_theme.gd")
const Library := preload("res://workout_library.gd")
const LABELS := ["Vrij rijden", "Zeer rustig", "Rustig", "Gemiddeld", "Zwaar", "Zeer zwaar"]
const FLAME := '<path d="M13 2c1 5-3 5-2 9-2-1-3-3-3-3C3 13 4 21 12 22c8-1 9-10 4-14 0 3-2 4-2 4 1-4-1-6-1-10Z" fill="#%s"/>'

func configure(target: float) -> void:
	var level := Library.intensity_level(target)
	add_theme_constant_override("separation", 5)
	for i in range(5):
		var flame := TextureRect.new()
		var colour: Color = Style.WOOD if i < level else Style.LINE
		flame.texture = Style.icon(FLAME % colour.to_html(false), colour)
		flame.custom_minimum_size = Vector2(20, 24)
		flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flame)
	var caption := Label.new()
	caption.text = "  " + LABELS[level]
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Style.MUTED)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Vrij rijden heeft geen vast doelvermogen." if level == 0 else "%d van 5 · gemiddeld doelvermogen %d%% FTP" % [level, roundi(target * 100)]

static func filter_icon(level: int) -> ImageTexture:
	var marks := ""
	for i in range(5):
		var colour: Color = Style.WOOD if i < level else Style.LINE
		marks += '<g transform="translate(%d 0)" stroke="#%s" stroke-width="1.2">%s</g>' % [i * 20, colour.to_html(false), FLAME % colour.to_html(false)]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="104" height="24" viewBox="0 0 104 24">%s</svg>' % marks
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)
