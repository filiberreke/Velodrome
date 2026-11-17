extends VBoxContainer
const Formats := preload("res://omnium/omnium_formats.gd")
const Countries := preload("res://rennersboxen/race_countries.gd")
var menu
var manager = preload("res://omnium/omnium_manager.gd").new()
var draft = preload("res://omnium/omnium_selection.gd").new()
var body: VBoxContainer
var back_button: Button
var message: Label
var editing := false
var opened := false
var choosing_startlist := false
var picker_layer: CanvasLayer

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	back_button = Button.new(); back_button.text = "← Hoofdmenu"
	back_button.pressed.connect(go_back); add_child(back_button)
	manager.load_session(int(Time.get_unix_time_from_system()))
	refresh()

func clear_body() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func button(text: String, action: Callable, parent: Node = null) -> Button:
	var item := Button.new(); item.text = text; item.custom_minimum_size.y = 46
	item.pressed.connect(action)
	(body if parent == null else parent).add_child(item)
	return item

func player() -> Dictionary:
	var game = menu.get_parent()
	while game != null and not game.has_method("get_player_appearance_base"): game = game.get_parent()
	var country := Countries.from_kit(game.player_appearance.resolve(game.get_player_appearance_base()))
	return {"id":"player", "name":game.player_display_name, "country":country, "profile":0, "is_player":true}

func refresh() -> void:
	clear_body()
	back_button.text = "← Omnium" if editing and not manager.state.active.is_empty() else ("← Deelnemersbron" if editing else ("← Speelinstellingen" if choosing_startlist and manager.state.active.is_empty() else ("← Toernooien" if opened else "← Hoofdmenu")))
	manager.check_deadline(int(Time.get_unix_time_from_system()))
	if not opened:
		var tile = preload("res://omnium/omnium_tile.gd").new()
		tile.menu = menu; tile.manager = manager
		tile.pressed.connect(func(): opened = true; refresh())
		body.add_child(tile)
		return
	if editing: render_editor(); return
	if not manager.clock_warning.is_empty(): body.add_child(menu.label(manager.clock_warning, 20))
	if not manager.state.active.is_empty():
		preload("res://omnium/omnium_details.gd").new().render(self)
		return
	if not choosing_startlist: render_setup(); return
	body.add_child(menu.label("Startlijst aanmaken · kies je deelnemersbron", 26))
	if not draft.catalog.load_catalog(): body.add_child(menu.label(draft.catalog.error, 20)); return
	for category in ["men", "women", "mixed"]:
		button("Willekeurige lijst · " + {"men":"mannen", "women":"vrouwen", "mixed":"gemengd"}[category], generate.bind(category))
	button("Zelf samenstellen", manual)
	for tournament in manager.state.archive:
		button("Deelnemers kopiëren · " + String(tournament.id), copy_previous.bind(tournament))

func generate(category: String) -> void:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	draft.riders = draft.catalog.generate(player(), 24, category, rng)
	editing = true; refresh()

func manual() -> void:
	draft.riders = [player()]; editing = true; refresh()

func copy_previous(tournament: Dictionary) -> void:
	var chosen_format: String = draft.format_id
	var chosen_strength: float = draft.strength
	draft.copy_from(tournament, player())
	draft.format_id = chosen_format; draft.strength = chosen_strength
	editing = true; refresh()

func edit_active() -> void:
	if not draft.catalog.load_catalog(): return
	draft.copy_from(manager.state.active, player()); editing = true; refresh()

func render_editor() -> void:
	body.add_child(menu.label("Deelnemers bevestigen · %d/24" % draft.riders.size(), 26))
	for i in range(draft.riders.size()):
		var entry: Dictionary = draft.riders[i]
		var row := HBoxContainer.new(); body.add_child(row)
		if i == 0:
			row.add_child(menu.label("Speler · " + String(entry.name) + " · " + String(entry.country), 20))
			continue
		var card = preload("res://rider_passport.gd").new()
		card.entry = entry; card.compact = true
		if i > 0: card.selected.connect(func(_entry): open_picker(i))
		row.add_child(card)
		row.add_child(menu.label(String(entry.get("category", "speler")), 18))
		if i > 0:
			var remove_button := button("Verwijderen", func(): draft.remove(i); refresh(), row)
			remove_button.disabled = draft.riders.size() <= 12
	var add_button := button("Renner toevoegen", open_picker.bind(-1))
	add_button.disabled = draft.riders.size() >= 24
	message = menu.label("", 18); body.add_child(message)
	var confirm := button("Startlijst bevestigen", confirm_draft)
	confirm.disabled = draft.riders.size() < 12 or draft.riders.size() > 24
	button("Annuleren", go_back)

func open_picker(slot: int) -> void:
	if is_instance_valid(picker_layer): return
	var picker = preload("res://rider_picker.gd").new()
	picker.entries = draft.catalog.candidates(draft.riders, "mixed", slot)
	picker_layer = CanvasLayer.new(); picker_layer.layer = 30
	picker.layer = picker_layer
	get_tree().root.add_child(picker_layer)
	picker.selected.connect(func(entry):
		if slot < 0: draft.add(entry)
		else: draft.replace(slot, entry)
		refresh())
	picker_layer.add_child(picker)

func confirm_draft() -> void:
	var now := int(Time.get_unix_time_from_system())
	var success: bool
	if manager.state.active.is_empty(): success = manager.create(draft.riders, draft.format_id, draft.strength, now)
	else: success = manager.update_setup(draft.riders, draft.format_id, draft.strength, now)
	if success: editing = false; choosing_startlist = false; refresh()
	else: message.text = manager.error if not manager.error.is_empty() else "Controleer deelnemers, landen en format."

func confirm_stop() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Omnium stoppen en archiveren? Hervatten is daarna niet mogelijk."
	dialog.confirmed.connect(func(): manager.archive("stopped", int(Time.get_unix_time_from_system())); refresh())
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog); dialog.popup_centered()

func go_back() -> void:
	if is_instance_valid(picker_layer): picker_layer.queue_free(); return
	if editing: editing = false
	elif choosing_startlist and manager.state.active.is_empty(): choosing_startlist = false
	elif opened: opened = false
	else: menu.show_hub(); return
	refresh()
	back_button.grab_focus.call_deferred()

func handle_navigation(key: String) -> bool:
	if is_instance_valid(picker_layer):
		for child in picker_layer.get_children():
			if child.has_method("bridge_action"): child.bridge_action(key)
		return true
	if key == "B": go_back(); return true
	return false

func render_setup() -> void:
	body.add_child(menu.label("Nieuw omnium · speelinstellingen", 28))
	body.add_child(menu.label("Kies je format en de sterkte van je tegenstanders.", 20))
	var formats := OptionButton.new()
	for title in ["Verkort", "Mannenafstanden", "Vrouwenafstanden"]: formats.add_item(title)
	formats.select(["short", "men", "women"].find(draft.format_id))
	formats.item_selected.connect(func(index): draft.format_id = ["short", "men", "women"][index])
	body.add_child(formats)
	var strength := SpinBox.new(); strength.min_value = 40; strength.max_value = 120; strength.step = 5; strength.value = draft.strength
	strength.prefix = "AI-sterkte "; strength.suffix = "%"
	strength.value_changed.connect(func(value): draft.strength = value); body.add_child(strength)

	button("Verder · startlijst aanmaken →", func(): choosing_startlist = true; refresh())
