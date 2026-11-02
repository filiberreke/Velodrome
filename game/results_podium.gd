extends RefCounted
## Presentation-only copies. Never move or change the racing riders or their results.
const Visual := preload("res://rider_visual.gd")
const Appearance := preload("res://player_appearance.gd")
const MenuStyle := preload("res://menu_theme.gd")
const STEPS := [Vector3(0,0.65,0),Vector3(-1.05,0.45,0),Vector3(1.05,0.30,0)]
var root: Node3D
var signature := ""
var riders: Array[int] = []

func clear() -> void:
	if is_instance_valid(root):
		if root.get_parent() != null: root.get_parent().remove_child(root)
		root.queue_free()
	root = null
	riders.clear()
	signature = ""

func classified(game) -> Array[int]:
	var result: Array[int] = []
	# Do not award provisional places while an opponent is still racing.
	if not game._all_riders_finished(): return result
	if game.race_mode == 5:
		result.assign([0,game.team_size] if game.team_race.better(0,1) else [game.team_size,0])
	else:
		for i in range(game.rider_count):
			if game.finish_times[i] >= 0: result.append(i)
		result.sort_custom(func(a: int,b: int) -> bool: return game._race_better(a,b))
		if result.size() > 3: result.resize(3)
	return result

func update(game, podium: Node3D) -> void:
	var order := classified(game)
	if order.is_empty():
		if is_instance_valid(root): clear()
		return
	var next_signature := "%d:%s" % [game.race_mode,str(order)]
	if next_signature == signature and is_instance_valid(root): return
	clear()
	signature = next_signature
	riders.assign(order)
	root = Node3D.new()
	root.name = "ResultsPodiumRiders"
	podium.add_child(root)
	for place in range(order.size()):
		var index := order[place]
		var holder := Node3D.new()
		holder.name = "Place%d" % (place+1)
		holder.position = STEPS[place]
		holder.set_meta("rider_index",index)
		holder.set_meta("rank",place+1)
		holder.set_meta("identity_id",String(game.rider_identities[index].get("id","player")))
		root.add_child(holder)
		var visual := Visual.new()
		visual.set_meta("rider_index",game._profile(index))
		visual.set_meta("body_shapes",game.rider_identities[index].get("morphs",{}))
		visual.set_meta("jersey_config",game.rider_kits[index])
		var kit: Dictionary = game.rider_kits[index].duplicate(true)
		if index < game.bikes.size():
			var source = game.bikes[index].get_child(0)
			for key in Appearance.KEYS: kit[key] = String(source.get(key))
		elif index == 0:
			kit = game.player_appearance.resolve(game.get_player_appearance_base())
		Appearance.prepare_rider(visual,kit)
		holder.add_child(visual)
		var bike := visual.rig_scene.find_child("Bike",true,false) as GeometryInstance3D
		if bike != null: bike.hide()
		standing_pose(visual,place == 0)
		var name_label := Label3D.new()
		var caption: String = game._rider_name(index)
		if game.race_mode == 5: caption = "Jouw ploeg" if index == 0 else "Tegenploeg"
		name_label.text = "%d\n%s" % [place+1,caption]
		name_label.position = Vector3(STEPS[place].x,STEPS[place].y*.50,.468)
		name_label.font_size = 48
		name_label.pixel_size = .0013
		name_label.modulate = MenuStyle.INK
		name_label.outline_modulate = MenuStyle.IVORY
		name_label.outline_size = 4
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(name_label)

static func _bone(skeleton: Skeleton3D, name: String, head: Vector3, tail: Vector3) -> void:
	var index := skeleton.find_bone(name)
	if index < 0: return
	var rest := skeleton.get_bone_global_rest(index)
	var rotation := Quaternion(rest.basis.y.normalized(),(tail-head).normalized())
	skeleton.set_bone_global_pose_override(index,Transform3D(Basis(rotation)*rest.basis,head),1.0,true)

static func standing_pose(visual, winner: bool) -> void:
	visual.animator.stop()
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	skeleton.reset_bone_poses()
	_bone(skeleton,"pelvis",Vector3(0,1.02,0),Vector3(0,1.16,0))
	_bone(skeleton,"spine",Vector3(0,1.16,0),Vector3(0,1.303,0))
	_bone(skeleton,"chest",Vector3(0,1.303,0),Vector3(0,1.448,0))
	_bone(skeleton,"neck",Vector3(0,1.448,0),Vector3(0,1.598,0))
	_bone(skeleton,"head",Vector3(0,1.598,0),Vector3(0,1.849,0))
	for side in ["L","R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		var shoulder := Vector3(sign_x*.20,1.438,0)
		var elbow := Vector3(sign_x*(.38 if winner else .26),1.638 if winner else 1.175,0)
		var wrist := Vector3(sign_x*(.54 if winner else .30),1.843 if winner else .918,.02)
		var hand := wrist + Vector3(sign_x*.03,.08 if winner else -.08,.01)
		_bone(skeleton,"clavicle."+side,Vector3(sign_x*.03,1.448,0),shoulder)
		_bone(skeleton,"upper_arm."+side,shoulder,elbow)
		_bone(skeleton,"forearm."+side,elbow,wrist)
		_bone(skeleton,"hand."+side,wrist,hand)
		var hip := Vector3(sign_x*.10,.99,0)
		var knee := Vector3(sign_x*.11,.52,.02)
		var ankle := Vector3(sign_x*.11,.08,0)
		_bone(skeleton,"thigh."+side,hip,knee)
		_bone(skeleton,"shin."+side,knee,ankle)
		_bone(skeleton,"foot."+side,ankle,Vector3(sign_x*.11,.037,.18))
	skeleton.force_update_all_bone_transforms()
