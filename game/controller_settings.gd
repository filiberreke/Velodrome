extends VBoxContainer
## Live, read-only diagnostics for Zwift Ride. No remapping in this first phase.
const MenuStyle := preload("res://menu_theme.gd")
const BUTTONS := [
    ["UP", "Menu omhoog"], ["DOWN", "Menu omlaag"],
    ["LEFT", "Menu links"], ["RIGHT", "Menu rechts"],
    ["A", "Bevestigen"], ["B", "Terug / achteruitkijken (later)"],
    ["Y", "Camera wisselen (gepland)"], ["Z", "Pauze (gepland)"],
    ["SHIFT_UP_LEFT", "Schakelen links omhoog"],
    ["SHIFT_DOWN_LEFT", "Schakelen links omlaag"],
    ["SHIFT_UP_RIGHT", "Schakelen rechts omhoog"],
    ["SHIFT_DOWN_RIGHT", "Schakelen rechts omlaag"],
    ["POWER_LEFT", "DROP_LEFT — gereserveerd voor arcade"], ["POWER_RIGHT", "DROP_RIGHT — gereserveerd voor arcade"],
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

func _ready() -> void:
    add_theme_constant_override("separation", 12)
    var title := Label.new()
    title.text = "ZWIFT RIDE  /  CONTROLLERTEST"
    title.add_theme_color_override("font_color", MenuStyle.BLUE)
    add_child(title)
    var help := Label.new()
    help.text = "Druk een knop in: de regel licht op tot je loslaat. De toewijzing is nog niet aanpasbaar."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(help)
    status_label = Label.new()
    status_label.text = "Verbinding: wacht op een Ride-signaal"
    add_child(status_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 390
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
        key.text = str(entry[0])
        key.custom_minimum_size.x = 180
        row.add_child(key)
        var action := Label.new()
        action.text = str(entry[1])
        action.add_theme_color_override("font_color", MenuStyle.MUTED)
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

func set_testing(value: bool) -> void:
    active = value
    if not active:
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
            pressed_buttons.clear()
            _refresh_indicators()
    elif kind == "controller_button":
        var key := str(packet.get("source_button", ""))
        if key.is_empty():
            return
        var pressed := bool(packet.get("pressed", false))
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
