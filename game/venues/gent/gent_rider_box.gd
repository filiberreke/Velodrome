@tool
extends "res://rennersboxen/rider_box.gd"
## The existing Vélodrome sleeping cabin, with Gent's sober finishes and roof.
## Local +Z is the curtained entrance; placement turns it toward the piste.
var pair_number:=1
var fabric_hex:="6c7d78"
static var _gent_finishes:Dictionary={}

func _init()->void:
	include_equipment=false
	include_barriers=false
	collision_enabled=false

func _print(part:String)->StandardMaterial3D:
	var hex:String=fabric_hex if part=="curtain" else ("d8d6c9" if part=="header" else "a4aaa8")
	if not _gent_finishes.has(hex):
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color(hex);material.roughness=.88
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		_gent_finishes[hex]=material
	return _gent_finishes[hex]

func rebuild()->void:
	# Reuse the actual bed, mattress, pillow, folded bedding, shelf, helmets,
	# bottles, metal frame and movable pleated curtains from Vélodrome.
	super.rebuild()
	if not is_instance_valid(_geometry):return
	var roof:=_box(Vector3(0,2.17,0),Vector3(2.72,.10,2.62),_mat("b5bab7"))
	roof.name="GentRoof"
	_box(Vector3(0,2.04,1.32),Vector3(2.62,.24,.08),_mat("3b4b51")).name="GentFrontFascia"
	var number:=Label3D.new();number.name="GentPairNumber";number.text="%02d"%pair_number
	number.font_size=64;number.pixel_size=.23/64.0;number.outline_size=0
	number.modulate=Color("f2eee4");number.position=Vector3(0,2.045,1.369)
	_geometry.add_child(number)
	# The spare bike is above the roof, leaving the doorway and bed visible.
	var rack_material:=_mat("acb7c1",.7)
	for x in [-1.15,1.15]:
		_rod(Vector3(x,2.22,-.75),Vector3(x,2.48,-.75),.025,rack_material)
	_rod(Vector3(-1.20,2.42,-.75),Vector3(1.20,2.42,-.75),.025,rack_material)
	preload("res://venues/gent/parked_bike.gd").build(_geometry,Vector3(0,2.27,-.75),PI/2)
