extends SceneTree
const Sponsors := preload("res://boarding_sponsors.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game = preload("res://main.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	var group: Node3D = game.arena.get_node("NoordbochtSponsors")
	var panels: Array = group.get_meta("panels")
	var start: float = game.LAP*0.5; var end: float = start+PI*game.RADIUS
	check(panels.size()>=7 and panels.size()%3==1,"Repeating pattern shares Tour separators")
	check(is_equal_approx(panels[0]["start"],start) and is_equal_approx(panels[-1]["end"],end),"Entire northern bend covered")
	var expected := ["tour-dambiance-vierkant.png","sjampanje-ivoor.png","sjampanje-groen.png"]
	var visual := panels.duplicate(); visual.reverse()
	for index in range(visual.size()):
		check(String(visual[index]["texture"]).get_file()==expected[index%3],"Visible order Tour / white / green / Tour")
	for index in range(panels.size()):
		var panel: Dictionary = panels[index]
		check(panel["end"]>panel["start"],"Every sign has positive width")
		if index>0: check(absf(panel["start"]-panels[index-1]["end"])<0.0001,"No gaps or overlaps between signs")
		var texture: Texture2D = load(panel["texture"])
		var aspect := float(texture.get_width())/float(texture.get_height())
		var base: Dictionary = panels[0]
		check(absf((panel["end"]-panel["start"])/aspect-(base["end"]-base["start"]))<0.0001,"Square Tour / broad champagne banners retain their relative proportions")
	check(Sponsors.covered(game,start+0.01) and Sponsors.covered(game,end-0.01),"Old northern posters suppressed")
	check(not Sponsors.covered(game,90),"Other unfinished straight remains outside new coverage")
	check(group.get_child_count()==3,"Geometry batched into three sponsor meshes")
	for item in group.get_children():
		var arrays: Array = item.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(not points.is_empty() and points.size()==uv.size(),"Curved print has full vertex/UV data")
		for texcoord in uv: check(texcoord.x>=0 and texcoord.x<=1 and texcoord.y>=0 and texcoord.y<=1,"No cropped logos")
	game.free()
	print("NORTH_BOARDING_OK" if failures==0 else "NORTH_BOARDING_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
