extends Control
## Standalone browser proof-of-concept. Does not load the 3D stadium or ERG engine.
## Requires the separately installed Godot WRY GDExtension.

const START_URL := "https://www.youtube.com"
const HUD_HEIGHT := 148.0
const BAR_HEIGHT := 52.0

var browser: Control
var address: LineEdit
var status_label: Label
var browser_area: Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var toolbar := HBoxContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = BAR_HEIGHT
	add_child(toolbar)

	var back := Button.new()
	back.text = "Home"
	back.pressed.connect(func(): _navigate(START_URL))
	toolbar.add_child(back)

	address = LineEdit.new()
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.text = START_URL
	address.placeholder_text = "https://..."
	address.text_submitted.connect(_navigate)
	toolbar.add_child(address)

	var go := Button.new()
	go.text = "Open"
	go.pressed.connect(func(): _navigate(address.text))
	toolbar.add_child(go)

	browser_area = Control.new()
	browser_area.anchor_right = 1.0
	browser_area.anchor_bottom = 1.0
	browser_area.offset_top = BAR_HEIGHT
	browser_area.offset_bottom = -HUD_HEIGHT
	add_child(browser_area)

	var hud := PanelContainer.new()
	hud.anchor_top = 1.0
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	hud.offset_top = -HUD_HEIGHT
	add_child(hud)

	var hud_box := VBoxContainer.new()
	hud.add_child(hud_box)
	var heading := Label.new()
	heading.text = "VIDEO POC  |  ERG HUD PLACEHOLDER (no trainer connected)"
	hud_box.add_child(heading)
	var stats := Label.new()
	stats.text = "Power: -- W     Target: -- W     Cadence: -- rpm     Heart rate: -- bpm     Time: --:--"
	hud_box.add_child(stats)
	status_label = Label.new()
	status_label.text = "Browser not initialized"
	hud_box.add_child(status_label)

	if not ClassDB.class_exists("WebView"):
		status_label.text = "Missing Godot WRY: install addon before running this scene."
		return

	browser = ClassDB.instantiate("WebView") as Control
	if browser == null:
		status_label.text = "Could not instantiate WRY WebView."
		return
	browser_area.add_child(browser)
	browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	browser.set("full_window_size", false)
	browser.set("devtools", true)
	browser.set("autoplay", false)
	browser.call("load_url", START_URL)
	browser.connect("page_load_started", _on_load_started)
	browser.connect("page_load_finished", _on_load_finished)
	get_viewport().size_changed.connect(_on_window_resized)
	status_label.text = "Opening " + START_URL

func _on_window_resized() -> void:
	if is_instance_valid(browser):
		browser.call_deferred("resize")

func _navigate(raw_url: String) -> void:
	var url := raw_url.strip_edges()
	if not (url.begins_with("https://") or url.begins_with("http://")):
		status_label.text = "Only http:// and https:// URLs are supported."
		return
	address.text = url
	if is_instance_valid(browser):
		browser.call("load_url", url)
	else:
		status_label.text = "WebView unavailable: install Godot WRY."

func _on_load_started(url: String) -> void:
	status_label.text = "Loading: " + url

func _on_load_finished(url: String) -> void:
	status_label.text = "Loaded: " + url
