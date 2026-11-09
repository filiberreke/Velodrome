extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _register_performance() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run_test")
func settle() -> void:
	for i in range(3):await process_frame
func run_test() -> void:
	var g := Game.new();root.add_child(g);g.set_physics_process(false)
	await settle()
	var menu=g.setup_panel
	# Transitioning from points used to leave its ten-lap minimum behind.
	menu.select_mode(3);menu.select_mode(6)
	check(not menu.start_button.disabled and menu.race_settings.visible,"Keirin is playable")
	check(menu.count_input.value==6 and menu.laps_input.value==6,"Fixed six riders/six laps after mode switch")
	check(not menu.count_input.visible and not menu.laps_input.visible and menu.keirin_derny.visible,"Keirin offers derny tempo, not incompatible field/lap controls")
	menu.keirin_derny.value=70
	menu.start_button.pressed.emit();await settle()
	check(menu.page==5 and menu.startlist_page.lineup.size()==5 and menu.startlist_page.can_start(),"Five distinct selectable opponents")
	menu.startlist_page.start_button.pressed.emit();await settle()
	check(g.race_mode==3 and g.rider_count==6 and g.race_laps==6,"Keirin does not accidentally start scratch")
	check(g.keirin.percent==70 and g.startlist_mode==3,"Menu tempo and selected opponents reach race")
	check(g.keirin.pilot.animator!=null and g.keirin.pilot.animator.has_animation("DP_DernyLookBack"),"Actual derny model and look animation loaded")
	g.broadcast_intro.finish();g._begin_riding()
	g.running=true
	check(g.keirin.phase=="PACED","Normal start flow releases the derny")
	var drawn: int = g.player_lane
	g._steer_player(1);check(g.player_lane==drawn,"Paced formation cannot be steered apart")
	while g.keirin.phase=="PACED":g._update_race(.1)
	check(absf(g.keirin.exit_speed_kmh-45)<.001,"70 percent releases at 45 km/h")
	check(g.keirin.pilot.gesture_count.speed_up==0,"No raised hand")
	g._steer_player(-1);check(g.player_lane==0,"Inside racing corridor selectable")
	g._steer_player(1);check(g.player_lane==2,"Outside racing corridor selectable")
	var release_speed: float = g.speeds[0]
	g.watts=0
	for i in range(30):g._update_race(.1);g._update_coasting(.1)
	check(g.speeds[0]<release_speed,"Free phase respects zero human power; no continued derny assistance")
	g.watts=1000
	while g.keirin.time<240 and not g._all_riders_finished():g._update_race(.1);g._update_coasting(.1)
	check(g._all_riders_finished(),"Player and selected mixed-profile opponents all finish")
	check(g._winner_index()>=0,"Native classification available")
	g._refresh_fullscreen_results()
	check(g.finish_heading.text.contains("Keirin"),"Keirin-specific results heading")
	for i in range(6000):g._update_coasting(.05)
	for i in range(6):
		check(int(g.elimination_exit[i].stage)==3,"Finisher reaches real box route")
		check(Vector3(g.elimination_exit[i].position).distance_to(Vector3(g.elimination_exit[i].target))<.1,"Box coordinates reached")
	g.finish_overlay.show();g._update_visuals(.1)
	for i in range(6):check(g.bikes[i].position.distance_to(Vector3(g.elimination_exit[i].position)+Vector3.UP*.09)<.001,"Visible riders keep moving to their boxes while results are open")
	# Restart keeps the opponent identities and derny choice.
	var selected: Array[Dictionary] = g.rider_identities.duplicate(true)
	g._restart_same_race()
	check(g.race_mode==3 and g.keirin.percent==70 and g.rider_identities==selected,"Restart preserves keirin roster and tempo")
	menu.select_mode(0);check(not menu.keirin_derny.visible,"Derny-only control is hidden in scratch")
	g.free();print("KEIRIN_FLOW failures=",failures);quit(0 if failures==0 else 1)
