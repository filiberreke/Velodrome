extends RefCounted
## Places reusable concessions west of the large yellow northern tent.
const SJAMPANJE := preload("res://scenes/bars/SjampanjeBar.tscn")
const PURSOET := preload("res://scenes/bars/PursoetBar.tscn")

func build(host: Node3D) -> Node3D:
	var zone := Node3D.new(); zone.name = "NoordelijkeSponsorbars"; host.add_child(zone)
	var champagne := SJAMPANJE.instantiate() as Node3D
	zone.add_child(champagne); champagne.position = Vector3(-5.8,0,37.0)
	# Champagne stays north; Pursoet replaces the southern waffle stall.
	host.blockers.append([Vector2(-5.8,37),2.55])
	# Match the paved northern hospitality zone, inside the curved spectator strip.
	var outline := [Vector3(-13,0.009,30.5),Vector3(-4.5,0.009,30.5),Vector3(-4.5,0.009,45),Vector3(-7.2,0.009,45),Vector3(-12.8,0.009,39)]
	var vertices := PackedVector3Array()
	for i in range(1,outline.size()-1): vertices.append_array([outline[0],outline[i],outline[i+1]])
	host._surface(vertices,"Terras nieuwe noordbars","b3a481")
	var spots := [Vector3(-10.5,0,31.0),Vector3(-6.8,0,31.5),Vector3(-3.2,0,32.5),Vector3(-10.5,0,42.5),Vector3(-5.8,0,43.0)]
	var count := 0
	for index in range(spots.size()):
		var p: Vector3 = spots[index]
		var table: Node3D = host._prop("high_table",p,0,{"canopy_a":"ff7900" if index%2 else "064a32"},0.0)
		table.name = "Bartafel%02d" % (index+1)
		# All four people have explicit positions; random wanderers stay clear.
		for person in range(4):
			var angle: float = TAU*float(person)/4.0+0.35
			var position := p+Vector3(sin(angle),0,cos(angle))*0.90
			var variant: String = ["stand_f_drink","stand_m_drink","stand_f_talk","stand_m_relaxed"][(person+index)%4]
			host._person(variant,position,atan2((p-position).x,(p-position).z))
			count += 1
		host.blockers.append([Vector2(p.x,p.z),1.65])
	zone.set_meta("supporter_count",count); zone.set_meta("table_count",spots.size())
	return zone

func build_south(host: Node3D) -> Node3D:
	var soda := PURSOET.instantiate() as Node3D
	host.add_child(soda); soda.position = Vector3(-8.5,0,-16.0)
	# Scene front is -Z; rotate it east towards the infield like the old waffle stall.
	soda.rotation.y = -PI*0.5
	host.blockers.append([Vector2(-8.5,-16),2.25])
	return soda
