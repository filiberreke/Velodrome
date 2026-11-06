extends CanvasLayer
## Controller UI input stays inside the active overlay. No race key emulation.
const ACTIONS := {"LEFT":"ui_left", "RIGHT":"ui_right", "UP":"ui_up", "DOWN":"ui_down", "A":"ui_accept"}
var keyboard: PanelContainer
var target: LineEdit
var previous_focus: Control
var draft: LineEdit

func _ready() -> void:
	layer = 120

func send(button: String) -> void:
	if not ACTIONS.has(button): return
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = ACTIONS[button]
		event.pressed = down
		get_viewport().push_input(event)

func controls(scope: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in scope.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		if child is SpinBox:
			if child.editable: result.append(child.get_line_edit())
			continue
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			if not (child is BaseButton and child.disabled): result.append(child)
		result.append_array(controls(child))
	return result

func navigate(scope: Control, button: String, fallback: Control, linear: bool = false) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree() or not scope.is_ancestor_of(focused):
		fallback.grab_focus()
		focused = fallback
	if linear and button in ["UP", "DOWN"]:
		var items := controls(scope)
		if not items.is_empty():
			items[posmod(items.find(focused) + (-1 if button == "UP" else 1), items.size())].grab_focus()
		return
	if edit_control(button): return
	send(button)

func edit_control(button: String) -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null: return false
	var spin := focused.get_parent() as SpinBox
	if button in ["UP", "DOWN"] and (spin != null or focused is Range):
		var next := focused.find_prev_valid_focus() if button == "UP" else focused.find_next_valid_focus()
		if next != null: next.grab_focus()
		return true
	if button in ["LEFT", "RIGHT"] or (button == "A" and focused is OptionButton):
		var direction := -1 if button == "LEFT" else 1
		if spin != null:
			spin.value += direction * spin.step
			return true
		if focused is Range:
			focused.value += direction * focused.step
			return true
		if focused is OptionButton:
			var option := focused as OptionButton
			for offset in range(1, option.item_count + 1):
				var index := posmod(option.selected + direction * offset, option.item_count)
				if not option.is_item_disabled(index) and not option.get_popup().is_item_separator(index):
					option.select(index)
					option.item_selected.emit(index)
					break
			return true
	if button == "A" and focused is LineEdit and spin == null and focused.editable:
		open_keyboard(focused)
		return true
	return false

func open_keyboard(input: LineEdit) -> void:
	target = input
	previous_focus = input
	keyboard = PanelContainer.new()
	keyboard.theme = preload("res://menu_theme.gd").create()
	keyboard.position = Vector2(450, 310)
	keyboard.custom_minimum_size = Vector2(1020, 400)
	add_child(keyboard)
	var box := VBoxContainer.new()
	keyboard.add_child(box)
	draft = LineEdit.new()
	draft.text = input.text
	draft.editable = false
	draft.focus_mode = Control.FOCUS_NONE
	box.add_child(draft)
	var grid := GridContainer.new()
	grid.columns = 10
	box.add_child(grid)
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .-'":
		var key := Button.new()
		key.text = letter if letter != " " else "Spatie"
		key.custom_minimum_size = Vector2(96, 38)
		key.pressed.connect(func():
			if target.max_length == 0 or draft.text.length() < target.max_length: draft.text += letter)
		grid.add_child(key)
	for caption in ["Wissen", "Klaar", "Annuleren"]:
		var key := Button.new()
		key.text = caption
		key.pressed.connect(func():
			if caption == "Wissen": draft.text = draft.text.left(-1)
			else: close_keyboard(caption == "Klaar"))
		box.add_child(key)
	grid.get_child(0).grab_focus()

func keyboard_action(button: String) -> bool:
	if not is_instance_valid(keyboard): return false
	if button in ["B", "Z"]: close_keyboard(false)
	else: send(button)
	return true

func close_keyboard(accept: bool) -> void:
	if accept and is_instance_valid(target):
		target.text = draft.text
		target.text_changed.emit(target.text)
	keyboard.hide()
	keyboard.queue_free()
	keyboard = null
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if is_instance_valid(keyboard) and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_keyboard(false)
		get_viewport().set_input_as_handled()
