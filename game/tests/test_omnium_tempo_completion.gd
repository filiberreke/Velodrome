extends SceneTree
const Manager := preload("res://omnium/omnium_manager.gd")
const Tempo := preload("res://omnium/omnium_tempo_controller.gd")
class Race extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _record_ai_performances() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
	func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var manager := Manager.new(); manager.store.folder = "user://omnium_tempo_completion_" + str(Time.get_ticks_usec())
	var riders: Array = []; var ids: Array = []
	for i in range(8):
		var id := "rider_" + str(i); ids.append(id)
		riders.append({"id":id,"name":id,"country":str(i),"profile":0 if i == 0 else 1,"is_player":i == 0})
	var now := int(Time.get_unix_time_from_system())
	assert(manager.create(riders,"short",80,now))
	var attempt := manager.begin_attempt(now)
	assert(manager.finish_attempt(attempt.id,{"discipline":"scratch","order":ids},{},now))
	var game := Race.new(); root.add_child(game)
	game.omnium_race = Tempo.new(); game.omnium_race.manager = manager
	game.omnium_race.attempt = manager.begin_attempt(now)
	game.omnium_race.context = manager.state.active.duplicate(true)
	game.race_mode = 8; game.rider_count = 8; game.race_laps = 20
	game._configure_peloton(); game._finish_neutral_start()
	game.clock = 100; game.finished = true; game.finish_times[0] = 99; game.distances[0] = 5000
	var ordering: Array = []
	for i in range(8): ordering.append(i)
	for lap in range(5,20):
		game.tempo_rules.sprints.append({"lap":lap,"seconds":float(lap),"order":ordering.duplicate(),"times":[1,2,3,4,5,6,7,8],"awards":[1,0,0,0,0,0,0,0]})
	game.tempo_rules.points[0] = 16
	game.tempo_rules.sprints.append({"lap":20,"seconds":99.0,"order":[0],"times":[99.0],"awards":[1]})
	game.tempo_rules.finish_clock = 99; game.tempo_rules.last_sprint_clock = 99
	for i in range(1,8):
		game.distances[i] = 4760 + i; game.speeds[i] = 12; game.tempo_rules.credits[i] = -1
	game.finish_overlay = ColorRect.new(); game.add_child(game.finish_overlay)
	game._refresh_fullscreen_results()
	assert(game.results_completion.active)
	for frame in range(5000):
		await process_frame
		if not game.results_completion.active: break
	assert(game._all_riders_finished() and game.tempo_rules.complete())
	assert(game.omnium_race.committed and manager.state.active.results.size() == 2)
	assert(manager.state.active.results[1].sprints.size() == 16)
	assert(manager.state.active.results[1].sprints[-1].order.size() == 8)
	assert(manager.state.active.energy.size() == 7)
	assert(game.finish_times[0] == 99 and game.distances[0] == 5000 and game.tempo_rules.points[0] == 16)
	game.omnium_race.clear(); game.free()
	for suffix in ["state.json", "state.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.store.folder))
	print("PASS Omnium Tempo CPU completion commits full result, sprint archive and AI Wprime exactly once")
	quit()
