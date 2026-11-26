extends SceneTree
## Real rendered Godot frames. Run with a display/GPU, not --headless.
func _initialize()->void:call_deferred("run")
func run()->void:
	TranslationServer.set_locale("nl")
	var view:=SubViewport.new();view.size=Vector2i(1600,900);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;root.add_child(view)
	var scene:=preload("res://venues/gent/gent_preview.gd").new();scene.show_ui=false;view.add_child(scene)
	await process_frame
	scene.set_process(false);scene._update_riders(0.0)
	var output:=ProjectSettings.globalize_path("res://project.godot").get_base_dir().get_base_dir().path_join("docs/venues/gent/screenshots/");DirAccess.make_dir_recursive_absolute(output)
	for i in 4:
		scene.set_view(i)
		if i==1:
			for k in scene.rider_distances.size():scene.rider_distances[k]=20.0-k*2.4
			scene._update_riders(0.0)
		scene.arena.official._official_play("VO_LastLapBell" if i!=3 else "VO_StartReady")
		scene.arena.official.flag_anim.advance(.45)
		for j in 10:await RenderingServer.frame_post_draw
		var name:String=["01-overzicht","02-piste","03-rennersboxen","04-tv-box"][i]
		view.get_texture().get_image().save_jpg(output+name+".jpg",0.94)
		print("GENT_CAPTURE ",output+name+".jpg")
	scene.free();view.free();quit()
