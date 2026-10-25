extends RefCounted
## Scenic details behind the last (Tour d'Ambiance) bend; no race logic.
const DOG := preload("res://assets/people/chihuahua_lasagne.glb")
const FAN := preload("res://assets/people/supporter_wout.glb")
const STAIR_S := 147.15 # Fourth radial stair: 3*49.7 - 3 + 1.05.
const FAN_S := 152.4

func build(arena: Node3D) -> void:
	var details := Node3D.new(); details.name = "TourBochtDetails"; arena.add_child(details)
	var dog := DOG.instantiate() as Node3D; details.add_child(dog); dog.name = "ChihuahuaLasagne"
	# Fifth tread of the lower tier: raised above the first rows, not behind the fascia.
	dog.position = arena._stadium_point(STAIR_S,10.65+4.0*1.10+0.55,0.88+4.0*0.40+0.022)
	dog.basis = facing(arena,STAIR_S)
	dog.set_meta("stair_s",STAIR_S); dog.set_meta("row",4)
	var fan := FAN.instantiate() as Node3D; details.add_child(fan); fan.name = "WoutSupporter"
	fan.position = arena._stadium_point(FAN_S,10.65+0.55,0.88)
	fan.basis = facing(arena,FAN_S)
	fan.set_meta("tier",0);fan.set_meta("row",0)
	var text := Label3D.new(); text.name = "WoutSpandoekTekst"
	text.text = "WOUT WOUT WOUT!";text.font_size = 72;text.pixel_size = 0.00195
	text.modulate = Color("172d40");text.outline_size = 0
	text.no_depth_test = false; text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	fan.add_child(text);text.position = Vector3(0,1.38,0.358)
	text.shaded = true; text.double_sided = false
	details.set_meta("bend", "Tour d'Ambiance")

func facing(arena: Node3D, s: float) -> Basis:
	var outward: Basis = arena._seat_basis(s)
	return Basis(-outward.x,Vector3.UP,-outward.z)
