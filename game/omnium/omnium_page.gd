extends VBoxContainer
const Style := preload("res://menu_theme.gd")
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
var result_index := -1
var archived_tournament := {}
var archive_list := false
var archive_view = preload("res://omnium/omnium_archive.gd").new()
var choosing_startlist := false
var picker_layer: CanvasLayer
# Keep signal receivers alive while the detail controls are in use.
var details = preload("res://omnium/omnium_details.gd").new()

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	back_button = Button.new(); back_button.text = "RACE_MENU_MAIN_MENU"
	back_button.pressed.connect(go_back); add_child(back_button)
	manager.load_session(int(Time.get_unix_time_from_system()))
	draft.venue_id = menu.venue_id
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
	if country.is_empty(): country = String(Countries.roster(game).player)
	return {"id":"player", "name":game.player_display_name, "country":country, "profile":0, "is_player":true}

func refresh() -> void:
	clear_body()
	back_button.text = String(TranslationServer.translate("RACE_MENU_OMNIUM")) if editing and not manager.state.active.is_empty() else (String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_RIDER_SOURCE")) if editing else (String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_GAME_SETTINGS")) if choosing_startlist and manager.state.active.is_empty() else (String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_TOURNAMENTS")) if opened else String(TranslationServer.translate("RACE_MENU_MAIN_MENU")))))
	manager.check_deadline(int(Time.get_unix_time_from_system()))
	var viewing: Dictionary = manager.state.active if archived_tournament.is_empty() else archived_tournament
	if viewing.is_empty(): result_index = -1
	if result_index >= 0 and result_index < viewing.results.size():
		back_button.text = "RACE_MENU_OMNIUM"
		preload("res://omnium/omnium_result_page.gd").render(self,viewing,result_index)
		return
	if not archived_tournament.is_empty():
		back_button.text = "OMNIUM_OMNIUM_PAGE_PAST_TOURNAMENTS"; archive_view.render(self); return
	if archive_list:
		back_button.text = "OMNIUM_OMNIUM_PAGE_TOURNAMENTS"; archive_view.render_list(self); return
	if not opened:
		var tile = preload("res://omnium/omnium_tile.gd").new()
		tile.menu = menu; tile.manager = manager
		tile.pressed.connect(func(): opened = true; refresh())
		body.add_child(tile)
		var archive_tile := button(String(TranslationServer.translate("OMNIUM_PAST_TOURNAMENTS_D_SAVED")) % manager.state.archive.size(), open_archive_list)
		archive_tile.custom_minimum_size.y = 88
		archive_tile.add_theme_font_size_override("font_size",24)
		return
	if editing: render_editor(); return
	if not manager.clock_warning.is_empty(): body.add_child(menu.label(manager.clock_warning, 20))
	if not manager.state.active.is_empty():
		details.render(self)
		return
	if not choosing_startlist: render_setup(); return
	body.add_child(menu.label("OMNIUM_OMNIUM_PAGE_CREATE_START_LIST_CHOOSE_YOUR_RIDER_SOURCE", 26))
	if not draft.catalog.load_catalog(): body.add_child(menu.label(draft.catalog.error, 20)); return
	for category in ["men", "women", "mixed"]:
		button(String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_RANDOM_LIST")) + {"men":"mannen", "women":"vrouwen", "mixed":"gemengd"}[category], generate.bind(category))
	button("OMNIUM_OMNIUM_PAGE_BUILD_YOUR_OWN", manual)
	for tournament in manager.state.archive:
		button(String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_COPY_RIDERS")) + String(tournament.id), copy_previous.bind(tournament))

func generate(category: String) -> void:
	if roster_locked(): return
	var rng := RandomNumberGenerator.new(); rng.randomize()
	draft.riders = draft.catalog.generate(player(), 24, category, rng)
	editing = true; refresh()

func manual() -> void:
	if roster_locked(): return
	draft.riders = [player()]; editing = true; refresh()

func copy_previous(tournament: Dictionary) -> void:
	if roster_locked(): return
	var chosen_format: String = draft.format_id
	var chosen_strength: float = draft.strength
	var chosen_venue: String = draft.venue_id
	draft.copy_from(tournament, player())
	draft.format_id = chosen_format; draft.strength = chosen_strength; draft.venue_id = chosen_venue
	editing = true; refresh()

func roster_locked() -> bool:
	return not manager.state.active.is_empty() and int(manager.state.active.started) > 0

func edit_active() -> void:
	if roster_locked():
		draft.riders.assign(manager.state.active.riders.duplicate(true))
	else:
		if not draft.catalog.load_catalog(): return
		draft.copy_from(manager.state.active, player())
	editing = true; refresh()

func render_editor() -> void:
	var locked := roster_locked()
	body.add_child(menu.label(String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_START_LIST_PLAYER_D_23_OPPONENTS_D_24_TOTAL")) % [draft.opponent_count(), draft.riders.size()], 26))
	if locked:
		body.add_child(menu.label("OMNIUM_OMNIUM_PAGE_THE_START_LIST_HAS_BEEN_LOCKED_SINCE_THE_START_OF_THE_SCRATCH_RACE", 18))
	else:
		var tools := HBoxContainer.new(); tools.add_theme_constant_override("separation", 12)
		body.add_child(tools)
		button("OMNIUM_OMNIUM_PAGE_REGENERATE_RANDOM_MEN_S_LIST", confirm_roster_change.bind(generate.bind("men"), false), tools)
		button("OMNIUM_OMNIUM_PAGE_REGENERATE_RANDOM_WOMEN_S_LIST", confirm_roster_change.bind(generate.bind("women"), false), tools)
		var previous := OptionButton.new()
		previous.custom_minimum_size.y = 46
		previous.add_item("OMNIUM_OMNIUM_PAGE_PREVIOUS_TOURNAMENT")
		previous.set_item_disabled(0, true)
		for tournament in manager.state.archive: previous.add_item(String(tournament.id))
		previous.disabled = manager.state.archive.is_empty()
		previous.item_selected.connect(func(index):
			previous.select(0)
			if index > 0: confirm_roster_change(copy_previous.bind(manager.state.archive[index - 1]), false))
		tools.add_child(previous)
		button("OMNIUM_OMNIUM_PAGE_CLEAR_LIST", confirm_roster_change.bind(manual, true), tools)
	var grid := GridContainer.new(); grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for i in range(draft.riders.size()):
		var entry: Dictionary = draft.riders[i]
		var tile := VBoxContainer.new(); grid.add_child(tile)
		if entry.get("is_player", false):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(280, 216)
			panel.add_theme_stylebox_override("panel", Style.panel(Style.PALE, Style.LINE, 12, 12))
			tile.add_child(panel)
			var copy := VBoxContainer.new(); panel.add_child(copy)
			copy.add_child(menu.label("OMNIUM_OMNIUM_PAGE_PLAYER", 18))
			copy.add_child(menu.label(String(entry.name), 22))
			var flag := TextureRect.new()
			flag.texture = preload("res://national_flags.gd").texture(String(entry.country))
			flag.custom_minimum_size = Vector2(60, 40)
			flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			copy.add_child(flag)
			continue
		var card = preload("res://rider_passport.gd").new()
		card.entry = entry; card.compact = true; card.interactive = not locked
		if not locked: card.selected.connect(func(_entry): open_picker(i))
		tile.add_child(card)
		if not locked: button("WORKOUT_EDITOR_DELETE", func(): draft.remove(i); refresh(), tile)
	if not locked:
		var add_button := button("OMNIUM_OMNIUM_PAGE_ADD_RIDER", open_picker.bind(-1))
		add_button.disabled = not draft.can_add()
		message = menu.label(String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_AT_LEAST_8_RIDERS_REQUIRED_PLAYER_7_OPPONENTS")) if draft.riders.size() < 8 else "", 18)
		body.add_child(message)
		var confirm := button("OMNIUM_OMNIUM_PAGE_CONFIRM_START_LIST", confirm_draft)
		confirm.disabled = draft.riders.size() < 8 or draft.riders.size() > 24

func open_picker(slot: int) -> void:
	if roster_locked(): return
	if slot < 0 and not draft.can_add(): return
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
	if manager.state.active.is_empty(): success = manager.create(draft.riders, draft.format_id, draft.strength, now, draft.venue_id)
	else: success = manager.update_setup(draft.riders, draft.format_id, draft.strength, now, draft.venue_id)
	if success: editing = false; choosing_startlist = false; refresh()
	else: message.text = manager.error if not manager.error.is_empty() else String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_CHECK_RIDERS_COUNTRIES_AND_FORMAT"))

func confirm_stop() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_STOP_AND_ARCHIVE_THE_OMNIUM_IT_CANNOT_BE_RESUMED_AFTERWARDS"))
	dialog.confirmed.connect(func(): manager.archive("stopped", int(Time.get_unix_time_from_system())); refresh())
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog); dialog.popup_centered()

func go_back() -> void:
	if is_instance_valid(picker_layer): picker_layer.queue_free(); return
	if result_index >= 0: result_index = -1
	elif not archived_tournament.is_empty(): archived_tournament = {}; archive_list = true
	elif archive_list: archive_list = false; opened = false
	elif editing: editing = false
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
	body.add_child(menu.label("OMNIUM_OMNIUM_PAGE_NEW_OMNIUM_GAME_SETTINGS", 28))
	body.add_child(menu.label("OMNIUM_OMNIUM_PAGE_CHOOSE_YOUR_FORMAT_AND_THE_STRENGTH_OF_YOUR_OPPONENTS", 20))
	var formats := OptionButton.new()
	for title in [String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_SHORTENED")), String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_MEN_S_DISTANCES")), String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_WOMEN_S_DISTANCES"))]: formats.add_item(title)
	formats.select(["short", "men", "women"].find(draft.format_id))
	formats.item_selected.connect(func(index): draft.format_id = ["short", "men", "women"][index])
	body.add_child(formats)
	var strength := SpinBox.new(); strength.min_value = 40; strength.max_value = 120; strength.step = 5; strength.value = draft.strength
	strength.prefix = String(TranslationServer.translate("OMNIUM_AI_STRENGTH_PREFIX")); strength.suffix = "%"
	strength.value_changed.connect(func(value): draft.strength = value); body.add_child(strength)

	var venues := preload("res://venues/venue_selector.gd").new()
	venues.tile_size = Vector2(360, 244)
	venues.selected_id = draft.venue_id
	body.add_child(venues)
	venues.selected.connect(func(id): draft.venue_id = id)
	button("OMNIUM_OMNIUM_PAGE_CONTINUE_CREATE_START_LIST", func(): choosing_startlist = true; refresh())

func confirm_roster_change(action: Callable, clear_list: bool) -> void:
	if roster_locked(): return
	var dialog := ConfirmationDialog.new()
	dialog.title = String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_CLEAR_START_LIST")) if clear_list else String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_REPLACE_START_LIST"))
	dialog.dialog_text = String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_ARE_YOU_SURE_YOU_WANT_TO_CLEAR_THE_CURRENT_START_LIST")) if clear_list else String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_ARE_YOU_SURE_YOU_WANT_TO_REPLACE_THE_CURRENT_START_LIST"))
	dialog.ok_button_text = String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_CLEAR")) if clear_list else String(TranslationServer.translate("OMNIUM_OMNIUM_PAGE_REPLACE"))
	dialog.cancel_button_text = "WORKOUT_EDITOR_CANCEL"
	dialog.confirmed.connect(func():
		if not roster_locked(): action.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func open_archive_list() -> void:
	archive_list = true; opened = false; archived_tournament = {}; result_index = -1; refresh()
func open_archive(tournament: Dictionary) -> void:
	archived_tournament = tournament.duplicate(true); result_index = -1; archive_view.sort_column = 5; archive_view.descending = true; refresh()
func open_result(index: int) -> void:
	result_index = index; refresh(); body.get_parent().set_deferred("scroll_vertical",0)
