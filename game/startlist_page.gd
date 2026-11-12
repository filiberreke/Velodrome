extends VBoxContainer
## Opponent selection is a menu model; game configuration consumes a deep copy on start.
const MenuStyle := preload("res://menu_theme.gd")
var menu
var pool: Array[Dictionary] = []
var lineup: Array[Dictionary] = []
var remembered: Dictionary = {}
var grid: GridContainer
var summary: Label
var previous_button: Button
var start_button: Button
var active_picker: Control

func _ready() -> void:
	theme = MenuStyle.create()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	summary = menu.label("", 20, MenuStyle.MUTED)
	add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 14)
	add_child(navigation)
	previous_button = Button.new()
	previous_button.text = "← Wedstrijdinstellingen"
	previous_button.custom_minimum_size = Vector2(300, 54)
	previous_button.pressed.connect(back)
	navigation.add_child(previous_button)
	menu.place_back(previous_button, self)
	navigation.add_spacer(false)
	start_button = Button.new()
	start_button.text = "Start wedstrijd →"
	start_button.custom_minimum_size = Vector2(310, 54)
	MenuStyle.primary(start_button)
	start_button.pressed.connect(func() -> void:
		if can_start(): menu.start_requested.emit())
	navigation.add_child(start_button)
	hide()

func begin() -> void:
	pool.clear()
	# The game supplies configured identities and additional default reserve slots.
	var owner_node: Node = menu
	while owner_node != null:
		if owner_node.has_method("available_startlist_riders"):
			pool.assign(owner_node.available_startlist_riders())
			break
		owner_node = owner_node.get_parent()
	if pool.is_empty(): pool.assign(menu.pursuit_options.ai_entries)
	var old: Array = remembered.get(menu.selected, [])
	lineup.clear()
	for entry in old:
		for candidate in pool:
			if candidate.id == entry.id and not _chosen_ids().has(String(candidate.id)):
				lineup.append(candidate.duplicate(true))
				break
	var required := opponent_count()
	if lineup.size() > required: lineup.resize(required)
	for entry in pool:
		if lineup.size() >= required: break
		if not _chosen_ids().has(String(entry.id)): lineup.append(entry.duplicate(true))
	_save()
	_render()
	show()
	start_button.grab_focus.call_deferred()

func opponent_count() -> int:
	return (int(menu.elimination_count_picker.get_selected_id()) if menu.selected == 5 else int(menu.count_input.value)) - 1

func _chosen_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in lineup: ids.append(String(entry.id))
	return ids

func available_candidates() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var chosen := _chosen_ids()
	for entry in pool:
		if String(entry.id) not in chosen: available.append(entry)
	return available

func replace_opponent(slot: int, entry: Dictionary) -> bool:
	if slot < 0 or slot >= lineup.size(): return false
	for candidate in available_candidates():
		if candidate.id == entry.get("id", ""):
			lineup[slot] = candidate.duplicate(true)
			_save()
			_render()
			return true
	return false

func _save() -> void:
	remembered[menu.selected] = lineup.duplicate(true)

func can_start() -> bool:
	if menu.page != 5 or menu.selected not in [0,3,5,6]: return false
	if menu.bridge_unavailable or lineup.size() != opponent_count(): return false
	var seen: Array[String] = []
	for entry in lineup:
		var id := String(entry.get("id", ""))
		if id.is_empty() or id in seen: return false
		var found := false
		for candidate in pool:
			if candidate.id == id: found = true; break
		if not found: return false
		seen.append(id)
	return true

func _render() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	summary.text = "%s · Jij + %d tegenstanders · AI %d%%" % [menu.MODES[menu.selected].title, lineup.size(), int(menu.difficulty_slider.value)]
	for slot in range(lineup.size()):
		var card = preload("res://rider_passport.gd").new()
		card.entry = lineup[slot]
		card.compact = true
		card.selected.connect(func(_entry: Dictionary) -> void: open_picker(slot))
		grid.add_child(card)
	update_bridge()

func update_bridge() -> void:
	if start_button != null: start_button.disabled = not can_start()

func open_picker(slot: int) -> void:
	if is_instance_valid(active_picker): return
	var picker = preload("res://rider_picker.gd").new()
	picker.entries = available_candidates()
	active_picker = picker
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	picker.layer = overlay
	get_tree().root.add_child(overlay)
	overlay.tree_exited.connect(func() -> void: active_picker = null; start_button.grab_focus.call_deferred())
	picker.selected.connect(func(entry: Dictionary) -> void: replace_opponent(slot, entry))
	overlay.add_child(picker)

func back() -> void:
	menu.select_mode(menu.selected)

func bridge_action(value: String) -> void:
	if is_instance_valid(active_picker): active_picker.bridge_action(value); return
	if value == "B": back(); return
	var actions := {"LEFT":"ui_left", "RIGHT":"ui_right", "UP":"ui_up", "DOWN":"ui_down", "A":"ui_accept"}
	if not actions.has(value): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or (focus != previous_button and not is_ancestor_of(focus)): start_button.grab_focus()
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = actions[value]
		event.pressed = down
		get_viewport().push_input(event)
