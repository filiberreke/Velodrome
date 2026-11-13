extends CanvasLayer
## Separate discovery socket: never claims or refreshes the trainer lease.
const Style := preload("res://menu_theme.gd")
const ROLES := ["trainer", "controller", "heart_rate"]
const LABELS := ["Trainer / rollen", "Besturing", "Hartslagmeter"]
var socket := PacketPeerUDP.new()
var port := 51725
var session := "devices-%d" % Time.get_ticks_usec()
var sequence := 0
var requests: Dictionary = {}
var snapshot: Dictionary = {}
var newest_snapshot := -1
var last_poll := -10.0
var last_response := -10.0
var auto_shown := false
var panel_root: ColorRect
var open_button: Button
var status: Label
var choices: Dictionary = {}
var connection_labels: Dictionary = {}
var mapping_separator: HSeparator
var controller_connection: Label
var keyboard_check: CheckButton
var mapping_link: Button
var close_button: Button
var return_focus: Control
var pending := ""
var pending_at := 0.0
var error := ""

func _ready() -> void:
	layer = 105
	var toolbar := Control.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.theme = Style.create()
	add_child(toolbar)
	open_button = Button.new()
	open_button.text = get_parent().setup_panel.bridge_status_text
	open_button.icon = Style.icon('<path d="m9.7 3-.6 2.1-2 .9-1.9-1.1L3 8.7l1.6 1.6v2.3L3 14.2l2.2 3.8 2.2-.6 2 1.2.5 2.4h4.4l.5-2.4 2-1.2 2.2.6 2.2-3.8-1.6-1.6v-2.3L21 8.7l-2.2-3.8-1.9 1.1-2-.9L14.3 3Z"/><circle cx="12" cy="12" r="3"/>', Style.MUTED)
	open_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	open_button.add_theme_font_size_override("font_size", 18)
	open_button.add_theme_color_override("font_color", Style.MUTED)
	open_button.add_theme_constant_override("h_separation", 16)
	open_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	open_button.tooltip_text = "Bridge-apparaten instellen"
	open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_button.offset_left = -785
	open_button.offset_right = -310
	open_button.offset_top = 48
	open_button.offset_bottom = 100
	open_button.pressed.connect(open_page)
	toolbar.add_child(open_button)
	panel_root = ColorRect.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.color = Color(0.03, 0.08, 0.15, 0.85)
	panel_root.theme = Style.create()
	add_child(panel_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 650)
	panel.add_theme_stylebox_override("panel", Style.panel(Style.IVORY, Style.LINE, 32))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Apparaten"
	title.add_theme_font_override("font", Style.heading())
	title.add_theme_font_size_override("font_size", 32)
	var page_header := HBoxContainer.new()
	page_header.add_theme_constant_override("separation", 20)
	box.add_child(page_header)
	var back := Button.new()
	back.text = "← Terug"
	back.custom_minimum_size = Vector2(190, 48)
	Style.primary(back)
	back.pressed.connect(close_page)
	page_header.add_child(back)
	page_header.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(1000, 52)
	box.add_child(status)
	for i in ROLES.size():
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 10)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Style.panel(Style.PAPER, Style.LINE, 16, 12))
		box.add_child(card)
		card.add_child(section)
		var header := HBoxContainer.new()
		section.add_child(header)
		var label := Label.new()
		label.text = LABELS[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(label)
		if ROLES[i] == "controller":
			controller_connection = Label.new()
			controller_connection.text = "Verbonden"
			controller_connection.add_theme_font_size_override("font_size", 16)
			controller_connection.add_theme_color_override("font_color", Color("008b38"))
			controller_connection.add_theme_stylebox_override("normal", Style.panel(Color("d9f5e3"), Color.TRANSPARENT, 6, 12))
			header.add_child(controller_connection)
			connection_labels[ROLES[i]] = controller_connection
		else:
			var connection := Label.new()
			connection.add_theme_font_size_override("font_size", 16)
			header.add_child(connection)
			connection_labels[ROLES[i]] = connection
		var option := OptionButton.new()
		option.custom_minimum_size.y = 48
		section.add_child(option)
		choices[ROLES[i]] = option
		option.item_selected.connect(func(index: int): _select(ROLES[i], index))
		if ROLES[i] == "controller":
			keyboard_check = CheckButton.new()
			keyboard_check.text = "Toetsenbordbediening gebruiken"
			keyboard_check.button_pressed = get_parent().keyboard_mapping.enabled
			keyboard_check.toggled.connect(func(value):
				var mapping = get_parent().keyboard_mapping
				var before: bool = mapping.enabled
				mapping.enabled = value
				if mapping.save() != OK:
					mapping.enabled = before
					keyboard_check.set_pressed_no_signal(before)
					error = "Toetsenbordkeuze kon niet worden opgeslagen."
				get_parent()._clear_look_back())
			section.add_child(keyboard_check)
			mapping_separator = HSeparator.new()
			section.add_child(mapping_separator)
			mapping_link = Button.new()
			mapping_link.text = "Toetsenbord en controller instellen"
			mapping_link.tooltip_text = "Alle toetsen aanpassen; toetsenbord werkt ook zonder Zwift Ride"
			mapping_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
			mapping_link.flat = true
			mapping_link.custom_minimum_size.y = 40
			mapping_link.icon = Style.icon('<path d="M4 6h4m4 0h8M4 12h9m4 0h3M4 18h2m4 0h10M8 3v6m5 0v6M6 15v6"/>', Style.MUTED)
			mapping_link.add_theme_constant_override("icon_max_width", 20)
			mapping_link.add_theme_font_size_override("font_size", 18)
			mapping_link.add_theme_color_override("font_color", Style.MUTED)
			mapping_link.add_theme_color_override("font_pressed_color", Style.INK)
			mapping_link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			mapping_link.add_theme_stylebox_override("hover", Style.panel(Style.PALE, Color.TRANSPARENT, 6))
			mapping_link.add_theme_stylebox_override("pressed", Style.panel(Style.PALE, Color.TRANSPARENT, 6))
			var arrow := TextureRect.new()
			arrow.texture = Style.icon('<path d="M7 17 17 7M8 7h9v9"/>', Style.MUTED)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			arrow.offset_left = -26
			arrow.offset_right = -6
			arrow.offset_top = -10
			arrow.offset_bottom = 10
			mapping_link.add_child(arrow)
			mapping_link.pressed.connect(open_mapping)
			section.add_child(mapping_link)
	close_button = Button.new()
	close_button.text = "Overslaan"
	Style.primary(close_button)
	close_button.pressed.connect(close_page)
	box.add_child(close_button)
	panel_root.hide()
	_refresh()
	socket.bind(0, "127.0.0.1")
	socket.set_dest_address("127.0.0.1", port)

func _send(command: String, params: Dictionary = {}) -> String:
	sequence += 1
	var id := "%s-%d" % [session, sequence]
	var packet := {"type": "command", "v": 1, "id": id, "command": command}
	packet.merge(params)
	requests[id] = Time.get_ticks_msec() / 1000.0
	socket.put_packet(JSON.stringify(packet).to_utf8_buffer())
	return id

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_poll >= 1.0:
		last_poll = now
		_send("devices")
		for id in requests.keys():
			if now - float(requests[id]) > 5.0: requests.erase(id)
	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet()
		if socket.get_packet_ip() != "127.0.0.1" or socket.get_packet_port() != port: continue
		var packet: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if packet is Dictionary: handle_response(packet, now)
	if not pending.is_empty() and now - pending_at > 4.0:
		pending = ""
		error = "Geen bevestiging ontvangen. Controleer de bridge; de lijst wordt opnieuw opgehaald."
	var settings = get_parent().get_node_or_null("GameSettings")
	open_button.text = get_parent().setup_panel.bridge_status_text
	open_button.tooltip_text = open_button.text + "\nBridge-apparaten instellen"
	open_button.visible = not panel_root.visible and (settings == null or not settings.panel_root.visible)
	if not auto_shown and now - last_response < 3.0 and get_parent().get("start_state") == "SETUP":
		auto_shown = true
		open_page()
	if now - last_response > 3.0:
		status.text = "Bridge niet bereikbaar. Start de bridge of ga verder met Overslaan."
		for option in choices.values(): option.disabled = true
		_update_connection_action(false)

func handle_response(packet: Dictionary, now: float) -> void:
	var id := str(packet.get("id", ""))
	if packet.get("v") != 1 or not requests.has(id) or packet.get("type") not in ["ack", "error"]: return
	requests.erase(id)
	last_response = now
	var selection_reply := id == pending
	if selection_reply: pending = ""
	if packet.get("ok") != true:
		if selection_reply or snapshot.is_empty(): error = "Deze bridge ondersteunt apparaatselectie niet. Werk de bridge bij." if packet.get("code") in ["unknown_command", "unsupported"] else str(packet.get("message", "Apparaatselectie mislukt."))
	elif packet.get("state") is Dictionary and packet.state.get("device_selection_v") == 1:
		var response_sequence := id.trim_prefix(session + "-").to_int()
		if response_sequence >= newest_snapshot:
			snapshot = packet.state
			newest_snapshot = response_sequence
			# Only confirmed, current selections change the game's power source.
			var selected: Dictionary = snapshot.get("selected", {})
			get_parent()._set_trainer_disabled(selected.get("trainer") == "")
		if selection_reply: error = ""
	_refresh()

func _refresh() -> void:
	status.text = error if not error.is_empty() else "Kies uit gevonden apparaten. Keuzes worden door de bridge onthouden; verbinden kan even duren."
	if not str(snapshot.get("scan_error", "")).is_empty(): status.text += "\nScan: " + str(snapshot.scan_error)
	var selected: Dictionary = snapshot.get("selected", {})
	var connected: Dictionary = snapshot.get("connected", {})
	for role in ROLES:
		var option: OptionButton = choices[role]
		# Avoid rebuilding an open mouse/keyboard popup during periodic polling.
		if option.get_popup().visible: continue
		option.clear()
		option.add_item("Geen / overslaan")
		option.set_item_metadata(0, "")
		var address := str(selected.get(role, "")) if selected.get(role) != null else str(connected.get(role, ""))
		var found := false
		for device in snapshot.get("devices", []):
			if role not in device.get("roles", []): continue
			var suffix := " · verbonden" if connected.get(role) == device.address else ""
			if not device.get("available", false): suffix = " · niet beschikbaar"
			option.add_item("%s · %s%s" % [device.name, device.address, suffix])
			var index := option.item_count - 1
			option.set_item_metadata(index, device.address)
			option.set_item_disabled(index, not device.get("available", false))
			if device.address == address:
				option.select(index)
				found = true
		if not address.is_empty() and not found:
			option.add_item(address + " · niet beschikbaar")
			option.set_item_metadata(option.item_count - 1, address)
			option.set_item_disabled(option.item_count - 1, true)
			option.select(option.item_count - 1)
		option.disabled = snapshot.is_empty() or not pending.is_empty()
	mapping_link.visible = true
	mapping_separator.visible = mapping_link.visible
	_update_connection_action(Time.get_ticks_msec() / 1000.0 - last_response <= 3.0)

func _update_connection_action(online: bool) -> void:
	var connected: Dictionary = snapshot.get("connected", {})
	var any_connected := false
	for role in ROLES:
		if online and not str(connected.get(role, "")).is_empty(): any_connected = true
		var live: bool = online and not str(connected.get(role, "")).is_empty()
		var badge: Label = connection_labels[role]
		badge.text = "Verbonden" if live else "Niet verbonden"
		badge.add_theme_color_override("font_color", Color("008b38") if live else Style.MUTED)
		badge.add_theme_stylebox_override("normal", Style.panel(Color("d9f5e3") if live else Style.PALE, Color.TRANSPARENT, 6, 8))
	close_button.text = "Kies deze setup" if any_connected else "Overslaan"
	keyboard_check.set_pressed_no_signal(get_parent().keyboard_mapping.enabled)
	controller_connection.visible = true
	var ride_online := online and not str(connected.get("controller", "")).is_empty()
	controller_connection.text = "Ride verbonden" if ride_online else "Geen Ride: toetsenbord beschikbaar"
	controller_connection.add_theme_color_override("font_color", Color("008b38") if ride_online else Style.MUTED)

func _select(role: String, index: int) -> void:
	if not pending.is_empty(): return
	var option: OptionButton = choices[role]
	pending_at = Time.get_ticks_msec() / 1000.0
	pending = _send("select_device", {"role": role, "address": str(option.get_item_metadata(index))})
	_refresh()

func open_page() -> void:
	auto_shown = true
	return_focus = get_viewport().gui_get_focus_owner()
	get_parent().call("_pause_race")
	get_parent().call("_clear_look_back")
	panel_root.show()
	_refresh()
	close_button.grab_focus()

func close_page() -> void:
	panel_root.hide()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()
	elif get_parent().get("race_paused"): get_parent().exit_menu.resume_button.grab_focus()

func open_mapping() -> void:
	panel_root.hide()
	get_parent().get_node("GameSettings").open_device_mapping()

func bridge_action(key: String) -> void:
	if key in ["B", "Z"]: close_page()
	else: get_parent().ride_navigation.navigate(panel_root, key, close_button, true)

func _exit_tree() -> void:
	socket.close()
