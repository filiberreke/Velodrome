extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port:int=UDP_PORT)->Error:return super._bind_bridge(int(OS.get_cmdline_user_args()[0]))
	func _save_recording(_reason:String)->void:pass
var g
var failures:=0
func _initialize()->void:call_deferred("run_test")
func wait_for(marker:String,condition:Callable)->void:
	print("PURSUIT_FLOW_"+marker)
	var deadline:=Time.get_ticks_msec()+5000
	while not condition.call() and Time.get_ticks_msec()<deadline:
		g._physics_process(0.01)
		await process_frame
	if not condition.call():failures+=1;push_error("UDP pursuit flow timeout: "+marker)
func run_test()->void:
	g=Game.new();root.add_child(g);g.set_physics_process(false)
	await process_frame;await process_frame
	g.trainer_control.port=int(OS.get_cmdline_user_args()[1])
	g.get_node("GameSettings").always_show_intro=true
	g.setup_panel.show_choices()
	var flow=g.setup_panel.pursuit_flow
	flow.preferences_path="user://test_ride_pursuit_udp.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	await wait_for("MODE_RIGHT",func():return root.gui_get_focus_owner()==g.setup_panel.cards[1])
	await wait_for("MODE_A",func():return flow.visible and flow.step==1)
	await wait_for("OPPONENT_A",func():return flow.step==2)
	await wait_for("STRENGTH_UP",func():return root.gui_get_focus_owner()==flow.strength_input.get_line_edit())
	await wait_for("CAROUSEL_UP",func():return root.gui_get_focus_owner()==flow.left_arrow)
	var previous:int=flow.current
	await wait_for("OPPONENT_RIGHT",func():return flow.current==posmod(previous+1,flow.candidates.size()))
	await wait_for("PERCENT_DOWN",func():return root.gui_get_focus_owner()==flow.strength_input.get_line_edit())
	var strength:float=flow.strength_input.value
	await wait_for("PERCENT_RIGHT",func():return flow.strength_input.value==minf(150,strength+5))
	await wait_for("START_DOWN",func():return root.gui_get_focus_owner()==flow.proceed_button)
	await wait_for("START_A",func():return g.start_state=="INTRO")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	g.free();await process_frame
	print("VIRTUAL_BRIDGE_OK PURSUIT_NAVIGATION failures=%d"%failures)
	quit(0 if failures==0 else 1)
