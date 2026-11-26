extends VBoxContainer
## Shared mouse/keyboard stadium picker for race and omnium settings.
signal selected(venue_id: String)
const Catalog := preload("res://venues/venue_catalog.gd")
const Style := preload("res://menu_theme.gd")
const PHOTOS := {"velodrome": preload("res://assets/venues/velodrome-overview.jpg"), "gent": preload("res://assets/venues/gent-overview.jpg")}
const SATURATION := "shader_type canvas_item; uniform float saturation = 1.0; void fragment() { vec4 p = texture(TEXTURE, UV); float gray = dot(p.rgb, vec3(0.2126, 0.7152, 0.0722)); COLOR = vec4(mix(vec3(gray), p.rgb, saturation), p.a); }"
var tile_size := Vector2(252, 174)
var selected_id := Catalog.DEFAULT_ID
var locked := false
var tiles := {}

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", 10)
	var heading := Label.new()
	heading.text = "MENU_RACE_VENUE"
	heading.add_theme_font_size_override("font_size", 22)
	add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var group := ButtonGroup.new()
	for id in Catalog.available_ids():
		var tile := Button.new()
		tile.name = "Venue_" + id
		tile.custom_minimum_size = tile_size
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.toggle_mode = true; tile.button_group = group
		tile.disabled = locked
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(tile)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8; content.offset_top = 8; content.offset_right = -8; content.offset_bottom = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(content)
		var photo := TextureRect.new()
		photo.texture = PHOTOS[id]
		photo.custom_minimum_size.y = tile_size.y - 48
		photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new(); shader.code = SATURATION
		var material := ShaderMaterial.new(); material.shader = shader
		photo.material = material
		content.add_child(photo)
		var title := Label.new()
		title.text = Catalog.find(id).display_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 23)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(title)
		tiles[id] = {"button": tile, "photo": photo, "title": title}
		tile.pressed.connect(select.bind(id))
	select(selected_id, false)

func select(id: String, emit_change: bool = true) -> void:
	if locked and emit_change: return
	selected_id = Catalog.resolved(id).id
	for key in tiles:
		var active: bool = key == selected_id
		var tile: Dictionary = tiles[key]
		tile.button.set_pressed_no_signal(active)
		tile.button.set_meta("venue_selected", active)
		tile.photo.material.set_shader_parameter("saturation", 1.0 if active else 0.0)
		tile.title.add_theme_color_override("font_color", Style.INK if active else Color("727272"))
		var panel := Style.panel(Style.PALE if active else Color("e4e4e4"), Style.BLUE if active else Color("a4a4a4"), 10, 8)
		panel.set_border_width_all(3 if active else 1)
		for state in ["normal", "hover", "pressed"]: tile.button.add_theme_stylebox_override(state, panel)
		tile.button.add_theme_stylebox_override("focus", Style.focus_ring(10))
	if emit_change: selected.emit(selected_id)
