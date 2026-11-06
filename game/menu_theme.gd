extends RefCounted
## Shared menu/HUD palette. National-kit colours remain independent.
const INK := Color("122c50")
const MUTED := Color("536980")
const BLUE := Color("164e98")
const IVORY := Color("f5f1e7")
const PAPER := Color("fffdf8")
const PALE := Color("e0edf5")
const LINE := Color("d2d9df")
const WOOD := Color("bc8a43")
const GOLD := Color("f8e9c7")
static var cached: Theme

static func panel(fill: Color = IVORY, outline: Color = Color.TRANSPARENT, padding: int = 18, radius: int = 12) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = fill
	skin.border_color = outline
	skin.set_border_width_all(1 if outline.a > 0 else 0)
	skin.set_corner_radius_all(radius)
	skin.set_content_margin_all(padding)
	return skin

static func focus_ring(radius: int = 9) -> StyleBox:
	return preload("res://menu_focus_style.gd").new(radius)

static func toggle_focus(button: BaseButton) -> void:
	button.add_theme_stylebox_override("focus", focus_ring())

static func heading() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Liberation Sans", "DejaVu Sans"])
	font.font_weight = 700
	font.font_italic = true
	return font

static func icon(mark: String, colour: Color = INK) -> ImageTexture:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [colour.to_html(false), mark]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

static func create() -> Theme:
	if cached != null: return cached
	cached = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Liberation Sans", "DejaVu Sans"])
	cached.default_font = font
	cached.default_font_size = 20
	for kind in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "PopupMenu", "TabContainer", "TabBar", "TextEdit", "AcceptDialog"]:
		for name in ["font_color", "font_hover_color", "font_focus_color", "font_uneditable_color", "font_unselected_color"]:
			cached.set_color(name, kind, INK)
		cached.set_color("font_disabled_color", kind, MUTED)
		cached.set_color("font_pressed_color", kind, Color.WHITE)
		cached.set_color("font_selected_color", kind, Color.WHITE)
		cached.set_color("font_outline_color", kind, Color.TRANSPARENT)
	for kind in ["Button", "OptionButton"]:
		cached.set_stylebox("normal", kind, panel(PAPER, LINE, 12, 9))
		cached.set_stylebox("hover", kind, panel(PALE, BLUE, 12, 9))
		cached.set_stylebox("pressed", kind, panel(BLUE, BLUE, 12, 9))
		cached.set_stylebox("disabled", kind, panel(IVORY, LINE, 12, 9))
		cached.set_stylebox("focus", kind, focus_ring())
		cached.set_constant("outline_size", kind, 0)
	cached.set_icon("arrow", "OptionButton", icon('<path d="m7 10 5 5 5-5"/>', Color.WHITE))
	cached.set_constant("modulate_arrow", "OptionButton", 1)
	cached.set_icon("updown", "SpinBox", icon('<path d="m8 8 4-4 4 4M8 16l4 4 4-4"/>'))
	for state in ["up", "up_hover", "up_pressed", "up_disabled"]:
		cached.set_icon(state, "SpinBox", icon('<path d="m7 15 5-5 5 5"/>'))
	for state in ["down", "down_hover", "down_pressed", "down_disabled"]:
		cached.set_icon(state, "SpinBox", icon('<path d="m7 9 5 5 5-5"/>'))
	for kind in ["LineEdit", "TextEdit"]:
		cached.set_stylebox("normal", kind, panel(PAPER, LINE, 10, 8))
		cached.set_stylebox("read_only", kind, panel(PALE, LINE, 10, 8))
		cached.set_stylebox("focus", kind, focus_ring(8))
		cached.set_color("caret_color", kind, BLUE)
		cached.set_color("selection_color", kind, BLUE)
		cached.set_color("font_placeholder_color", kind, MUTED)
	for kind in ["CheckBox", "CheckButton"]:
		cached.set_stylebox("focus", kind, focus_ring())
		cached.set_color("font_pressed_color", kind, INK)
		cached.set_icon("checked", kind, icon('<rect x="3" y="3" width="18" height="18" rx="4"/><path d="m7 12 3 3 7-7"/>', BLUE))
		cached.set_icon("unchecked", kind, icon('<rect x="3" y="3" width="18" height="18" rx="4"/>', MUTED))
		cached.set_stylebox("normal", kind, panel(Color.TRANSPARENT, Color.TRANSPARENT, 8))
		cached.set_stylebox("pressed", kind, panel(PALE, Color.TRANSPARENT, 8))
	for kind in ["PopupMenu", "AcceptDialog", "Window", "PanelContainer", "TooltipPanel"]:
		cached.set_stylebox("panel", kind, panel(PAPER, LINE))
	cached.set_color("font_color", "TooltipLabel", INK)
	cached.set_stylebox("hover", "PopupMenu", panel(PALE, Color.TRANSPARENT, 6))
	cached.set_color("font_hover_color", "PopupMenu", INK)
	cached.set_stylebox("panel", "TabContainer", panel(PAPER, LINE, 18))
	for kind in ["TabContainer", "TabBar"]:
		cached.set_stylebox("tab_focus", kind, focus_ring(8))
		cached.set_color("font_hovered_color", kind, INK)
		cached.set_stylebox("tab_selected", kind, panel(BLUE, BLUE, 14, 8))
		cached.set_stylebox("tab_unselected", kind, panel(IVORY, LINE, 14, 8))
		cached.set_stylebox("tab_hovered", kind, panel(PALE, BLUE, 14, 8))
		cached.set_color("font_selected_color", kind, Color.WHITE)
	for kind in ["HSlider", "VSlider"]:
		cached.set_stylebox("slider", kind, panel(LINE, Color.TRANSPARENT, 3, 4))
		cached.set_stylebox("grabber_area", kind, panel(BLUE, Color.TRANSPARENT, 3, 4))
		cached.set_stylebox("grabber_area_highlight", kind, panel(BLUE, Color.TRANSPARENT, 3, 4))
		var knob := icon('<circle cx="12" cy="12" r="8" fill="#164e98" stroke="#fffdf8"/>', BLUE)
		cached.set_icon("grabber", kind, knob)
		cached.set_icon("grabber_highlight", kind, knob)
	for kind in ["VScrollBar", "HScrollBar"]:
		cached.set_stylebox("scroll", kind, panel(IVORY, Color.TRANSPARENT, 3, 4))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			cached.set_stylebox(state, kind, panel(MUTED, Color.TRANSPARENT, 4, 4))
	cached.set_stylebox("separator", "HSeparator", panel(LINE, Color.TRANSPARENT, 1, 0))
	return cached

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("focus", focus_ring(10))
	for state in ["normal", "pressed", "hover"]:
		button.add_theme_stylebox_override(state, panel(BLUE.lightened(.10) if state == "hover" else BLUE, Color.TRANSPARENT, 14, 10))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_stylebox_override("disabled", panel(LINE, Color.TRANSPARENT, 14, 10))
	button.add_theme_color_override("font_disabled_color", MUTED)

static func logo() -> TextureRect:
	var image: Texture2D = preload("res://assets/branding/velodrome_wordmark.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = image
	# This source includes transparent export padding; frame the actual wordmark.
	atlas.region = Rect2(28, 142, 2138, 414)
	var node := TextureRect.new()
	node.texture = atlas
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(600, 112)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
