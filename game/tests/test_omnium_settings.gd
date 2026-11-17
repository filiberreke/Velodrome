extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Details := preload("res://omnium/omnium_details.gd")
const Menu := preload("res://race_menu.gd")
const Formats := preload("res://omnium/omnium_formats.gd")
# Small UI host: exercise actual settings signals without the 3D world.
class Host extends VBoxContainer:
	var manager = Manager.new()
	var menu = Menu.new()
	var body := VBoxContainer.new()
	var details = Details.new()
	var refreshes := 0
	func refresh() -> void:
		refreshes += 1
	func _ready() -> void: add_child(body)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.manager.store.folder = "user://omnium_settings_test_" + str(Time.get_ticks_usec())
	var riders: Array = []
	for i in range(12): riders.append({"id":str(i), "country":str(i), "is_player":i == 0})
	assert(host.manager.create(riders, "short", 80, 1000000))
	host.details.page = host; host.details.menu = host.menu
	host.details.active = host.manager.state.active
	host.details.render_settings()
	var picker: OptionButton = find_type(host.body, "OptionButton")
	var strength: SpinBox = find_type(host.body, "SpinBox")
	picker.item_selected.emit(1)
	await process_frame
	assert(host.refreshes == 1)
	assert(host.manager.state.active.format == "men")
	assert(Formats.race_laps(host.manager.state.active.format, "points", 12) == 100)
	strength.value = 95
	assert(host.manager.state.active.strength == 95)
	var restored := Manager.new()
	restored.store.folder = host.manager.store.folder
	assert(restored.load_session(int(Time.get_unix_time_from_system())))
	assert(restored.state.active.format == "men" and restored.state.active.strength == 95)
	picker.item_selected.emit(2)
	assert(host.manager.state.active.format == "women")
	assert(Formats.race_laps(host.manager.state.active.format, "points", 12) == 80)
	for suffix in ["state.json", "state.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(host.manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(host.manager.store.folder))
	host.menu.free(); host.queue_free()
	print("PASS omnium settings signals, format distances and persisted settings")
	quit()

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found != null: return found
	return null
