extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port:int=UDP_PORT)->Error:return super._bind_bridge(0)
	func _save_recording(_reason:String)->void:pass
var failures:=0
func _initialize()->void:call_deferred("run_test")
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func click_button(button:Button)->void:
	var position:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=position;root.push_input(motion)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event)
	await process_frame
func run_test()->void:
	root.size=Vector2i(1920,1080)
	var game:=Game.new();root.add_child(game);game.set_physics_process(false)
	await process_frame;await process_frame
	var menu=game.setup_panel
	var order:Array[String]=[]
	for entry in menu.MODES:order.append(entry.key)
	check(order==["scratch","pursuit","team_pursuit","points","madison","elimination","keirin","time_trial","tempo","records"],"Elimination directly precedes keirin; Records remains last")
	for i in range(7):
		var riders:=0
		for node in menu.previews[i].get_child(0).get_children():
			if node.has_meta("preview_rider"):
				riders+=1;check(not String(node.country_kit).is_empty(),"Every illustrated rider wears an actual national kit")
		check(riders>0,"Every race preview contains cyclists")
	check(menu.previews[5].get_camera_3d().transform.is_equal_approx(menu.previews[0].get_camera_3d().transform),"Elimination has the same track and blue-band orientation as the other postcards")
	var world=menu.previews[5].get_child(0)
	check(world.get_node("EliminationRider5").position.z-preload("res://mode_preview.gd").REAR_EDGE_Z<0,"Last rear tyre has just cleared finish line")
	check(world.get_node("EliminationRider5").position.z-preload("res://mode_preview.gd").REAR_EDGE_Z>-.04,"Rear tyre is within four centimetres of finish")
	check(world.get_node("EliminationRider0").position.z<world.get_node("EliminationRider5").position.z,"Pack is ahead of last rider")
	for amount in [4,12,16]:
		menu.cards[5].pressed.emit()
		for i in menu.elimination_count_picker.item_count:
			if menu.elimination_count_picker.get_item_id(i)==amount:menu.elimination_count_picker.select(i)
		await process_frame;await process_frame
		check(not menu.start_button.disabled,"Elimination start button enabled")
		await click_button(menu.start_button)
		check(game.start_state!="SETUP" and not menu.visible,"Actual mouse click starts elimination")
		check(game.race_mode==2 and game.rider_count==amount,"Elimination keeps requested participant count")
		game.broadcast_intro.finish()
		for i in range(70):game._physics_process(.1)
		check(game.start_state=="RACING" and game.running,"Elimination proceeds through countdown into racing")
		check(is_equal_approx(game.x_ai.cp[1],float(game.rider_identities[1].cp_w)*game.rider_forms[1]),"Elimination retains main's fixed rider profiles and factors")
		if amount==4:
			while game.elimination_rules.remaining_count()==4 and game.clock<250:
				game.clock+=.1;game.watts=350;game._update_race(.1)
			check(game.elimination_rules.remaining_count()==3 and not game.elimination_exit.is_empty(),"Combined main runs the rear-wheel jury and eliminates a rider")
		game._reset()
	menu.cards[9].pressed.emit();check(menu.page==3 and menu.records_page.visible,"Reordered Records card still opens records")
	game.free()
	print("ELIMINATION_MENU_FIX failures=",failures)
	quit(0 if failures==0 else 1)
