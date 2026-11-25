extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=preload("res://tests/arena_roof_test_game.gd").new();root.add_child(game);current_scene=game;game.set_physics_process(false)
	await process_frame
	var button:Button=game.setup_panel.find_child("GentVenuePreview",true,false)
	check(button!=null,"Gent accessible from main menu")
	for locale in ["nl","en"]:
		TranslationServer.set_locale(locale)
		check(button.tr(button.text).contains("Gent") and not button.tr(button.text).contains("GENT_OPEN"),"Menu button translated: "+locale)
	button.pressed.emit()
	for i in 3:await process_frame
	check(current_scene.get_script().resource_path=="res://venues/gent/gent_preview.gd","Menu opens Gent scene")
	current_scene._back()
	for i in 3:await process_frame
	check(current_scene.get_script().resource_path=="res://main.gd","Back restores main game")
	check(current_scene.venue.id=="velodrome","Race default stays Vélodrome")
	current_scene.free();current_scene=null
	print("GENT_NAVIGATION_OK" if failures==0 else "GENT_NAVIGATION_FAILED")
	quit(0 if failures==0 else 1)
