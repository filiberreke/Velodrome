extends CanvasLayer
# Local display preferences; no trainer or gameplay dependencies.
const OPTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SETTINGS_PATH := "user://display_settings.cfg"
var resolution := Vector2i(1920, 1080)
var render_scale := 0.85
var fullscreen := true
var crowd_density := 0.60
var crowd_slider: HSlider
var crowd_label: Label
var panel_root: Control
var resolution_choice: OptionButton
var scale_slider: HSlider
var scale_label: Label
var fullscreen_check: CheckButton
var rider_name_input: LineEdit
var rider_weight_input: SpinBox
const RIDER_PATH := "user://rider_profile.cfg"

func _ready() -> void:
	layer = 25
	_load_settings()
	_load_rider_profile()
	_apply_display()
	_build_menu()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var w := int(cfg.get_value("display", "width", 1920))
	var h := int(cfg.get_value("display", "height", 1080))
	var candidate := Vector2i(w, h)
	if OPTIONS.has(candidate):
		resolution = candidate
	render_scale = clampf(float(cfg.get_value("display", "render_scale", 0.85)), 0.5, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	crowd_density = clampf(float(cfg.get_value("arena", "crowd_density", 0.60)), 0.0, 1.0)

func _apply_display() -> void:
	# Keep 2D UI at the reference viewport resolution while scaling 3D separately.
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_viewport().scaling_3d_scale = render_scale
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var pos := usable.position + (usable.size - resolution) / 2
		DisplayServer.window_set_position(pos)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "width", resolution.x)
	cfg.set_value("display", "height", resolution.y)
	cfg.set_value("display", "render_scale", render_scale)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("arena", "crowd_density", crowd_density)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Beeldinstellingen niet opgeslagen: %d" % err)

func _load_rider_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RIDER_PATH) != OK:
		return
	get_parent().set("player_display_name", str(cfg.get_value("rider", "name", "JIJ")).strip_edges())
	if str(get_parent().get("player_display_name")).is_empty():
		get_parent().set("player_display_name", "JIJ")
	get_parent().set("player_weight_kg", clampf(float(cfg.get_value("rider", "weight_kg", 75.0)), 35.0, 180.0))

func _save_rider_profile() -> void:
	var name_text := rider_name_input.text.strip_edges()
	get_parent().set("player_display_name", name_text if not name_text.is_empty() else "JIJ")
	get_parent().set("player_weight_kg", rider_weight_input.value)
	var cfg := ConfigFile.new()
	cfg.set_value("rider", "name", get_parent().get("player_display_name"))
	cfg.set_value("rider", "weight_kg", get_parent().get("player_weight_kg"))
	cfg.save(RIDER_PATH)

func _build_menu() -> void:
	var toolbar := Control.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toolbar)
	var open_button := Button.new()
	open_button.text = "INSTELLINGEN [F10]"
	open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_button.offset_left = -218
	open_button.offset_right = -16
	open_button.offset_top = 14
	open_button.offset_bottom = 54
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.pressed.connect(toggle_menu)
	toolbar.add_child(open_button)

	panel_root = ColorRect.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.color = Color(0.02, 0.05, 0.10, 0.88)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.visible = false
	add_child(panel_root)
	var centered := CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(centered)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10253c")
	style.border_color = Color("42d9ed")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	centered.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "INSTELLINGEN"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ffb44c"))
	box.add_child(title)
	var player_heading := Label.new()
	player_heading.text = "RENNE R  /  SPELERSPROFIEL".replace("RENNE R", "RENNER")
	player_heading.add_theme_color_override("font_color", Color("42d9ed"))
	box.add_child(player_heading)
	var name_label := Label.new()
	name_label.text = "Naam van speler"
	box.add_child(name_label)
	rider_name_input = LineEdit.new()
	rider_name_input.text = str(get_parent().get("player_display_name"))
	rider_name_input.max_length = 22
	box.add_child(rider_name_input)
	var weight_label := Label.new()
	weight_label.text = "Gewicht renner (kg) — voorlopig profiel, verandert nog niet de racefysica"
	box.add_child(weight_label)
	rider_weight_input = SpinBox.new()
	rider_weight_input.min_value = 35
	rider_weight_input.max_value = 180
	rider_weight_input.step = 0.5
	rider_weight_input.value = float(get_parent().get("player_weight_kg"))
	box.add_child(rider_weight_input)
	var display_heading := Label.new()
	display_heading.text = "BEELDINSTELLINGEN"
	display_heading.add_theme_color_override("font_color", Color("42d9ed"))
	box.add_child(display_heading)
	var res_label := Label.new()
	res_label.text = "Vensterresolutie (in volledig scherm geldt de schermresolutie)"
	box.add_child(res_label)
	resolution_choice = OptionButton.new()
	for r in OPTIONS:
		resolution_choice.add_item("%d x %d" % [r.x, r.y])
	resolution_choice.select(maxi(0, OPTIONS.find(resolution)))
	box.add_child(resolution_choice)
	var scale_header := HBoxContainer.new()
	box.add_child(scale_header)
	var label := Label.new()
	label.text = "Interne 3D-resolutie"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_header.add_child(label)
	scale_label = Label.new()
	scale_header.add_child(scale_label)
	scale_slider = HSlider.new()
	scale_slider.min_value = 0.5
	scale_slider.max_value = 1.0
	scale_slider.step = 0.05
	scale_slider.value = render_scale
	scale_slider.custom_minimum_size = Vector2(480, 25)
	scale_slider.value_changed.connect(func(v: float): scale_label.text = "%d%%" % roundi(v * 100.0))
	box.add_child(scale_slider)
	scale_label.text = "%d%%" % roundi(render_scale * 100.0)
	var crowd_header := HBoxContainer.new()
	box.add_child(crowd_header)
	var crowd_heading := Label.new()
	crowd_heading.text = "PUBLIEK OP DE TRIBUNES (na herstart)"
	crowd_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crowd_header.add_child(crowd_heading)
	crowd_label = Label.new()
	crowd_header.add_child(crowd_label)
	crowd_slider = HSlider.new()
	crowd_slider.min_value = 0.0
	crowd_slider.max_value = 1.0
	crowd_slider.step = 0.1
	crowd_slider.value = crowd_density
	crowd_slider.value_changed.connect(func(v: float): crowd_label.text = "%d%%" % roundi(v * 100.0))
	box.add_child(crowd_slider)
	crowd_label.text = "%d%%" % roundi(crowd_density * 100.0)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Volledig scherm"
	fullscreen_check.button_pressed = fullscreen
	box.add_child(fullscreen_check)
	var info := Label.new()
	info.text = "3D lager instellen kan helpen op een Intel GPU.\nDe uitslag en andere interface-elementen blijven scherp.\nDruk op F10 om dit menu te openen of sluiten."
	info.add_theme_color_override("font_color", Color("b4d4e9"))
	box.add_child(info)
	var account_heading := Label.new()
	account_heading.text = "STRAVA"
	account_heading.add_theme_color_override("font_color", Color("42d9ed"))
	box.add_child(account_heading)
	var reconnect_button := Button.new()
	reconnect_button.text = "STRAVA OPNIEUW KOPPELEN"
	reconnect_button.pressed.connect(func(): get_parent().get("strava_client").call("reconnect"))
	box.add_child(reconnect_button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var apply_button := Button.new()
	apply_button.text = "TOEPASSEN EN BEWAREN"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_on_apply)
	actions.add_child(apply_button)
	var close_button := Button.new()
	close_button.text = "SLUITEN"
	close_button.pressed.connect(toggle_menu)
	actions.add_child(close_button)

func _on_apply() -> void:
	resolution = OPTIONS[resolution_choice.selected]
	render_scale = float(scale_slider.value)
	fullscreen = fullscreen_check.button_pressed
	crowd_density = float(crowd_slider.value)
	_apply_display()
	_save_settings()
	_save_rider_profile()
	panel_root.hide()

func toggle_menu() -> void:
	panel_root.visible = not panel_root.visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		toggle_menu()
		get_viewport().set_input_as_handled()
