extends CanvasLayer
const MenuStyle := preload("res://menu_theme.gd")
# Local display preferences; no trainer or gameplay dependencies.
const OPTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SETTINGS_PATH := "user://config/display_settings.cfg"
var resolution := Vector2i(1920, 1080)
var render_scale := 0.85
var fullscreen := true
var crowd_density := 0.60
var simple_infield := false
var simple_infield_check: CheckButton
var always_show_intro := false
var intro_check: CheckButton
var crowd_slider: HSlider
var crowd_label: Label
var panel_root: Control
var close_button: Button
var open_button: Button
var resolution_choice: OptionButton
var scale_slider: HSlider
var scale_label: Label
var fullscreen_check: CheckButton
var rider_name_input: LineEdit
var rider_weight_input: SpinBox
var rider_ftp_input: SpinBox
const Appearance = preload("res://player_appearance.gd")
var appearance
var keyboard_settings: Control
var controller_test: Control
var appearance_tabs: TabContainer
var ride_tabs: Button
var return_to_devices := false
var return_focus: Control
var suit_choice: OptionButton
var helmet_choice: OptionButton
var visor_choice: OptionButton
var appearance_preview
var appearance_status: Label
const RIDER_PATH := "user://config/rider_profile.cfg"

func _ready() -> void:
	layer = 110
	appearance = get_parent().get("player_appearance")
	_load_settings()
	_load_rider_profile()
	_apply_display()
	_build_menu()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if preload("res://config_paths.gd").load_user(cfg, "display_settings.cfg") != OK:
		return
	var w := int(cfg.get_value("display", "width", 1920))
	var h := int(cfg.get_value("display", "height", 1080))
	var candidate := Vector2i(w, h)
	if OPTIONS.has(candidate):
		resolution = candidate
	render_scale = clampf(float(cfg.get_value("display", "render_scale", 0.85)), 0.5, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	crowd_density = clampf(float(cfg.get_value("arena", "crowd_density", 0.60)), 0.0, 1.0)
	simple_infield = bool(cfg.get_value("arena", "simple_infield", false))
	always_show_intro = bool(cfg.get_value("presentation", "always_show_intro", false))

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
	cfg.set_value("arena", "simple_infield", simple_infield)
	cfg.set_value("presentation", "always_show_intro", always_show_intro)
	var err := cfg.save(preload("res://config_paths.gd").user_path("display_settings.cfg"))
	if err != OK:
		push_warning("Beeldinstellingen niet opgeslagen: %d" % err)

func _load_rider_profile() -> void:
	var cfg := ConfigFile.new()
	if preload("res://config_paths.gd").load_user(cfg, "rider_profile.cfg") != OK:
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
	preload("res://config_paths.gd").load_user(cfg,"rider_profile.cfg")
	if rider_ftp_input != null: cfg.set_value("rider","ftp_w",roundi(rider_ftp_input.value))
	cfg.set_value("rider", "name", get_parent().get("player_display_name"))
	cfg.set_value("rider", "weight_kg", get_parent().get("player_weight_kg"))
	cfg.save(preload("res://config_paths.gd").user_path("rider_profile.cfg"))

func _build_menu() -> void:
	var toolbar := Control.new()
	toolbar.theme = MenuStyle.create()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toolbar)
	open_button = Button.new()
	open_button.text = "Instellingen  ·  F10"
	open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_button.offset_left = -295
	open_button.offset_right = -64
	open_button.offset_top = 48
	open_button.offset_bottom = 100
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.pressed.connect(toggle_menu)
	toolbar.add_child(open_button)

	panel_root = ColorRect.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.theme = MenuStyle.create()
	panel_root.color = Color(0.07, 0.16, 0.27, 0.46)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.visible = false
	add_child(panel_root)
	var centered := CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(centered)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1160, 900)
	var style := StyleBoxFlat.new()
	style.bg_color = MenuStyle.IVORY
	style.border_color = MenuStyle.BLUE
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	centered.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "Instellingen"
	title.add_theme_font_override("font", MenuStyle.heading())
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", MenuStyle.INK)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	outer.add_child(header)
	header.add_child(title)
	appearance_tabs = TabContainer.new()
	appearance_tabs.custom_minimum_size = Vector2(0, 620)
	appearance_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(appearance_tabs)
	ride_tabs = Button.new()
	ride_tabs.flat = true
	ride_tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ride_tabs.add_theme_font_size_override("font_size", 17)
	ride_tabs.add_theme_color_override("font_color", MenuStyle.MUTED)
	ride_tabs.text = "Tab kiezen: links / rechts  ·  omlaag: opties  ·  B/Z: sluiten"
	outer.move_child(appearance_tabs, outer.get_child_count() - 1)
	outer.add_child(ride_tabs)
	outer.move_child(ride_tabs, appearance_tabs.get_index())
	var player_tab := HBoxContainer.new()
	player_tab.name = "Speler"
	player_tab.add_theme_constant_override("separation", 28)
	appearance_tabs.add_child(player_tab)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 420
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	player_tab.add_child(box)
	var player_heading := Label.new()
	player_heading.text = "RENNE R  /  SPELERSPROFIEL".replace("RENNE R", "RENNER")
	player_heading.add_theme_color_override("font_color", MenuStyle.BLUE)
	box.add_child(player_heading)
	var name_label := Label.new()
	name_label.text = "Naam van speler"
	box.add_child(name_label)
	rider_name_input = LineEdit.new()
	rider_name_input.text = str(get_parent().get("player_display_name"))
	rider_name_input.max_length = 22
	box.add_child(rider_name_input)
	var weight_label := Label.new()
	weight_label.text = "Gewicht renner (kg)"
	weight_label.tooltip_text = "Profielinstelling; verandert de racefysica niet."
	box.add_child(weight_label)
	rider_weight_input = SpinBox.new()
	rider_weight_input.min_value = 35
	rider_weight_input.max_value = 180
	rider_weight_input.step = 0.5
	rider_weight_input.value = float(get_parent().get("player_weight_kg"))
	box.add_child(rider_weight_input)
	var ftp_label := Label.new()
	ftp_label.text = "FTP (W)"
	box.add_child(ftp_label)
	rider_ftp_input = SpinBox.new()
	rider_ftp_input.min_value = 20
	rider_ftp_input.max_value = 1000
	rider_ftp_input.step = 1
	rider_ftp_input.value = preload("res://player_profile.gd").new().ftp()
	box.add_child(rider_ftp_input)
	_build_appearance_controls(box, player_tab)
	box = VBoxContainer.new()
	box.name = "Beeld"
	box.add_theme_constant_override("separation", 10)
	appearance_tabs.add_child(box)
	var display_heading := Label.new()
	display_heading.text = "BEELDINSTELLINGEN"
	display_heading.add_theme_color_override("font_color", MenuStyle.BLUE)
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
	simple_infield_check = CheckButton.new()
	simple_infield_check.name = "EenvoudigMiddenplein"
	simple_infield_check.text = "Eenvoudige graphics (na herstart)"
	simple_infield_check.button_pressed = simple_infield
	simple_infield_check.tooltip_text = "Eenvoudig publiek op de tribunes, eenvoudige tenten en supporters op het middenplein. Zonder mediazone of commentaarcabine. Intro van 2,5 seconden bij de renners. Rennersboxen, jury en wedstrijdcommissaris blijven behouden."
	box.add_child(simple_infield_check)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Volledig scherm"
	fullscreen_check.button_pressed = fullscreen
	box.add_child(fullscreen_check)
	intro_check = CheckButton.new()
	intro_check.text = "Intro bij elke wedstrijd tonen"
	intro_check.button_pressed = always_show_intro
	intro_check.tooltip_text = "Uit: alleen bij de eerste wedstrijd van deze sessie. Aan: bij elke wedstrijd."
	box.add_child(intro_check)
	var intro_hint := Label.new()
	intro_hint.text = "Uit: alleen de eerste wedstrijd van de sessie. Aan: elke wedstrijd."
	intro_hint.add_theme_color_override("font_color", MenuStyle.MUTED)
	box.add_child(intro_hint)
	var info := Label.new()
	info.text = "Een lagere 3D-resolutie verbetert de prestaties.\nMenu’s en uitslagen blijven scherp.\nStel je sneltoetsen in op het tabblad Toetsenbord."
	info.add_theme_color_override("font_color", MenuStyle.MUTED)
	box.add_child(info)
	box = VBoxContainer.new()
	box.name = "Strava"
	box.add_theme_constant_override("separation", 18)
	appearance_tabs.add_child(box)
	var account_heading := Label.new()
	account_heading.text = "STRAVA"
	account_heading.add_theme_color_override("font_color", MenuStyle.BLUE)
	box.add_child(account_heading)
	var account_status := Label.new()
	var client = get_parent().get("strava_client")
	var has_account := false
	if client != null:
		has_account = not str(client.tokens.get_value("tokens", "refresh_token", "")).is_empty() or not str(client.config.get_value("strava", "refresh_token", "")).is_empty()
	account_status.text = "Account gekoppeld" if has_account else "Nog geen account gekoppeld"
	account_status.add_theme_font_size_override("font_size", 26)
	box.add_child(account_status)
	var account_help := Label.new()
	account_help.text = "1. Kopieer config/strava_config.example.cfg naar config/strava_config.cfg.\n2. Vul client_id en client_secret in via strava.com/settings/api.\n3. Gebruik redirect_uri = http://localhost en callbackdomein localhost.\n4. Kies hieronder Koppel je Strava-account en geef toestemming.\n5. Upload na een wedstrijd of pistetraining je activiteit naar Strava.\n\nJe trainingen en resultaten blijven ook lokaal beschikbaar."
	account_help.add_theme_font_size_override("font_size", 19)
	account_help.add_theme_color_override("font_color", MenuStyle.MUTED)
	box.add_child(account_help)
	var reconnect_button := Button.new()
	reconnect_button.text = "Strava opnieuw koppelen" if has_account else "Koppel je Strava-account"
	reconnect_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MenuStyle.primary(reconnect_button)
	reconnect_button.pressed.connect(func(): get_parent().get("strava_client").call("reconnect"))
	box.add_child(reconnect_button)
	controller_test = preload("res://controller_settings.gd").new()
	controller_test.name = "Besturing"
	appearance_tabs.add_child(controller_test)
	keyboard_settings = preload("res://keyboard_settings.gd").new()
	keyboard_settings.name = "Toetsenbord"
	appearance_tabs.add_child(keyboard_settings)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	outer.add_child(actions)
	var apply_button := Button.new()
	apply_button.text = "Toepassen en bewaren"
	MenuStyle.primary(apply_button)
	apply_button.custom_minimum_size = Vector2(310, 52)
	apply_button.pressed.connect(_on_apply)
	actions.add_child(apply_button)
	close_button = Button.new()
	close_button.text = "Sluiten"
	close_button.pressed.connect(_close_settings)
	actions.add_child(close_button)
	close_button.reparent(header)
	header.move_child(close_button, 0)
	close_button.text = "← Terug"
	close_button.custom_minimum_size = Vector2(210, 48)
	MenuStyle.primary(close_button)
	appearance_tabs.tab_changed.connect(_on_settings_tab_changed)

func _build_appearance_controls(box: VBoxContainer, player_tab: HBoxContainer) -> void:
	for entry in [["Truitje / wielerpak", appearance.suit_options], ["Helm", appearance.helmet_options]]:
		var label := Label.new()
		label.text = entry[0]
		box.add_child(label)
		var choice := OptionButton.new()
		for option in entry[1]:
			choice.add_item(option.label)
			choice.set_item_metadata(choice.item_count - 1, option.id)
		box.add_child(choice)
		choice.item_selected.connect(_on_appearance_draft)
		if suit_choice == null: suit_choice = choice
		else: helmet_choice = choice
	var visor_label := Label.new()
	visor_label.text = "Vizier"
	box.add_child(visor_label)
	visor_choice = OptionButton.new()
	for id in ["donker", "doorzichtig"]:
		visor_choice.add_item(id.capitalize())
		visor_choice.set_item_metadata(visor_choice.item_count - 1, id)
	visor_choice.item_selected.connect(_on_appearance_draft)
	box.add_child(visor_choice)
	var hint := Label.new()
	hint.text = "Het wielerpak omvat ook de broek.\nJe keuze geldt alleen voor jouw renner.\nBewaar om je keuze in de wedstrijd te gebruiken."
	hint.add_theme_color_override("font_color", MenuStyle.MUTED)
	box.add_child(hint)
	appearance_status = Label.new()
	appearance_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	appearance_status.add_theme_color_override("font_color", MenuStyle.WOOD)
	box.add_child(appearance_status)
	var preview_box := VBoxContainer.new()
	player_tab.add_child(preview_box)
	var heading := Label.new()
	heading.text = "JOUW RENNER"
	preview_box.add_child(heading)
	appearance_preview = preload("res://player_appearance_preview.gd").new()
	appearance_preview.custom_minimum_size = Vector2(400, 480)
	preview_box.add_child(appearance_preview)
	var views := HBoxContainer.new()
	preview_box.add_child(views)
	var group := ButtonGroup.new()
	for back in [false, true]:
		var button := Button.new()
		button.text = "Achterkant" if back else "Voorkant"
		button.toggle_mode = true
		MenuStyle.toggle_focus(button)
		button.button_group = group
		button.button_pressed = not back
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(appearance_preview.set_back_view.bind(back))
		views.add_child(button)

func _choice_id(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else "configured"

func _select_id(choice: OptionButton, id: String) -> void:
	for i in choice.item_count:
		if str(choice.get_item_metadata(i)) == id:
			choice.select(i)
			return
	choice.select(0)

func _sync_appearance_controls() -> void:
	rider_ftp_input.value = preload("res://player_profile.gd").new().ftp()
	rider_name_input.text = str(get_parent().get("player_display_name"))
	rider_weight_input.value = float(get_parent().get("player_weight_kg"))
	_select_id(suit_choice, appearance.suit_id)
	_select_id(helmet_choice, appearance.helmet_id)
	var selected_visor: String = appearance.visor_id
	if selected_visor == "configured":
		var base: Dictionary = get_parent().call("get_player_appearance_base")
		selected_visor = str(base.get("visor", "donker")).strip_edges().to_lower()
	_select_id(visor_choice, selected_visor)
	appearance_status.text = ""
	_update_appearance_preview()

func _update_appearance_preview() -> void:
	var base: Dictionary = get_parent().call("get_player_appearance_base")
	appearance_preview.show_configuration(appearance.resolve(base, _choice_id(suit_choice), _choice_id(helmet_choice), _choice_id(visor_choice)))

func _on_appearance_draft(_index: int) -> void:
	_update_appearance_preview()

func _on_settings_tab_changed(index: int) -> void:
	get_parent().call("_clear_look_back")
	appearance_preview.set_active(panel_root.visible and index == 0)
	if controller_test != null:
		controller_test.call("set_testing", controller_test_active())

func controller_test_active() -> bool:
	return panel_root != null and panel_root.visible and controller_test != null and appearance_tabs.current_tab == controller_test.get_index()

func receive_controller_packet(packet: Dictionary) -> void:
	if controller_test != null:
		controller_test.call("receive_packet", packet)

func open_device_mapping() -> void:
	if not panel_root.visible: toggle_menu()
	return_to_devices = true
	close_button.text = "Terug naar apparaten"
	keyboard_settings.context_choice.select(get_parent().keyboard_mapping.CONTEXTS.find(get_parent()._keyboard_profile()))
	keyboard_settings.refresh()
	appearance_tabs.current_tab = keyboard_settings.get_index()
	_on_settings_tab_changed(appearance_tabs.current_tab)
	keyboard_settings.context_choice.grab_focus()

func _close_settings() -> void:
	keyboard_settings.cancel_capture()
	panel_root.hide()
	close_button.text = "← Terug"
	appearance_preview.set_active(false)
	if controller_test != null:
		controller_test.call("set_testing", false)
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()
	get_parent().call("_clear_look_back")
	if return_to_devices:
		return_to_devices = false
		get_parent().bridge_devices.open_page()

func _on_apply() -> void:
	var error: Error = appearance.save_choices(_choice_id(suit_choice), _choice_id(helmet_choice), _choice_id(visor_choice))
	if error != OK:
		appearance_tabs.current_tab = 0
		appearance_status.text = "Je keuze kon niet worden bewaard. Probeer opnieuw."
		return
	resolution = OPTIONS[resolution_choice.selected]
	render_scale = float(scale_slider.value)
	fullscreen = fullscreen_check.button_pressed
	always_show_intro = intro_check.button_pressed
	crowd_density = float(crowd_slider.value)
	simple_infield = simple_infield_check.button_pressed
	_apply_display()
	_save_settings()
	_save_rider_profile()
	get_parent().call("apply_player_appearance")
	_close_settings()

func toggle_menu() -> void:
	if panel_root.visible:
		_close_settings()
	else:
		return_focus = get_viewport().gui_get_focus_owner()
		get_parent().call("_clear_look_back")
		if get_parent().get("start_state") not in ["SETUP", "INTRO"] and not get_parent().get("finished"):
			get_parent().call("_pause_race")
		_sync_appearance_controls()
		intro_check.button_pressed = always_show_intro
		panel_root.show()
		_on_settings_tab_changed(appearance_tabs.current_tab)
		ride_tabs.grab_focus()

func bridge_action(button: String, from_keyboard: bool = false) -> void:
	if controller_test_active() and not from_keyboard:
		if button in ["B", "Z"] and return_to_devices:
			_close_settings()
			return
		if button == "Z":
			appearance_tabs.current_tab = 0
			ride_tabs.grab_focus()
		return
	if button in ["B", "Z"]:
		_close_settings()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == ride_tabs or focused is TabBar:
		if button in ["LEFT", "RIGHT"]:
			appearance_tabs.current_tab = posmod(appearance_tabs.current_tab + (-1 if button == "LEFT" else 1), appearance_tabs.get_tab_count())
			ride_tabs.grab_focus()
			return
	# A controller test can only be left through Z, so no gameplay input escapes.
	get_parent().ride_navigation.navigate(panel_root, button, ride_tabs, true)

func _process(_delta: float) -> void:
	open_button.text = "Instellingen: " + get_parent().keyboard_mapping.caption("global", "settings")
	ride_tabs.text = "Tab: links/rechts · Controller: B/Z sluiten · Toetsenbord: " + get_parent().keyboard_mapping.caption("menu","back") + " sluiten"
	if open_button != null:
		open_button.visible = not panel_root.visible and (get_parent().get("bridge_devices") == null or not get_parent().bridge_devices.panel_root.visible)
