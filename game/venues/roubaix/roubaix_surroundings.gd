extends "res://venues/gent/gent_build.gd"

const Crowd := preload("res://crowd_kit.gd")
const PAVEMENT_Y := 0.008
const STREET_DISTANCE := -17.5
const STREET_OFFSET := 24.2
const STREET_LENGTH := 205.0

var rng := RandomNumberGenerator.new()
var crowd: RefCounted
var density: float

func build(profile: Resource, route: RefCounted, kit: RefCounted, crowd_density: float, access_distance: float) -> void:
	venue = profile
	track = route
	crowd = kit
	density = crowd_density
	rng.seed = 19260317
	_build_grandstand_street()
	_build_arrival_plaza(access_distance)
	for sector in [Vector2(41.0, 85.0), Vector2(87.0, 136.0), Vector2(141.0, 185.0), Vector2(304.0, 347.0), Vector2(350.0, 393.0), Vector2(395.0, 434.0)]:
		_bend_concourse(sector.x, sector.y)

func _ground_frame(s: float, offset: float) -> Node3D:
	var outward: Vector3 = track.outward(s)
	var p: Vector3 = track.at(s, offset)
	p.y = PAVEMENT_Y
	var place := Node3D.new()
	place.transform = Transform3D(Basis(Vector3.UP.cross(outward), Vector3.UP, outward), p)
	add_child(place)
	return place

func _ground(name_text: String, parent: Node3D, x: float, z: float, width: float, depth: float, paint: Material, height := 0.0) -> void:
	box(name_text, Vector3(x, height - 0.04, z), Vector3(width, 0.08, depth), paint, parent)

func _build_grandstand_street() -> void:
	var street := _ground_frame(STREET_DISTANCE, STREET_OFFSET)
	street.name = "GrandstandStreet"
	_ground("StreetAsphalt", street, 0, 0, STREET_LENGTH, 7.3, mat("4a4b49"))
	for side in [-1.0, 1.0]:
		_ground("Sidewalk", street, 0, side * 4.95, STREET_LENGTH, 2.6, mat("8b8981"), 0.095)
		_ground("Curb", street, 0, side * 3.69, STREET_LENGTH, 0.13, mat("c4bdb0"), 0.11)
	for x in range(-98, 99, 5):
		_ground("CenterMark", street, x, 0, 2.0, 0.087, mat("cdcbc0"), 0.004)
	for x in [-41.0, 39.0]:
		for stripe in 8:
			_ground("ZebraStripe", street, x, -2.71 + stripe * 0.78, 3.1, 0.35, mat("bdbbb0"), 0.006)
	var windows: Array[Vector3] = []
	for block in [[-80.0, 21.0, 8.5], [-43.0, 25.0, 9.7], [-14.0, 27.0, 12.7], [14.2, 24.0, 11.0],
			[38.3, 20.0, 8.9], [54.1, 10.0, 10.5], [78.0, 19.0, 7.3]]:
		_brick_building(street, block[0], block[1], block[2], windows)
	_facade_windows(street, windows)
	for i in 10:
		var x := -53.0 + i * 11.5
		var paint: String = ["dedcd4", "496478", "a0a3a0", "b96e54", "414b52"][i % 5]
		_vehicle(street, Vector3(x, 0, 2.45 if i % 3 != 0 else -2.51), paint, i % 4 == 0)
	for x in [-48.0, -25.0, -2.0, 21.0, 44.0]:
		box("StreetlampPole", Vector3(x, 2.30, -4.35), Vector3(0.085, 4.6, 0.085), mat("68716f"), street)
		box("StreetlampHead", Vector3(x, 4.62, -3.98), Vector3(0.24, 0.10, 0.83), mat("9d9f93"), street)

func _brick_building(parent: Node3D, x: float, width: float, height: float, windows: Array[Vector3]) -> void:
	var brick := mat("805448" if height < 11.0 else "9a6755")
	var stone := mat("c1ae94")
	var roof := mat("555c5c", 0.79)
	box("BrickBuilding", Vector3(x, height * 0.5, 12.35), Vector3(width, height, 12.1), brick, parent)
	box("RoofParapet", Vector3(x, height + 0.18, 12.35), Vector3(width + 0.28, 0.42, 12.34), roof, parent)
	box("RoofServiceRoom", Vector3(x + width * 0.21, height + 0.71, 14.7), Vector3(3.1, 1.05, 2.45), mat("898a81"), parent)
	box("StonePlinth", Vector3(x, 0.38, 6.25), Vector3(width, 0.76, 0.12), stone, parent)
	var bays := maxi(2, floori(width / 2.8))
	for story in range(1, int(height / 2.75) + 1):
		var y := story * 2.50
		box("FacadeBelt", Vector3(x, y - 0.88, 6.27), Vector3(width, 0.10, 0.17), stone, parent)
		for bay in bays:
			var px := x + ((bay + 0.5) / bays - 0.5) * width
			windows.append(Vector3(px, y, 6.24))

func _facade_windows(street: Node3D, openings: Array[Vector3]) -> void:
	for part in [["Windows", Vector3.ZERO, Vector3(1.11, 1.45, 0.06), Color("586771")],
			["WindowMullions", Vector3(0, 0, -0.04), Vector3(0.055, 1.45, 0.04), Color("c1ae94")],
			["WindowSills", Vector3(0, -0.74, -0.08), Vector3(1.25, 0.085, 0.21), Color("c1ae94")]]:
		var poses: Array[Transform3D] = []
		var colors: Array[Color] = []
		for opening in openings:
			poses.append(Transform3D(street.basis, street.transform * (opening + Vector3(part[1]))))
			colors.append(part[3])
		instances(part[0], part[2], poses, colors)

func _vehicle(parent: Node3D, p: Vector3, paint: String, van: bool) -> void:
	var chassis := mat(paint, 0.58)
	var windows := mat("455664", 0.34)
	box("VehicleBody", p + Vector3.UP * 0.56, Vector3(4.35, 0.64, 1.76), chassis, parent)
	box("VehicleGlass", p + Vector3(-0.28, 1.00, 0), Vector3(2.41, 0.44, 1.63), windows, parent)
	box("VehicleRoof", p + Vector3(-0.28, 1.25, 0), Vector3(2.51, 0.12, 1.68), chassis, parent)
	if van:
		box("VanCargoBox", p + Vector3(0.52, 1.24, 0), Vector3(2.92, 1.04, 1.77), chassis, parent)
	for x in [-1.34, 1.32]:
		for z in [-0.82, 0.82]:
			box("Tyre", p + Vector3(x, 0.30, z), Vector3(0.61, 0.58, 0.22), mat("252628"), parent)
	for z in [-0.65, 0.65]:
		box("Headlamp", p + Vector3(-2.18, 0.62, z), Vector3(0.045, 0.17, 0.29), mat("e1dfcc"), parent)
		box("TailLamp", p + Vector3(2.18, 0.62, z), Vector3(0.045, 0.17, 0.24), mat("a02d26"), parent)

func _build_arrival_plaza(s: float) -> void:
	var plaza := _ground_frame(s, venue.track_outer_offset_m)
	plaza.name = "RoadAccessEventVillage"
	for segment in [Vector2(s - 34.5, s - 3.34), Vector2(s + 3.34, s + 36.0)]:
		ring("ArrivalConcourse", 13.5, 18.7, mat("8c887e"), segment.x, segment.y - segment.x, PAVEMENT_Y - 0.025, true)
	for side in [-1.0, 1.0]:
		_ground("PlazaPaving", plaza, side * 15.8, 16.6, 25.2, 24.2, mat("89867c"))
		_ground("ServiceCourt", plaza, side * 15.6, 38.7, 24.0, 18.2, mat("727572"))
		_plaza_barrier(plaza, side * 3.64)
		for i in 3:
			_vehicle(plaza, Vector3(side * (20.6 + (i % 2) * 4.7), 0, 35.5 + i * 4.7), "e2e0d5", true)
		for i in 3:
			var x: float = side * (15.6 + 5.2 * i)
			_marquee(plaza, Vector3(x, 0, 16.4 + float((i + int(side > 0.0)) % 2) * 5.3), "e5e4d9" if i != 1 else "365774")
		var people: Dictionary = {}
		for row in 8:
			for i in 18:
				var x: float = side * (4.05 + row * 0.65 + rng.randf_range(-0.25, 0.25))
				var z := 6.4 + i * 0.73 + rng.randf_range(-0.30, 0.30)
				var p := plaza.to_global(Vector3(x, 0, z))
				var concentration := 2.65 - maxf(0.0, row - 2.0) * (0.27 + 0.15 * sin(i * 0.54 + side))
				_spectator(people, p, plaza.global_basis.x * -side, concentration)
		for i in 33:
			var p := plaza.to_global(Vector3(side * rng.randf_range(9.8, 15.3), 0, rng.randf_range(9.0, 14.5)))
			_spectator(people, p, plaza.global_basis.z, 1.2)
		crowd.emit_group(self, people, "AccessSpectators", [[1, 0.0, 0.0]])

func _plaza_barrier(plaza: Node3D, x: float) -> void:
	var metal := mat("859195", 0.58)
	for height in [0.16, 0.95]:
		box("CrowdBarrierRail", Vector3(x, height, 15.0), Vector3(0.05, 0.045, 18.0), metal, plaza)
	for i in 13:
		box("CrowdBarrierPost", Vector3(x, 0.52, 6.0 + i * 1.5), Vector3(0.06, 1.04, 0.06), metal, plaza)

func _marquee(parent: Node3D, base: Vector3, tint: String) -> void:
	var fabric := mat(tint)
	for x in [-2.1, 2.1]:
		for z in [-1.9, 1.9]:
			box("MarqueeLeg", base + Vector3(x, 1.22, z), Vector3(0.075, 2.44, 0.075), mat("b8b9b2"), parent)
	box("MarqueeValance", base + Vector3.UP * 2.47, Vector3(4.45, 0.23, 4.06), fabric, parent)
	var corners := [Vector3(-2.23, 2.56, -2.03), Vector3(2.23, 2.56, -2.03), Vector3(2.23, 2.56, 2.03), Vector3(-2.23, 2.56, 2.03)]
	var vertices := PackedVector3Array()
	for i in 4:
		for point in [corners[i], corners[(i + 1) % 4], Vector3.UP * 3.45]:
			vertices.append(parent.to_global(base + point))
	surface("MarqueeCanopy", vertices, fabric)

func _bend_concourse(start: float, end: float) -> void:
	ring("BendConcourse", 13.65, 18.2, mat("918d80"), start, end - start, PAVEMENT_Y, true)
	var people: Dictionary = {}
	for row in 4:
		var s := start + rng.randf_range(0.15, 0.50)
		while s < end - 0.4:
			var offset := 14.0 + row * 0.68 + rng.randf_range(-0.22, 0.22)
			var p: Vector3 = track.at(s, offset)
			p.y = PAVEMENT_Y
			var busy := 1.7 + 0.72 * sin(s * 0.18 + row * 0.7) + 0.35 * cos(s * 0.41)
			_spectator(people, p, -track.outward(s), busy)
			s += rng.randf_range(0.42, 0.59)
	crowd.emit_group(self, people, "BendSpectators", [[1, 0.0, 0.0]])

func _spectator(people: Dictionary, p: Vector3, toward: Vector3, concentration: float) -> void:
	if rng.randf() >= 1.0 - pow(1.0 - density, concentration): return
	var facing := toward.rotated(Vector3.UP, rng.randf_range(-0.46, 0.46))
	var variant: String = Crowd.STANDING[rng.randi_range(0, Crowd.STANDING.size() - 1)]
	Crowd.add_to_group(people, variant, Transform3D(Basis(Vector3.UP.cross(facing), Vector3.UP, facing), p), crowd.random_look(rng))
