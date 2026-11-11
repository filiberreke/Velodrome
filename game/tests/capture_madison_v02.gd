extends SceneTree
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for i in range(4): await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://verification/madison_v02/"+name+".png") == OK)
	print("CAPTURED ",name)
func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://verification/madison_v02")
	var game := Game.new(); root.add_child(game); game.set_physics_process(false)
	for i in range(3): await process_frame
	game.bridge_devices.close_page()
	var menu = game.setup_panel
	menu.training_store.folder = "user://capture_madison_v02"
	menu.show_hub(); await shot("00_v02_hub")
	menu.show_piste_training(); await shot("01_piste_training")
	menu.show_madison_training()
	menu.madison_page.progress.advanced_unlocked = false
	menu.madison_page._refresh()
	await shot("02_training_settings")
	menu.madison_page.begin()
	var scene = game.madison_training_environment
	scene._spawn_partner() # Explicit exchange fixture after the normal settling-in start.
	scene.distances.assign([90.0,90.0]); scene.speeds.assign([12.0,10.0]); scene.lane_offsets.assign([2.38,3.58])
	scene.madison.reset()
	for i in range(60):
		scene.madison.step(scene,1.0/60.0); scene._present(1.0/60.0)
		await process_frame
	scene.grab_button("capture",true); scene.grab_button("capture",false)
	scene.madison.step(scene,scene.madison.grab_seconds)
	scene.madison.step(scene,scene.madison.sling_seconds*.58)
	scene._present(1.0)
	await shot("03_training_exchange")
	var centre: Vector3 = (scene.bikes[0].global_position+scene.bikes[1].global_position)*.5
	game.camera.global_position = centre+scene.bikes[0].global_basis.z*3+Vector3.UP*2+(scene.bikes[1].position-scene.bikes[0].position).normalized()*3
	game.camera.look_at(centre+Vector3.UP,Vector3.UP); game.camera.fov = 45
	await shot("04_hand_contact")
	menu.madison_page.leave()
	game.queue_free(); await process_frame; await process_frame
	print("MADISON_V02_CAPTURES_OK"); quit()
