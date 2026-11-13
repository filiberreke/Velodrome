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

# Build explicit links from the rendered layout, never from scene-tree order.
# The back buttons and training controls are reparented when a page is built.
static func controls(scope: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in scope.get_children():
		if child is Window or child is Viewport: continue
		if child is Control and not child.is_visible_in_tree(): continue
		if child is ScrollContainer or child is ScrollBar:
			child.focus_mode = Control.FOCUS_NONE
		if child is ScrollContainer: child.follow_focus = true
		if child is SpinBox:
			if child.editable: result.append(child.get_line_edit())
			continue
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			if not (child is BaseButton and child.disabled): result.append(child)
		result.append_array(controls(child))
	return result

func active_scope() -> Control:
	var game := get_parent()
	if is_instance_valid(keyboard): return keyboard
	match game._ride_context():
		"settings": return game.get_node("GameSettings").panel_root
		"devices": return game.bridge_devices.panel_root
		"pause": return game.exit_menu.backdrop
		"setup": return game.setup_panel
		"results": return game.finish_overlay
	return null

static func layout_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			rect.position += Vector2(parent.scroll_horizontal, parent.scroll_vertical)
		parent = parent.get_parent()
	return rect

func refresh_focus(scope: Control = null) -> void:
	if scope == null: scope = active_scope()
	if scope == null: return
	var items := controls(scope)
	# Group controls by their top edge, then read each row from left to right.
	items.sort_custom(func(a: Control, b: Control):
		var ar := layout_rect(a); var br := layout_rect(b)
		if not is_equal_approx(ar.position.y, br.position.y): return ar.position.y < br.position.y
		return ar.position.x < br.position.x)
	var ordered: Array[Control] = []
	while not items.is_empty():
		var row: Array[Control] = [items.pop_front()]
		var top := layout_rect(row[0]).position.y
		while not items.is_empty() and layout_rect(items[0]).position.y - top < 20:
			row.append(items.pop_front())
		row.sort_custom(func(a: Control, b: Control): return layout_rect(a).position.x < layout_rect(b).position.x)
		ordered.append_array(row)
	for i in range(ordered.size()):
		var item := ordered[i]
		item.focus_previous = item.get_path_to(ordered[posmod(i - 1, ordered.size())])
		item.focus_next = item.get_path_to(ordered[(i + 1) % ordered.size()])
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			item.set_focus_neighbor(side, item.get_path_to(neighbor(item, ordered, side)))

func neighbor(source: Control, items: Array[Control], side: int) -> Control:
	var rect := layout_rect(source)
	var center := rect.get_center()
	var horizontal := side in [SIDE_LEFT, SIDE_RIGHT]
	var forward := side in [SIDE_RIGHT, SIDE_BOTTOM]
	var best := source
	var best_score := INF
	for candidate in items:
		if candidate == source: continue
		var other := layout_rect(candidate)
		var delta := other.get_center() - center
		var along := delta.x if horizontal else delta.y
		if (along if forward else -along) <= 1: continue
		# Controls beside each other are never an up/down destination, even
		# when their heights (and therefore centres) differ.
		if not horizontal:
			if forward and other.position.y < rect.end.y - 1: continue
			if not forward and other.end.y > rect.position.y + 1: continue
		var gap := maxf(0, maxf(rect.position.y - other.end.y, other.position.y - rect.end.y)) if horizontal else maxf(0, maxf(rect.position.x - other.end.x, other.position.x - rect.end.x))
		# Left/right stays on the same row. Up/down can reach a header or footer.
		if horizontal and gap > 1: continue
		var score := absf(along) + absf(delta.y if horizontal else delta.x) * .05
		if gap > 1: score += 100000 + gap
		if score < best_score:
			best_score = score
			best = candidate
	return best

func navigate(scope: Control, button: String, fallback: Control, _linear: bool = false) -> void:
	refresh_focus(scope)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree() or not scope.is_ancestor_of(focused):
		fallback.grab_focus()
	if edit_control(button): return
	send(button)

func edit_control(button: String) -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null: return false
	var spin := focused.get_parent() as SpinBox
	if button in ["UP", "DOWN"] and (spin != null or focused is Range):
		var next := focused.find_valid_focus_neighbor(SIDE_TOP if button == "UP" else SIDE_BOTTOM)
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
	if is_instance_valid(keyboard) and event is InputEventKey and event.pressed and get_parent().keyboard_mapping.action_for("menu", event) == "back":
		close_keyboard(false)
		get_viewport().set_input_as_handled()
