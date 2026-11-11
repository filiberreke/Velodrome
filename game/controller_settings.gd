extends VBoxContainer
## Diagnostics consume physical input, including unmapped buttons.
const Mapping := preload("res://ride_mapping.gd")
const MenuStyle := preload("res://menu_theme.gd")
const BUTTONS := [
    ["UP", "Menu omhoog / vorige camera"], ["DOWN", "Menu omlaag / volgende camera"],
    ["LEFT", "Menu links"], ["RIGHT", "Menu rechts"],
    ["A", "Bevestigen"], ["B", "Terug / vasthouden: achteruitkijken"],
    ["Y", "Naam / wattage / energie (V)"], ["Z", "Pauze / instellingen / test verlaten"],
    ["SHIFT_UP_LEFT", "Afschakelen (lichter)"],
    ["SHIFT_DOWN_LEFT", "Afschakelen (lichter)"],
    ["SHIFT_UP_RIGHT", "Opschakelen (zwaarder)"],
    ["SHIFT_DOWN_RIGHT", "Opschakelen (zwaarder)"],
    ["POWER_LEFT", "Gereserveerd voor arcade"], ["POWER_RIGHT", "Gereserveerd voor arcade"],
    ["ONOFF_LEFT", "Nog geen spelactie"], ["ONOFF_RIGHT", "Nog geen spelactie"],
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
    title.text = "ZWIFT RIDE  /  CONTROLLERTEST"
    title.add_theme_color_override("font_color", MenuStyle.BLUE)
    add_child(title)
    var help := Label.new()
    help.text = "Veilige knoptest. Z verlaat de test (behalve tijdens knop wijzigen). SHIFT blijft schakelen in de bridge; analoge paddles blijven sturen."
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
    status_label.text = "Verbinding: wacht op een Ride-signaal"
    add_child(status_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 270
    add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 7)
    scroll.add_child(grid)
    for entry in BUTTONS:
        var panel := PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.custom_minimum_size = Vector2(465, 43)
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
        key.custom_minimum_size.x = 180
        row.add_child(key)
        var action := Label.new()
        action.text = str(entry[1])
        binding_labels[str(entry[0])] = action
        action.add_theme_color_override("font_color", MenuStyle.MUTED)
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(action)
        indicators[str(entry[0])] = panel
    steering_label = Label.new()
    steering_label.text = "Analoge paddles / stuurwaarde: 0"
    add_child(steering_label)
    steering_bar = ProgressBar.new()
    steering_bar.min_value = -100
    steering_bar.max_value = 100
    steering_bar.value = 0
    steering_bar.show_percentage = false
    add_child(steering_bar)
    last_label = Label.new()
    last_label.text = "Laatste invoer: —"
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
            steering_label.text = "Analoge paddles / stuurwaarde: 0"

func receive_packet(packet: Dictionary) -> void:
    if not active:
        return
    var kind := str(packet.get("type", ""))
    if kind == "controller_connection":
        connected = bool(packet.get("connected", false))
        status_label.text = "Ride: verbonden" if connected else "Ride: verbinding verbroken"
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
            mapping_status.text = "%s → %s. Bevestig om op te slaan." % [Mapping.display(key), Mapping.ACTIONS[_context()][_action()]]
        if pressed:
            pressed_buttons[key] = true
        else:
            pressed_buttons.erase(key)
        last_label.text = "Laatste invoer: %s %s" % [key, "ingedrukt" if pressed else "losgelaten"]
        status_label.text = "Ride: knopdata ontvangen"
        _refresh_indicators()
    elif kind == "steering":
        var value: Variant = packet.get("value", 0)
        if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
            return
        steering_bar.value = clampf(float(value), -100.0, 100.0)
        steering_label.text = "Analoge paddles / stuurwaarde: %d" % roundi(float(value))
        last_label.text = "Laatste invoer: stuurwaarde %d" % roundi(float(value))

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
    heading.text = "Knoptoewijzing"
    add_child(heading)
    var row := HBoxContainer.new()
    add_child(row)
    context_choice = OptionButton.new()
    for caption in ["Menu", "Wedstrijd", "Arcade (toekomstig)"]: context_choice.add_item(caption)
    row.add_child(context_choice)
    action_choice = OptionButton.new()
    row.add_child(action_choice)
    trigger_choice = OptionButton.new()
    for caption in ["Bij indrukken", "Bij loslaten", "Vasthouden"]: trigger_choice.add_item(caption)
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
    _editor_button(buttons, "Knop wijzigen", begin_capture)
    confirm_button = _editor_button(buttons, "Bevestigen", confirm_mapping)
    confirm_button.disabled = true
    _editor_button(buttons, "Annuleren", cancel_capture)
    _editor_button(buttons, "Vrijmaken", func(): _persist_binding(""))
    _editor_button(buttons, "Herstel context", func(): _restore(false))
    _editor_button(buttons, "Herstel alles", func(): _restore(true))
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
    mapping_status.text = "Druk de gewenste fysieke knop in (laat een ingedrukte knop eerst los)."

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
        mapping_status.text = error + ". Maak de andere actie eerst vrij."
        return
    if mapping.save() != OK:
        mapping.profiles = before
        mapping.customized = was_custom
        mapping_status.text = "Opslaan mislukt; vorige mapping blijft actief."
        return
    cancel_capture()
    mapping_status.text = "Mapping opgeslagen. Test de knop hier; spelacties werken buiten de test."
    _refresh_mapping()

func _restore(all_contexts: bool) -> void:
    var before: Dictionary = mapping.profiles.duplicate(true)
    var was_custom: bool = mapping.customized
    mapping.reset("" if all_contexts else _context())
    if mapping.save() != OK:
        mapping.profiles = before
        mapping.customized = was_custom
        mapping_status.text = "Opslaan mislukt; vorige mapping blijft actief."
        return
    cancel_capture()
    mapping_status.text = "Standaardinstellingen opgeslagen."
    _refresh_mapping()
    _refresh_trigger()

func _refresh_mapping() -> void:
    for button in binding_labels:
        var action: String = mapping.action_for(_context(), button)
        var caption := "Vrij / geen spelactie"
        if not action.is_empty():
            var binding: Dictionary = mapping.profiles[_context()][action]
            caption = "%s (%s)" % [Mapping.ACTIONS[_context()][action], {"press":"indrukken", "release":"loslaten", "hold":"vasthouden"}[binding.trigger]]
        if _context() == "race" and button == "A":
            var madison := "Madison-aflossing: indrukken = grijpen. Easy: automatisch slingeren en loslaten. Advanced: vasthouden = slingeren, loslaten = aflossen."
            caption = madison if action.is_empty() else caption + "\n" + madison
        if button.begins_with("SHIFT_"): caption += " · schakelen in bridge"
        binding_labels[button].text = caption
