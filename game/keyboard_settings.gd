extends VBoxContainer
const Mapping := preload("res://keyboard_mapping.gd")
var game: Node
var active_profile: Label
var mapping: RefCounted
var context_choice: OptionButton
var status: Label
var rows: VBoxContainer
var enabled_check: CheckButton
var capture_action := ""
var capture_context := ""

func _ready() -> void:
	var owner_node: Node = get_parent()
	while owner_node != null:
		if owner_node.get("keyboard_mapping") != null:
			game = owner_node
			mapping = owner_node.get("keyboard_mapping")
			break
		owner_node = owner_node.get_parent()
	add_theme_constant_override("separation", 12)
	enabled_check = CheckButton.new()
	enabled_check.text = "KEYBOARD_SETTINGS_USE_KEYBOARD_CONTROLS_ALSO_WITHOUT_ZWIFT_RIDE"
	enabled_check.button_pressed = mapping.enabled
	enabled_check.toggled.connect(func(value):
		var before: bool = mapping.enabled
		mapping.enabled = value
		if mapping.save() != OK:
			mapping.enabled = before
			enabled_check.set_pressed_no_signal(before)
			status.text = "WORKOUT_LIBRARY_FAILED_TO_SAVE"
		game._clear_look_back())
	add_child(enabled_check)
	var help := Label.new()
	help.text = "KEYBOARD_USAGE"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	active_profile = Label.new()
	add_child(active_profile)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	context_choice = OptionButton.new()
	for caption in Mapping.CONTEXT_LABELS: context_choice.add_item(caption)
	context_choice.select(Mapping.CONTEXTS.find(game._keyboard_profile()))
	context_choice.item_selected.connect(func(_i): cancel_capture(); refresh())
	toolbar.add_child(context_choice)
	var reset := Button.new()
	reset.text = "KEYBOARD_SETTINGS_RESTORE_DEFAULT_KEYS"
	reset.pressed.connect(func():
		var before: Dictionary = mapping.profiles.duplicate(true)
		mapping.profiles = Mapping.DEFAULT_KEYS.duplicate(true)
		if mapping.save() != OK:
			mapping.profiles = before
			status.text = "WORKOUT_LIBRARY_FAILED_TO_SAVE"
		else: status.text = "KEYBOARD_SETTINGS_DEFAULT_KEYS_SAVED"
		cancel_capture()
		refresh())
	toolbar.add_child(reset)
	var cancel := Button.new()
	cancel.text = "WORKOUT_EDITOR_CANCEL"
	cancel.pressed.connect(cancel_capture)
	toolbar.add_child(cancel)
	status = Label.new()
	status.text = mapping.status
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 350
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_capture())
	refresh()

func context() -> String:
	return Mapping.CONTEXTS[context_choice.selected]

func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for action in Mapping.ACTIONS[context()]:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = Mapping.ACTIONS[context()][action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var key := Button.new()
		key.text = mapping.caption(context(), action)
		key.custom_minimum_size = Vector2(240, 42)
		key.pressed.connect(func():
			capture_context = context()
			capture_action = action
			status.text = String(TranslationServer.translate("KEYBOARD_SETTINGS_PRESS_A_KEY_FOR")) + TranslationServer.translate(Mapping.ACTIONS[capture_context][action]))
		row.add_child(key)
		var clear := Button.new()
		clear.text = "KEYBOARD_SETTINGS_UNASSIGN"
		clear.pressed.connect(func(): store(context(), action, 0))
		row.add_child(clear)

func cancel_capture() -> void:
	capture_action = ""
	capture_context = ""

func consume(event: InputEventKey) -> bool:
	if capture_action.is_empty() or not is_visible_in_tree(): return false
	if event.pressed and not event.echo and event.keycode not in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
		store(capture_context, capture_action, int(event.get_keycode_with_modifiers()))
	return true

func store(scope: String, action: String, key: int) -> void:
	var before: Dictionary = mapping.profiles.duplicate(true)
	var error: String = mapping.assign(scope, action, key)
	if not error.is_empty():
		status.text = error + String(TranslationServer.translate("KEYBOARD_CONFLICT_HINT"))
		return
	if mapping.save() != OK:
		mapping.profiles = before
		status.text = "KEYBOARD_SETTINGS_FAILED_TO_SAVE_PREVIOUS_KEYS_REMAIN_ACTIVE"
		return
	cancel_capture()
	status.text = "KEYBOARD_SETTINGS_KEYBOARD_MAPPING_SAVED"
	refresh()

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	active_profile.text = String(TranslationServer.translate("KEYBOARD_SETTINGS_ACTIVE_PROFILE")) + tr(Mapping.CONTEXT_LABELS[Mapping.CONTEXTS.find(game._keyboard_profile())])
	enabled_check.set_pressed_no_signal(mapping.enabled)
