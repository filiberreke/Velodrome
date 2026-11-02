extends CanvasLayer
## Shared application exit and race pause controls, above every menu overlay.
const MenuStyle := preload("res://menu_theme.gd")
var game
var exit_button: Button
var backdrop: ColorRect
var heading: Label
var detail: Label
var resume_button: Button
var leave_button: Button
var confirming_leave := false

func setup(owner_game: Node) -> void:
	game = owner_game
	layer = 100
	var screen := Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = MenuStyle.create()
	exit_button = Button.new()
	screen.add_child(exit_button)
	exit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit_button.offset_left = -60
	exit_button.offset_right = -8
	exit_button.offset_top = 48
	exit_button.offset_bottom = 100
	exit_button.icon = MenuStyle.icon('<path d="M10 4H4v16h6M14 8l4 4-4 4M8 12h10"/>')
	exit_button.tooltip_text = "Spel afsluiten"
	exit_button.pressed.connect(game._quit_application)
	backdrop = ColorRect.new()
	screen.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.05, 0.10, 0.78)
	var center := CenterContainer.new()
	backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.IVORY, MenuStyle.LINE, 32))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	resume_button = Button.new()
	resume_button.custom_minimum_size.y = 60
	resume_button.pressed.connect(cancel_or_resume)
	box.add_child(resume_button)
	leave_button = Button.new()
	leave_button.custom_minimum_size.y = 60
	leave_button.pressed.connect(_leave_pressed)
	box.add_child(leave_button)
	hide_pause()

func set_exit_visible(value: bool) -> void:
	exit_button.visible = value and not backdrop.visible

func show_pause() -> void:
	confirming_leave = false
	heading.text = "Wedstrijd gepauzeerd"
	detail.text = "Wat wil je doen?"
	resume_button.text = "Wedstrijd hervatten"
	leave_button.text = "Wedstrijd verlaten"
	backdrop.show()
	exit_button.hide()
	resume_button.grab_focus()

func hide_pause() -> void:
	backdrop.hide()
	confirming_leave = false
	resume_button.release_focus()
	leave_button.release_focus()

func cancel_or_resume() -> void:
	if confirming_leave: show_pause()
	else: game._resume_race()

func _leave_pressed() -> void:
	if confirming_leave:
		game._reset()
		return
	confirming_leave = true
	heading.text = "Wedstrijd verlaten?"
	detail.text = "Je kunt deze wedstrijd daarna niet hervatten."
	resume_button.text = "Terug"
	leave_button.text = "Verlaten naar hoofdmenu"
	resume_button.grab_focus()
