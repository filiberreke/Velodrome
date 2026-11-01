extends SceneTree
class Screen extends "res://main.gd":
	func _bind_bridge(_port:int=UDP_PORT)->Error:return super._bind_bridge(0)
	func _save_recording(_reason:String)->void:pass
var output:="res://verification/pursuit_flow/"
func _initialize()->void:call_deferred("capture")
func snapshot(name:String)->void:
	for i in range(6):await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+name+".png")==OK)
	print("CAPTURED ",name)
func capture()->void:
	DirAccess.make_dir_recursive_absolute(output)
	var game:=Screen.new();root.add_child(game);game.set_physics_process(false)
	await process_frame;await process_frame
	var menu=game.setup_panel;var flow=menu.pursuit_flow
	flow.preferences_path="user://config/test_capture_opponents.cfg";DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	menu.select_mode(1)
	await snapshot("01_individual_distance")
	flow.next_step();flow.strength_input.value=90
	await snapshot("02_individual_opponent")
	menu.pursuit_options.library.directory="user://capture_pursuit_flow_individual"
	var samples:Array[Dictionary]=[{"t":0.,"d":0.,"p":250.,"lane":1.18},{"t":37.1,"d":500.,"p":400.,"lane":1.18},{"t":74.2,"d":1000.,"p":300.,"lane":1.18}]
	menu.pursuit_options.library.save("Mijn 1 km-prestatie",1000,74.2,samples,{"finished_local":"2026-11-01 15:34:12"})
	flow.select_kind(1);flow.strength_input.value=110
	await snapshot("03_individual_previous_ride")
	menu.show_choices();menu.select_mode(2);flow.select_size(4)
	await snapshot("04_team_distance")
	flow.next_step();flow.cycle(1);flow.strength_input.value=85
	await snapshot("05_team_opponent")
	menu.team_options.library.directory="user://capture_pursuit_flow_team"
	menu.team_options.library.save("Onze vorige ploegprestatie",1000,74.2,samples,{"finished_local":"2026-11-01 16:05:30"})
	flow.select_kind(1)
	await snapshot("06_team_previous_ride")
	for directory in ["user://capture_pursuit_flow_individual","user://capture_pursuit_flow_team"]:
		var folder:=DirAccess.open(directory)
		if folder!=null:
			for filename in folder.get_files():DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.preferences_path))
	print("PURSUIT_FLOW_CAPTURES_OK")
	quit()
