extends SceneTree
const Box = preload("res://rennersboxen/rider_box.gd")
const ExistingTest = preload("res://tests/test_infield_boxes.gd")
var failures := 0

func _initialize() -> void:call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func check_crew(row: Node3D, index: int, active: bool) -> void:
	var box: Node3D = row.boxes[index]
	var crew: Node3D = row.crews[index]
	var equipment: Node3D = box.get_node("Geometry/ExteriorEquipment")
	check(crew.is_visible_in_tree()==active,"Box crew visibility matches activity")
	check(equipment.is_visible_in_tree()==active,"Bikes, rollers, wheel stock and cases disappear at a closed box")
	if not active:return
	var roles := {"mechanic":0,"carer":0,"coach":0,"supporter":0}
	var expected := Color(Box.Themes.DATA[box.country].base)
	for actor in crew.actors:
		roles[actor.get_meta("role")]+=1
		var mesh_count := 0
		for node in actor.get_children():
			if node is MultiMeshInstance3D:
				mesh_count+=1
				check(node.multimesh.instance_count==1,"Every named member has actual Blender crowd geometry")
				# The headless dummy renderer returns black for MultiMesh colour readback.
				# Verify source assignment here; the GPU capture checks actual readback.
				check(actor.get_meta("shirt").is_equal_approx(expected),"People receive the assigned country's shirt colour")
		check(mesh_count==1,"Every member has one detailed mesh without spectator LOD gaps")
		if actor.get_meta("role")=="supporter":
			check(absf(actor.position.z+0.52-2.95)<0.001,"Leaning supporters' hands meet the actual glass rail")
			check(absf(actor.position.x)>2,"Supporters keep the cabin's central approach clear")
	check(roles=={"mechanic":2,"carer":1,"coach":1,"supporter":4},"Each open box has two mechanics, carer, trainer and four supporters")
	check(crew.get_node("Verzorger/Bidons").get_child_count()==4,"Carer has two real bottle bodies and caps")
	check(crew.has_node("Trainer/Stopwatch"),"Trainer's clipboard pose has a timing watch")

func run_test() -> void:
	# Compare each copied static surface against the actual rider rig, not a path label.
	for variant in ["track","pursuit"]:
		var box := Box.new()
		box.bike_variant = variant
		root.add_child(box)
		await process_frame
		var source: Node3D = Box.BIKE_SCENES[variant].instantiate()
		var live_bike := source.find_child("Bike",true,false) as MeshInstance3D
		var parts: Array = Box._bike_parts[variant]
		var exterior: Node3D = box.get_node("Geometry/ExteriorEquipment")
		var wheel_top := 0.0
		for n in exterior.get_children():
			if n is MeshInstance3D:
				var batch: Array = n.mesh.surface_get_arrays(0)
				# Check rendered triangles, not unreferenced vertices left in a batch.
				for vertex_index in batch[Mesh.ARRAY_INDEX]:
					wheel_top=maxf(wheel_top,batch[Mesh.ARRAY_VERTEX][vertex_index].y)
		check(wheel_top>2.8,"Original rear wheels are present above the box")
		check(parts.size()==live_bike.mesh.get_surface_count(),variant+": preserve every original bike surface")
		for i in range(parts.size()):
			var original: Array = live_bike.mesh.surface_get_arrays(i)
			var actual: Array = parts[i].mesh.surface_get_arrays(0)
			check(original[Mesh.ARRAY_VERTEX]==actual[Mesh.ARRAY_VERTEX],variant+": identical race-model vertices")
			check(original[Mesh.ARRAY_INDEX]==actual[Mesh.ARRAY_INDEX],variant+": identical race-model triangles")
			var expected: StandardMaterial3D = live_bike.get_active_material(i)
			var material: StandardMaterial3D = parts[i].material
			check(material.resource_name==expected.resource_name and material.albedo_color.is_equal_approx(expected.albedo_color),variant+": preserve the actual red/white frame and wheel materials")
			check(actual[Mesh.ARRAY_BONES]==null,"A parked bicycle contains no active cyclist skin")
		source.free()
		box.free()
	var game := ExistingTest.Screen.new()
	game.fixture.set_value("player","country_kit","belgium")
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var infield: Node3D = game.arena.get_node("LevendigMiddenterrein")
	var row: Node3D = infield.get_node("Rennersboxen")
	for i in range(6):check_crew(row,i,true)
	for child in infield.get_children():
		check(not (child is MultiMeshInstance3D and String(child.name).contains("staff_mechanic")),"No orphaned always-visible mechanics outside the box controller")
	game.race_mode = 4
	game._configure_peloton()
	await process_frame
	var active_count := 0
	for i in range(6):
		var active: bool = row.boxes[i].is_active()
		check_crew(row,i,active)
		check(row.boxes[i].bike_variant=="pursuit","Pursuit boxes use the same TT bike as the pursuit riders")
		if active:active_count+=1
	check(active_count==2,"Only the two pursuit countries have people and material")
	# Test during the animated close as well as after it has completed.
	var at := -1
	for i in range(6):
		if row.boxes[i].is_active():at=i;break
	row.boxes[at].set_open(false,0.45)
	check_crew(row,at,false)
	await create_timer(0.6).timeout
	check_crew(row,at,false)
	row.boxes[at].set_open(true,0.45)
	check_crew(row,at,true)
	game.player_appearance.suit_id = "netherlands"
	game.apply_player_appearance()
	await process_frame
	for i in range(6):check_crew(row,i,row.boxes[i].is_active())
	game.race_mode = 0
	game.rider_count = 8
	game._configure_peloton()
	await process_frame
	for i in range(6):
		check_crew(row,i,true)
		check(row.boxes[i].bike_variant=="track","Returning to scratch restores the real standard race bike")
	game.free()
	print("BOX_OCCUPATION_OK" if failures==0 else "BOX_OCCUPATION_FAILED: "+str(failures))
	quit(0 if failures==0 else 1)
