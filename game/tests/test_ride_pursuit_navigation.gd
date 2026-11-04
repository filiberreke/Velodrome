extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port:int=UDP_PORT)->Error: return super._bind_bridge(0)
	func _save_recording(_reason:String)->void: pass
var g
var flow
var failures:=0
func _initialize()->void: call_deferred("run_test")
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func press(key:String)->void:
	g._process_bridge_packet({"type":"controller_button","source_button":key,"pressed":true})
	g._process_bridge_packet({"type":"button","button":key,"source_button":key})
	g._process_bridge_packet({"type":"controller_button","source_button":key,"pressed":false})
	await process_frame
func focus()->Control: return root.gui_get_focus_owner()
func seek(target:Control)->void:
	for i in range(20):
		if focus()==target: return
		await press("DOWN")
	check(false,"Controller cannot reach "+target.name)
func clean_replays()->void:
	var directory:="user://test_ride_pursuit_replays"
	var folder:=DirAccess.open(directory)
	if folder==null:return
	for filename in folder.get_files():DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
func run_test()->void:
	clean_replays()
	g=Game.new();root.add_child(g);g.set_physics_process(false)
	await process_frame;await process_frame
	g.get_node("GameSettings").always_show_intro=true
	var menu=g.setup_panel
	flow=menu.pursuit_flow
	flow.preferences_path="user://test_ride_pursuit_selection.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	# Enter individual pursuit from the gallery using only Ride buttons.
	await press("RIGHT");await press("A")
	check(menu.selected==1 and flow.step==1,"Ride enters individual pursuit")
	await seek(flow.distance_buttons[0])
	await press("RIGHT");await press("A")
	check(menu.pursuit_options.distance_m()==4000,"Ride selects 4 km")
	await seek(flow.proceed_button);await press("A")
	check(flow.step==2 and g.start_state=="SETUP","Ride reaches opponent step")
	await seek(flow.left_arrow)
	var before:int=flow.current
	await press("RIGHT")
	check(flow.current==posmod(before+1,flow.candidates.size()),"Carousel row changes opponent")
	await seek(flow.strength_input.get_line_edit())
	var strength:float=flow.strength_input.value
	await press("RIGHT")
	check(flow.strength_input.value==minf(150,strength+5),"Strength row adjusts percentage")
	await press("DOWN")
	check(focus()!=flow.strength_input.get_line_edit(),"Ride can leave percentage field")
	await seek(flow.ai_tab);await press("RIGHT");await press("A")
	check(flow.kind==1 and flow.candidates.is_empty() and flow.proceed_button.disabled,"Own-prestation tab and empty state are reachable")
	await press("LEFT");await press("A")
	check(flow.kind==0 and flow.can_start(),"Ride can return from empty own rides to AI")
	await seek(flow.proceed_button);await press("A")
	check(g.start_state=="INTRO" and g.race_mode==4,"Focused start launches individual pursuit")
	await press("B")
	# Saved opponents use the same focus navigation and retain the chosen replay.
	var library=menu.pursuit_options.library
	library.directory="user://test_ride_pursuit_replays"
	var samples:Array[Dictionary]=[{"t":0.,"d":0.,"p":200.,"lane":1.18},{"t":300.,"d":4000.,"p":250.,"lane":1.18}]
	for i in range(2):
		var trace:Array[Dictionary]=samples.duplicate(true)
		trace[1].t=300.+i
		var saved:Dictionary=library.save("Controller replay "+str(i),4000,300.+i,trace)
		check(saved.has("id"),"Saved-opponent fixture is valid")
	await press("A");await press("A")
	await seek(flow.ai_tab);await press("RIGHT");await press("A")
	check(flow.kind==1 and flow.candidates.size()==2,"Own rides can be selected with Ride")
	await seek(flow.left_arrow)
	var replay_index:int=flow.current
	await press("RIGHT")
	check(flow.current==posmod(replay_index+1,2),"Ride changes saved opponent")
	await seek(flow.proceed_button);await press("A")
	check(g.start_state=="INTRO" and not g.pursuit_replay.is_empty(),"Ride starts the selected saved opponent")
	await press("B")
	# Team settings: all visible options must be reachable without focus injection.
	await press("RIGHT");await press("A")
	check(menu.selected==2 and flow.step==1,"Ride enters team pursuit")
	await seek(flow.size_buttons[0]);await press("RIGHT");await press("A")
	check(menu.team_options.team_size()==4,"Ride sets four-rider team")
	await seek(flow.advanced_toggle);await press("A")
	check(flow.advanced.visible,"Ride opens team settings")
	await seek(flow.resistance);await press("RIGHT")
	check(menu.team_options.resistance_mode()=="ERG","Ride selects ERG")
	for i in range(3):
		await seek(flow.factor_controls[i].get_line_edit())
		var value:float=flow.factor_controls[i].value
		await press("LEFT")
		check(flow.factor_controls[i].value==maxf(10,value-5),"Ride sets wheel-power factor "+str(i))
	await seek(flow.demo_input.get_line_edit())
	var demo:float=flow.demo_input.value
	await press("RIGHT")
	check(flow.demo_input.value==minf(900,demo+25),"Ride adjusts demo power")
	await seek(flow.proceed_button);await press("A")
	check(flow.step==2,"Ride continues from advanced team options")
	await seek(flow.left_arrow);await press("RIGHT")
	await seek(flow.strength_input.get_line_edit());await press("LEFT")
	await seek(flow.proceed_button);await press("A")
	check(g.start_state=="INTRO" and g.race_mode==5 and g.team_size==4 and g.team_resistance_mode=="ERG","Ride starts configured team pursuit")
	await press("B")
	# Disabled, hidden controls cannot trap a live trainer user.
	menu.update_bridge_status(true,true,false)
	menu.select_mode(2)
	await process_frame
	await seek(flow.advanced_toggle);await press("A")
	await seek(flow.size_buttons[1]);await press("LEFT");await press("A")
	check(menu.team_options.team_size()==3 and not flow.advanced_rows[2].visible and not flow.demo_row.visible,"Three-rider LIVE setup hides unavailable settings")
	await seek(flow.factor_controls[1].get_line_edit())
	await press("DOWN")
	check(focus()==flow.proceed_button,"Hidden third factor and demo power are skipped")
	await press("A");await press("B")
	check(flow.step==1 and g.start_state=="SETUP","B returns from opponent selection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	clean_replays()
	g.free();await process_frame
	print("RIDE_PURSUIT_NAVIGATION failures=%d"%failures)
	quit(0 if failures==0 else 1)
