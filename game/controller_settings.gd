extends VBoxContainer
## Diagnostics consume physical input, including unmapped buttons.
const Mapping := preload("res://ride_mapping.gd")
const MenuStyle := preload("res://menu_theme.gd")
const BUTTONS := [
    ["UP", "CONTROLLER_SETTINGS_MENU_UP_PREVIOUS_CAMERA"], ["DOWN", "CONTROLLER_SETTINGS_MENU_DOWN_NEXT_CAMERA"],
    ["LEFT", "CONTROLLER_SETTINGS_MENU_LEFT"], ["RIGHT", "CONTROLLER_SETTINGS_MENU_RIGHT"],
    ["A", "CONTROLLER_SETTINGS_CONFIRM"], ["B", "CONTROLLER_SETTINGS_BACK_HOLD_LOOK_BEHIND"],
    ["Y", "CONTROLLER_SETTINGS_NAME_POWER_ENERGY_V"], ["Z", "CONTROLLER_SETTINGS_PAUSE_SETTINGS_EXIT_TEST"],
    ["SHIFT_UP_LEFT", "INPUT_SHIFT_DOWN"],
    ["SHIFT_DOWN_LEFT", "INPUT_SHIFT_DOWN"],
    ["SHIFT_UP_RIGHT", "INPUT_SHIFT_UP"],
    ["SHIFT_DOWN_RIGHT", "INPUT_SHIFT_UP"],
    ["POWER_LEFT", "CONTROL_RESERVED_FOR_ARCADE"], ["POWER_RIGHT", "CONTROL_RESERVED_FOR_ARCADE"],
    ["ONOFF_LEFT", "CONTROL_NO_GAME_ACTION_YET"], ["ONOFF_RIGHT", "CONTROL_NO_GAME_ACTION_YET"],
]
var active := false
var connected := false
var indicators: Dictionary = {}
var pressed_buttons: Dictionary = {}
var status_label: Label
var last_label: Label
var steering_bar: ProgressBar
var steering_label: Label
var mapping: RefCounted
var context_choice: OptionButton
var action_choice: OptionButton
var trigger_choice: OptionButton
var mapping_status: Label
var binding_labels := {}
var capturing := false
var capture_consumed := false
var candidate := ""
var confirm_button: Button

func _ready() -> void:
    add_theme_constant_override("separation", 12)
    var title := Label.new()
    title.text = "CONTROL_ZWIFT_RIDE_CONTROLLER_TEST"
    title.add_theme_color_override("font_color", MenuStyle.BLUE)
    add_child(title)
    var help := Label.new()
    help.text = "CONTROL_SAFE_BUTTON_TEST_Z_EXITS_THE_TEST_EXCEPT_WHILE_CHANGING_A_BUTTON_SHIFT"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(help)
    var owner_node: Node = get_parent()
    while owner_node != null:
        if owner_node.get("ride_mapping") != null:
            mapping = owner_node.get("ride_mapping")
            break
        owner_node = owner_node.get_parent()
    _build_editor()
    status_label = Label.new()
    status_label.text = "CONTROL_CONNECTION_WAITING_FOR_A_RIDE_SIGNAL"
    add_child(status_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 270
    add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 7)
    scroll.add_child(grid)
    for entry in BUTTONS:
        var panel := PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.custom_minimum_size = Vector2(0, 43)
        var style := StyleBoxFlat.new()
        style.bg_color = MenuStyle.PAPER
        style.set_corner_radius_all(6)
        style.set_content_margin_all(7)
        panel.add_theme_stylebox_override("panel", style)
        grid.add_child(panel)
        var row := HBoxContainer.new()
        panel.add_child(row)
        var key := Label.new()
        key.text = str(entry[0]).replace("POWER_LEFT", "DROP_LEFT").replace("POWER_RIGHT", "DROP_RIGHT")
        key.custom_minimum_size.x = 250
        key.add_theme_font_size_override("font_size", 18)
        row.add_child(key)
        var action := Label.new()
        action.text = str(entry[1])
        binding_labels[str(entry[0])] = action
        action.add_theme_color_override("font_color", MenuStyle.MUTED)
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        action.add_theme_font_size_override("font_size", 18)
        action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(action)
        indicators[str(entry[0])] = panel
    steering_label = Label.new()
    steering_label.text = "CONTROL_ANALOGUE_PADDLES_STEERING_VALUE_0"
    add_child(steering_label)
    steering_bar = ProgressBar.new()
    steering_bar.min_value = -100
    steering_bar.max_value = 100
    steering_bar.value = 0
    steering_bar.show_percentage = false
    steering_bar.custom_minimum_size.y = 12
    add_child(steering_bar)
    last_label = Label.new()
    last_label.text = "CONTROL_LAST_INPUT"
    add_child(last_label)
    _refresh_mapping()

func set_testing(value: bool) -> void:
    active = value
    if not active:
        cancel_capture()
        pressed_buttons.clear()
        _refresh_indicators()
        if steering_bar != null:
            steering_bar.value = 0
            steering_label.text = "CONTROL_ANALOGUE_PADDLES_STEERING_VALUE_0"

func receive_packet(packet: Dictionary) -> void:
    if not active:
        return
    var kind := str(packet.get("type", ""))
    if kind == "controller_connection":
        connected = bool(packet.get("connected", false))
        status_label.text = "CONTROL_RIDE_CONNECTED" if connected else "CONTROL_RIDE_DISCONNECTED"
        if not connected:
            cancel_capture()
            pressed_buttons.clear()
            _refresh_indicators()
    elif kind == "controller_button":
        var key := Mapping.physical(str(packet.get("source_button", "")))
        if key.is_empty():
            return
        var pressed := bool(packet.get("pressed", false))
        capture_consumed = capturing or not candidate.is_empty()
        if capturing and pressed and key in Mapping.BUTTONS and not pressed_buttons.has(key):
            candidate = key
            capturing = false
            confirm_button.disabled = false
            mapping_status.text = String(TranslationServer.translate("CONTROL_S_S_CONFIRM_TO_SAVE")) % [Mapping.display(key), tr(Mapping.ACTIONS[_context()][_action()])]
        if pressed:
            pressed_buttons[key] = true
        else:
            pressed_buttons.erase(key)
        last_label.text = String(TranslationServer.translate("CONTROL_LAST_INPUT_S_S")) % [key, "ingedrukt" if pressed else "losgelaten"]
        status_label.text = "CONTROL_RIDE_BUTTON_DATA_RECEIVED"
        _refresh_indicators()
    elif kind == "steering":
        var value: Variant = packet.get("value", 0)
        if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
            return
        steering_bar.value = clampf(float(value), -100.0, 100.0)
        steering_label.text = String(TranslationServer.translate("CONTROL_ANALOGUE_PADDLES_STEERING_VALUE_D")) % roundi(float(value))
        last_label.text = String(TranslationServer.translate("CONTROL_LAST_INPUT_STEERING_VALUE_D")) % roundi(float(value))

func _refresh_indicators() -> void:
    for key in indicators:
        var panel: PanelContainer = indicators[key]
        var style := StyleBoxFlat.new()
        style.bg_color = MenuStyle.BLUE.lightened(0.40) if pressed_buttons.has(key) else MenuStyle.PAPER
        style.set_corner_radius_all(6)
        style.set_content_margin_all(7)
        panel.add_theme_stylebox_override("panel", style)

func _context() -> String:
    return ["menu", "race", "arcade"][context_choice.selected]

func _action() -> String:
    return str(Mapping.ACTIONS[_context()].keys()[action_choice.selected])

func _build_editor() -> void:
    var heading := Label.new()
    heading.text = "CONTROL_BUTTON_ASSIGNMENT"
    add_child(heading)
    var row := HBoxContainer.new()
    add_child(row)
    context_choice = OptionButton.new()
    for caption in ["CONTROL_MENU", "CONTROL_RACE", "CONTROL_ARCADE_COMING_SOON"]: context_choice.add_item(caption)
    row.add_child(context_choice)
    action_choice = OptionButton.new()
    row.add_child(action_choice)
    trigger_choice = OptionButton.new()
    for caption in ["CONTROL_ON_PRESS", "CONTROL_ON_RELEASE", "CONTROL_HOLD"]: trigger_choice.add_item(caption)
    row.add_child(trigger_choice)
    context_choice.item_selected.connect(func(_index):
        cancel_capture()
        _populate_actions()
        _refresh_mapping())
    action_choice.item_selected.connect(func(_index):
        cancel_capture()
        _refresh_trigger())
    var buttons := HBoxContainer.new()
    add_child(buttons)
    _editor_button(buttons, "CONTROL_CHANGE_BUTTON", begin_capture)
    confirm_button = _editor_button(buttons, "CONTROLLER_SETTINGS_CONFIRM", confirm_mapping)
    confirm_button.disabled = true
    _editor_button(buttons, "WORKOUT_EDITOR_CANCEL", cancel_capture)
    _editor_button(buttons, "KEYBOARD_SETTINGS_UNASSIGN", func(): _persist_binding(""))
    _editor_button(buttons, "CONTROL_RESET_CONTEXT", func(): _restore(false))
    _editor_button(buttons, "CONTROL_RESET_ALL", func(): _restore(true))
    mapping_status = Label.new()
    mapping_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(mapping_status)
    _populate_actions()
    mapping_status.text = mapping.status

func _editor_button(row: HBoxContainer, caption: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.pressed.connect(callback)
    row.add_child(button)
    return button

func _populate_actions() -> void:
    action_choice.clear()
    for caption in Mapping.ACTIONS[_context()].values(): action_choice.add_item(caption)
    _refresh_trigger()

func _refresh_trigger() -> void:
    var hold := _action() == "look_back"
    trigger_choice.set_item_disabled(0, hold)
    trigger_choice.set_item_disabled(1, hold)
    trigger_choice.set_item_disabled(2, not hold)
    trigger_choice.select(["press", "release", "hold"].find(mapping.profiles[_context()][_action()].trigger))

func begin_capture() -> void:
    cancel_capture()
    capturing = true
    mapping_status.text = "CONTROL_PRESS_THE_DESIRED_PHYSICAL_BUTTON_RELEASE_ANY_HELD_BUTTON_FIRST"

func cancel_capture() -> void:
    capturing = false
    candidate = ""
    capture_consumed = false
    if confirm_button != null: confirm_button.disabled = true

func confirm_mapping() -> void:
    if candidate.is_empty(): return
    _persist_binding(candidate)

func _persist_binding(button: String) -> void:
    var before: Dictionary = mapping.profiles.duplicate(true)
    var was_custom: bool = mapping.customized
    var error: String = mapping.assign(_context(), _action(), button, ["press", "release", "hold"][trigger_choice.selected])
    if not error.is_empty():
        mapping_status.text = error + String(TranslationServer.translate("CONTROL_UNASSIGN_THE_OTHER_ACTION_FIRST"))
        return
    if mapping.save() != OK:
        mapping.profiles = before
        mapping.customized = was_custom
        mapping_status.text = "CONTROL_FAILED_TO_SAVE_PREVIOUS_MAPPING_REMAINS_ACTIVE"
        return
    cancel_capture()
    mapping_status.text = "CONTROL_MAPPING_SAVED_TEST_THE_BUTTON_HERE_GAME_ACTIONS_WORK_OUTSIDE_THE_TEST"
    _refresh_mapping()

func _restore(all_contexts: bool) -> void:
    var before: Dictionary = mapping.profiles.duplicate(true)
    var was_custom: bool = mapping.customized
    mapping.reset("" if all_contexts else _context())
    if mapping.save() != OK:
        mapping.profiles = before
        mapping.customized = was_custom
        mapping_status.text = "CONTROL_FAILED_TO_SAVE_PREVIOUS_MAPPING_REMAINS_ACTIVE"
        return
    cancel_capture()
    mapping_status.text = "CONTROL_DEFAULT_SETTINGS_SAVED"
    _refresh_mapping()
    _refresh_trigger()

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_mapping()


func _refresh_mapping() -> void:
    for button in binding_labels:
        var action: String = mapping.action_for(_context(), button)
        var caption := String(TranslationServer.translate("CONTROL_UNASSIGNED_NO_GAME_ACTION"))
        if not action.is_empty():
            var binding: Dictionary = mapping.profiles[_context()][action]
            caption = "%s (%s)" % [tr(Mapping.ACTIONS[_context()][action]), tr({"press":"INPUT_PRESS", "release":"INPUT_RELEASE", "hold":"INPUT_HOLD"}.get(binding.trigger, ""))]
        if _context() == "race" and button == "A":
            var madison := String(TranslationServer.translate("CONTROL_MADISON_EXCHANGE_PRESS_TO_GRAB_EASY_AUTOMATIC_HAND_SLING_AND_RELEASE_A"))
            caption = madison if action.is_empty() else caption + "\n" + madison
        if button.begins_with("SHIFT_"): caption += String(TranslationServer.translate("CONTROL_GEAR_SHIFTING_IN_BRIDGE"))
        binding_labels[button].text = caption
