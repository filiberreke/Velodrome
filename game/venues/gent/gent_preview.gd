extends Node3D
## Interactive in-engine venue design. No race jury, trainer connection or saves.
const Profile := preload("res://venues/gent.tres")
var venue: Resource=Profile.duplicate(true)
var track=preload("res://venues/venue_track.gd").new(venue)
var arena: Node3D
var camera: Camera3D
var riders:Array[Node3D]=[]
var rider_distances:Array[float]=[]
var elapsed:=0.0
var camera_index:=0
var ui:CanvasLayer
var view_label:Label
# The shared official uses this small presentation state; no race results are made.
var start_state:="SETUP"
var race_mode:=1
var finished:=false
var distances:Array[float]=[0.0,0.0]
var finish_times:Array[float]=[-1.0,-1.0]
var race_laps:=6
var countdown:=3.0
var show_ui:=true
var show_riders:=true
func _ready() -> void:
	name="GentVenueDesign"
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("242b33")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("f5eddf");world.environment.ambient_light_energy=.58
	world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(world)
	arena=preload("res://venues/gent/gent_arena.gd").new();add_child(arena);arena.build(self,venue,track)
	camera=Camera3D.new();camera.fov=76;camera.near=.10;camera.far=180;add_child(camera);camera.current=true
	if show_riders:_build_riders()
	_build_ui()
	set_view(0)
func _at(s:float,offset:float)->Vector3:return track.at(s,offset)
func _build_riders()->void:
	for i in 12:
		var r:=preload("res://rider_visual.gd").new()
		r.set_meta("rider_index",i%4);r.set_meta("country_kit",["belgium","netherlands","france","italy"][i%4])
		add_child(r);riders.append(r);rider_distances.append(18.0+float(i)*3.0)
	_update_riders(0)
func _update_riders(delta:float)->void:
	for i in riders.size():
		rider_distances[i]+=delta*13.0
		var s:=rider_distances[i];var lane:=1.15+float(i%3)*.73
		var p:Vector3=track.at(s,lane);var forward:Vector3=track.direction(s,lane)
		var r:Node3D=riders[i];r.position=p;r.rotation=Vector3(0,atan2(forward.x,forward.z),-track.bank(s)*track.geometry.bend(track.phase(s))*.84)
		r.pedal(delta,92.0,290.0)
func _process(delta:float)->void:
	elapsed+=delta
	_update_riders(delta)
	# Cycle the prop demonstration using the actual four shared clips.
	if arena!=null and arena.official!=null:
		var actions: Array[String]=["VO_StartReady","VO_StartFire","VO_LastLapBell","VO_FinishFlag"]
		var phase:=int(elapsed/6.0)%actions.size()
		arena.official._official_play(actions[phase])
func _build_ui()->void:
	ui=CanvasLayer.new();add_child(ui)
	var top:=PanelContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_bottom=66;ui.add_child(top)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.055,.08,.12,.94);top.add_theme_stylebox_override("panel",style)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",22);top.add_child(row)
	var title:=Label.new();title.text="  GENT  /  166,67 m  /  6 = 1 km";title.add_theme_font_size_override("font_size",22);row.add_child(title)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spacer)
	view_label=Label.new();view_label.add_theme_font_size_override("font_size",18);row.add_child(view_label)
	var button:=Button.new();button.text=tr("GENT_NEXT_VIEW");button.pressed.connect(func():set_view((camera_index+1)%4));row.add_child(button)
	var back:=Button.new();back.text=tr("COMMON_BACK");back.pressed.connect(_back);row.add_child(back)
	var hint:=Label.new();hint.text=tr("GENT_PREVIEW_HINT");hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_top=-35
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",Color("f2ede2"));hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_offset_x",2);hint.add_theme_constant_override("shadow_offset_y",2);ui.add_child(hint)
	ui.visible=show_ui
func set_view(index:int)->void:
	camera_index=posmod(index,4)
	var eye:Vector3;var target:Vector3;var fov:=76.0
	match camera_index:
		# Reference photo: near bend in front, finish LEFT, team bays RIGHT.
		0:eye=Vector3(10,12.0,-40);target=Vector3(-4.5,1.0,-7);fov=68.0
		1:eye=Vector3(18,6.0,-20);target=Vector3(9.3,1.9,-8.8);fov=72.0
		2:eye=Vector3(-28.5,9.4,-.675);target=Vector3(-8.35,.8,-.675);fov=64.0
		_:eye=Vector3(22,10.9,-10);target=arena.suite.position+Vector3.UP*1.5;fov=70.0
	camera.global_position=eye;camera.look_at(target);camera.fov=fov
	if view_label!=null:view_label.text=tr(["GENT_VIEW_OVERVIEW","GENT_VIEW_TRACK","GENT_VIEW_CABINS","GENT_VIEW_BROADCAST"][camera_index])
func _unhandled_key_input(e:InputEvent)->void:
	if not e is InputEventKey or not e.pressed or e.echo:return
	match e.keycode:
		KEY_1:set_view(0)
		KEY_2:set_view(1)
		KEY_3:set_view(2)
		KEY_4:set_view(3)
		KEY_C,KEY_RIGHT:set_view(camera_index+1)
		KEY_LEFT:set_view(camera_index-1)
		KEY_H:ui.visible=not ui.visible
		KEY_ESCAPE:_back()
func _back()->void:
	get_tree().change_scene_to_file("res://main.tscn")
