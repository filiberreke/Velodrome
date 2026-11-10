extends SceneTree
const Records:=preload("res://pursuit_records.gd")
class Screen extends "res://main.gd":
	func _bind_bridge(_port:int=UDP_PORT)->Error:return super._bind_bridge(0)
	func _save_recording(_reason:String)->void:pass
var failures:=0
func _initialize()->void:call_deferred("run_test")
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func clean_test_records()->void:
	for directory in ["user://test_pursuit_flow_individual","user://test_pursuit_flow_team"]:
		var folder:=DirAccess.open(directory)
		if folder!=null:
			for filename in folder.get_files():DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func run_test()->void:
	clean_test_records()
	var game:=Screen.new();root.add_child(game);game.set_physics_process(false)
	await process_frame;await process_frame
	var menu=game.setup_panel
	var flow=menu.pursuit_flow
	flow.preferences_path="user://config/test_opponent_selection.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	menu.select_mode(1)
	check(menu.page==2 and flow.distance_page.visible and not flow.opponent_page.visible,"First page contains only match selection")
	game._confirm_start()
	check(game.start_state=="SETUP","Cannot skip the opponent selection step")
	flow.select_distance(4000);flow.next_step()
	await process_frame;await process_frame
	check(menu.page==4 and flow.current_card.entry.id==menu.pursuit_options.selected_ai().id,"Second page shows the actual current rider card")
	check(flow.proceed_button.get_global_rect().end.y<=1080.1,"Two-step navigation fits the reference screen")
	flow.cycle(1)
	var chosen:String=menu.pursuit_options.selected_ai().id
	flow.strength_input.value=100
	game._confirm_start()
	check(game.race_mode==4 and game.rider_identities[1].id==chosen and game.pursuit_pacer.difficulty_percent==100,"Selected rider and percentage reach the actual opponent")
	check(is_equal_approx(game.pursuit_pacer.power(0),minf(game.pursuit_pacer.power_limit_w,game.pursuit_pacer.target_w)),"AI strength scales capacity once, without multiplying target power again")
	game.broadcast_intro.finish();game._reset();menu.select_mode(1);flow.next_step()
	check(menu.pursuit_options.selected_ai().id==chosen and flow.strength_input.value==100,"Last opponent and percentage restore from saved preferences")
	flow.back();flow.select_distance(1000);flow.next_step()
	menu.pursuit_options.library.directory="user://test_pursuit_flow_individual"
	var samples:Array[Dictionary]=[{"t":0.,"d":0.,"p":200.,"lane":1.18},{"t":10.,"d":1000.,"p":400.,"lane":1.18}]
	var saved:Dictionary=menu.pursuit_options.library.save("Mijn eerdere rit",1000,10,samples,{"finished_local":"2026-11-01 10:20:30"})
	check(saved.has("id"),"Completed own ride can be selected")
	flow.select_kind(1)
	check(flow.candidates.size()==1 and flow.current_card.replay and menu.pursuit_options.selected_ride_id()==saved.id,"Own achievements use their own carousel profile")
	check(flow.current_card.data.finished_local=="2026-11-01 10:20:30" and Records.average_power(flow.current_card.data)==300,"Own profile contains actual date, time and average watts")
	flow.strength_input.value=120
	game._confirm_start();game.broadcast_intro.finish()
	check(is_equal_approx(game.pursuit_replay.time_s,10./1.2),"Replay percentage changes tempo")
	check(menu.pursuit_options.library.load_ride(saved.id).time_s==10,"Saved personal achievement stays unchanged")
	game.start_state="RACING";game.running=true
	while game.finish_times[1]<0 and game.clock<20:game.clock+=.1;game._update_race(.1)
	check(is_equal_approx(game.finish_times[1],10./1.2),"Replay actually finishes at its scaled target time")
	game._reset();menu.select_mode(2);flow.select_size(4);flow.select_distance(1000);flow.next_step()
	check(flow.current_card.is_team and flow.current_card.team_size==4,"Team pursuit shows a matching four-rider national profile")
	flow.cycle(1);var country:String=menu.team_options.selected_ai().country
	flow.strength_input.value=90
	game._confirm_start()
	check(game.team_size==4 and game.pursuit_opponent_country==country and game.team_race.pacer.difficulty_percent==90,"National team and strength are passed into team pursuit")
	game.broadcast_intro.finish();game._reset();menu.select_mode(2);flow.select_size(4);flow.next_step()
	check(menu.team_options.selected_ai().country==country and flow.strength_input.value==90,"Team opponent persists separately")
	menu.team_options.library.directory="user://test_pursuit_flow_team"
	var team_saved:Dictionary=menu.team_options.library.save("Vorige ploegprestatie",1000,10,samples,{"finished_local":"2026-11-01 11:30:00"})
	flow.select_kind(1)
	check(flow.candidates.size()==1 and flow.current_card.is_team and flow.current_card.replay,"Team achievements are filtered for team size and distance")
	flow.strength_input.value=50;game._confirm_start();game.broadcast_intro.finish()
	check(game.team_race.replay.time_s==20 and menu.team_options.library.load_ride(team_saved.id).time_s==10,"Team replay scales a copy and preserves the original")
	var original:Dictionary=menu.team_options.library.load_ride(team_saved.id)
	var exact:Dictionary=Records.scaled_replay(original,100)
	check(exact.time_s==original.time_s and exact.samples==original.samples,"100 percent preserves the original replay timeline")
	var irregular:Dictionary={"time_s":10.,"samples":[{"t":0.,"p":100.},{"t":2.,"p":300.},{"t":10.,"p":500.}]}
	check(Records.average_power(irregular)==360,"Average power uses time weighting for irregular samples")
	game._reset();menu.select_mode(2);flow.select_size(4);flow.select_distance(1000);menu.team_options.library.directory="user://test_pursuit_flow_team";flow.next_step();flow.select_kind(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.team_options.library.directory.path_join(String(team_saved.id)+".json")))
	game._confirm_start()
	check(game.start_state=="SETUP" and flow.candidates.is_empty() and flow.proceed_button.disabled and flow.status.visible,"Deleted own achievement leaves a visible error and cannot start")
	clean_test_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	game.free()
	print("PURSUIT_FLOW failures=",failures)
	quit(0 if failures==0 else 1)
