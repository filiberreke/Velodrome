extends "res://venues/gent/gent_build.gd"

const Bike := preload("res://venues/gent/parked_bike.gd")
const Crowd := preload("res://crowd_kit.gd")
const GRAVEL_WIDTH := 3.6
const PASSAGE_WIDTH := 3.2
const BAY_WIDTH := 9.8
const BAY_FRONT := 7.2
const BAY_BACK := 13.4

var gate_distance: float
var waiting_spots: Array[Vector3] = []
var entry_points: Array[Vector3] = []
var slot_approaches: Array[Vector3] = []
var official: Node3D
var barrier_pickets: Array[Transform3D] = []
var barrier_feet: Array[Transform3D] = []
var rng := RandomNumberGenerator.new()

func build(host: Node3D, profile: Resource, route: RefCounted, crowd: RefCounted, density: float) -> void:
	venue = profile
	track = route
	gate_distance = venue.transition_m * 0.5 + venue.finish_straight_clearance_m - track.geometry.STRAIGHT * 0.5
	var inward: Vector3 = -track.outward(gate_distance)
	var origin: Vector3 = track.at(gate_distance, 0.0)
	origin.y = 0.015
	transform = Transform3D(Basis(Vector3.UP.cross(inward), Vector3.UP, inward), origin)
	for index in 3:
		_waiting_bay(index, -11.0 + index * 11.0)
	_technical_zone()
	_event_infield(crowd, density)
	for batch in [["BarrierFoot", Vector3(0.34, 0.073, 0.34), barrier_feet],
			["BarrierPicket", Vector3(0.027, 0.79, 0.027), barrier_pickets]]:
		var colors: Array[Color] = []
		colors.resize(batch[2].size())
		colors.fill(Color("879da2"))
		instances(batch[0], batch[1], batch[2], colors)
	official = preload("res://venues/race_official.gd").new()
	official.game = host
	official.official_lap_m = venue.lap_length_m
	# The shared official places itself in stadium coordinates.
	get_parent().add_child(official)
	official._build_flag_official()

func _waiting_bay(index: int, x: float) -> void:
	var bay := Node3D.new()
	bay.name = "WaitingBay%d" % (index + 1)
	bay.position.x = x
	add_child(bay)
	bay.set_meta("capacity", 8)
	var half := BAY_WIDTH * 0.5
	_barrier(bay, Vector3(-half, 0, BAY_FRONT), Vector3(-half, 0, BAY_BACK))
	_barrier(bay, Vector3(half, 0, BAY_FRONT), Vector3(half, 0, BAY_BACK))
	_barrier(bay, Vector3(-half, 0, BAY_BACK), Vector3(half, 0, BAY_BACK))
	for side in [-1.0, 1.0]:
		_barrier(bay, Vector3(side * 1.4, 0, BAY_FRONT), Vector3(side * half, 0, BAY_FRONT))
		var bench_x: float = side * 3.00
		box("Bench", Vector3(bench_x, 0.48, 12.80), Vector3(3.25, 0.10, 0.43), mat("c6a878"), bay)
		for leg in [-1.25, 1.25]:
			box("BenchLeg", Vector3(bench_x + leg, 0.22, 12.80), Vector3(0.11, 0.44, 0.39), mat("748183"), bay)
		var board := box("BayNumber", Vector3(side * 2.58, 0.72, BAY_FRONT - 0.045), Vector3(0.62, 0.43, 0.06), mat("274963"), bay)
		var number_label := label3(str(index + 1), Vector3(0, 0, -0.04), 0.27, Color.WHITE, board)
		number_label.rotation.y = PI
	for slot in 8:
		var side: float = -1.0 if slot < 4 else 1.0
		var depth := 8.65 + float(slot % 4) * 1.12
		var position_in_bay := Vector3(side * 2.25, 0.135, depth)
		var marker := Marker3D.new()
		marker.name = "WaitingPlace%02d" % (index * 8 + slot + 1)
		marker.position = position_in_bay
		bay.add_child(marker)
		waiting_spots.append(marker.global_position)
		entry_points.append(to_global(Vector3(x, 0.135, 5.65)))
		slot_approaches.append(to_global(Vector3(x, 0.135, depth)))
		box("WaitingPlaceMark", position_in_bay - Vector3.UP * 0.142, Vector3(0.65, 0.013, 0.05), mat("d9d9bc"), bay)

func _barrier(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var metal := mat("879da2", 0.52)
	var divisions := ceili(a.distance_to(b) / 2.2)
	for row in [0.19, 0.98]:
		var rail := box("BarrierRail", (a + b) * 0.5 + Vector3.UP * row, Vector3(0.044, 0.044, a.distance_to(b)), metal, parent)
		rail.basis = Basis.looking_at(b - a)
	for i in range(divisions + 1):
		var p := a.lerp(b, float(i) / divisions)
		barrier_feet.append(Transform3D(Basis.IDENTITY, to_local(parent.to_global(p + Vector3.UP * 0.043))))
	for i in range(divisions * 9 + 1):
		var p := a.lerp(b, float(i) / (divisions * 9))
		barrier_pickets.append(Transform3D(Basis.IDENTITY, to_local(parent.to_global(p + Vector3.UP * 0.58))))

func _technical_zone() -> void:
	var area := Node3D.new()
	area.name = "TechnicalZone"
	area.position = Vector3(22.5, 0, 10.3)
	add_child(area)
	box("TechnicalFloor", Vector3(0, -0.035, 0), Vector3(9.0, 0.04, 6.2), mat("9b9d94"), area)
	for x in [-4.5, 4.5]:
		_barrier(area, Vector3(x, 0, -3.1), Vector3(x, 0, 3.1))
	_barrier(area, Vector3(-4.5, 0, 3.1), Vector3(4.5, 0, 3.1))
	box("WorkbenchTop", Vector3(0, 0.93, 2.1), Vector3(3.1, 0.12, 0.9), mat("bd9c69"), area)
	for x in [-1.32, 1.32]:
		for z in [1.77, 2.43]:
			box("WorkbenchLeg", Vector3(x, 0.44, z), Vector3(0.10, 0.88, 0.10), mat("425461"), area)
	box("Toolbox", Vector3(-0.83, 1.10, 2.23), Vector3(0.64, 0.23, 0.38), mat("b73826"), area)
	for i in 5:
		var tool := box("HandTool", Vector3(-0.27 + i * 0.22, 1.002, 1.93 + 0.035 * (i % 2)), Vector3(0.048, 0.025, 0.22), mat("56656c", 0.35), area)
		tool.rotation.y = 0.18 * i
	box("FloorPump", Vector3(1.95, 0.41, 2.31), Vector3(0.07, 0.82, 0.07), mat("c84e32"), area)
	box("PumpHandle", Vector3(1.95, 0.83, 2.31), Vector3(0.28, 0.055, 0.06), mat("30383d"), area)
	for i in 3:
		Bike.build(area, Vector3(-3.1 + 2.9 * i, 0.005, -0.6), PI * 0.38).name = "TechnicalBike%d" % (i + 1)

func _tent(parent: Node3D, center: Vector3, fabric := "f1efe2") -> void:
	for x in [-2.1, 2.1]:
		for z in [-1.9, 1.9]:
			box("TentLeg", center + Vector3(x, 1.16, z), Vector3(0.055, 2.32, 0.055), mat("e4e7de"), parent)
	var corners := [Vector3(-2.25, 2.25, -2.05), Vector3(2.25, 2.25, -2.05), Vector3(2.25, 2.25, 2.05), Vector3(-2.25, 2.25, 2.05)]
	var vertices := PackedVector3Array()
	for i in 4:
		for p in [corners[i], corners[(i + 1) % 4], Vector3.UP * 3.15]:
			vertices.append(to_local(parent.to_global(center + p)))
	surface("EventTent", vertices, mat(fabric)).reparent(parent)
	box("EventCounter", center + Vector3(0, 0.51, 0.95), Vector3(2.55, 1.02, 0.48), mat("354f66"), parent)

func _event_infield(crowd: RefCounted, density: float) -> void:
	rng.seed = 19320420
	_fence_infield_access()

	var north := _event_zone("SpectatorNorth", Vector2(16, 38), Vector2(24, 21))
	var south := _event_zone("SpectatorSouth", Vector2(-15.2, 62), Vector2(21, 17))
	_spectator_zone(north, crowd, density)
	_spectator_zone(south, crowd, density)

	var operations := _event_zone("OperationsWorkZone", Vector2(-16.5, 37.5), Vector2(24, 20))
	_tent(operations, Vector3(-7.8, 0, -6.2), "e7e6dd")
	_tent(operations, Vector3(-1.8, 0, -6.2), "e7e6dd")
	_tent(operations, Vector3(-6.5, 0, 4.3), "3d6481")
	for x in [-5.1, -1.1, 3.1]:
		_work_station(operations, Vector3(x, 0, 5.4))

	var media := _event_zone("MediaWorkZone", Vector2(16.9, 64), Vector2(24.5, 20))
	_tent(media, Vector3(6.45, 0, -6.5))
	_tent(media, Vector3(6.45, 0, 5.4), "40647c")
	_media_trailer(media)
	for z in [-4.5, -1.8, 1.1]:
		_work_station(media, Vector3(3.7, 0, z))
	_event_crew(operations, crowd)
	_event_crew(media, crowd)

func _fence_infield_access() -> void:
	var bypass := Node3D.new()
	bypass.name = "RiderBayBypass"
	add_child(bypass)
	var half := PASSAGE_WIDTH * 0.5
	# Keep the gravel crossing and every bay gate clear. Both sides of the
	# bypass lead into the grass aisle between the four fenced event zones.
	var outer_edge := PackedVector2Array([Vector2(-half, 4.47), Vector2(-22.2, 4.47), Vector2(-22.2, 23),
		Vector2(-4.1, 23), Vector2(-4.1, 27.5)])
	var inner_edge := PackedVector2Array([Vector2(-17.8, 7.2), Vector2(-17.8, 19), Vector2(3.5, 19), Vector2(3.5, 27.5)])
	for edge in [outer_edge, inner_edge]:
		for i in range(edge.size() - 1):
			_barrier(bypass, Vector3(edge[i].x, 0, edge[i].y), Vector3(edge[i + 1].x, 0, edge[i + 1].y))
	_barrier(bypass, Vector3(half, 0, 4.47), Vector3(16.6, 0, 4.47))

func _event_zone(zone_name: String, center: Vector2, size: Vector2) -> Node3D:
	var zone := Node3D.new()
	zone.name = zone_name
	zone.position = Vector3(center.x, 0, center.y)
	zone.set_meta("footprint_m", size)
	add_child(zone)
	var half := size * 0.5
	var inner_x := -signf(center.x) * half.x
	var outer_x := -inner_x
	for z in [-half.y, half.y]:
		_barrier(zone, Vector3(-half.x, 0, z), Vector3(half.x, 0, z))
	_barrier(zone, Vector3(outer_x, 0, -half.y), Vector3(outer_x, 0, half.y))
	for side in [-1.0, 1.0]:
		_barrier(zone, Vector3(inner_x, 0, side * 1.85), Vector3(inner_x, 0, side * half.y))
	var gate := Marker3D.new()
	gate.name = "GateOpening"
	gate.position.x = inner_x
	zone.add_child(gate)
	return zone

func _spectator_zone(zone: Node3D, crowd: RefCounted, density: float) -> void:
	var people: Dictionary = {}
	var size: Vector2 = zone.get_meta("footprint_m")
	var aisle_direction := -signf(zone.position.x)
	for row in range(floori(size.y / 0.83) - 1):
		var z := -size.y * 0.5 + 0.80 + row * 0.83
		for column in range(floori(size.x / 0.81) - 1):
			var x := -size.x * 0.5 + 0.74 + column * 0.81
			if absf(z) < 2.22 and x * aisle_direction > -size.x * 0.11: continue
			var concentration := 1.7 + 0.55 * cos(column * 0.53 + row * 0.45) - 0.31 * sin(row * 0.62)
			if rng.randf() >= 1.0 - pow(1.0 - density, concentration): continue
			var p := zone.position + Vector3(x + rng.randf_range(-0.22, 0.22), 0, z + rng.randf_range(-0.24, 0.24))
			var variant: String = Crowd.STANDING[rng.randi_range(0, Crowd.STANDING.size() - 1)]
			var facing := Basis(Vector3.UP, PI + rng.randf_range(-0.42, 0.42))
			Crowd.add_to_group(people, variant, Transform3D(facing, p), crowd.random_look(rng))
	crowd.emit_group(self, people, zone.name + "Crowd", [[1, 0.0, 0.0]])

func _work_station(zone: Node3D, p: Vector3) -> void:
	box("WorkTable", p + Vector3.UP * 0.89, Vector3(1.92, 0.10, 0.81), mat("d9d6c8"), zone)
	for x in [-0.78, 0.78]:
		box("TableLeg", p + Vector3(x, 0.42, 0), Vector3(0.075, 0.84, 0.66), mat("62747c"), zone)
		box("EquipmentCase", p + Vector3(x * 0.78, 1.08, 0), Vector3(0.59, 0.27, 0.48), mat("2f464f"), zone)

func _media_trailer(zone: Node3D) -> void:
	var p := Vector3(-1.5, 0, -5.4)
	box("BroadcastTrailer", p + Vector3.UP * 1.63, Vector3(7.5, 2.42, 2.5), mat("e4e3db"), zone)
	box("BroadcastTrailerRoof", p + Vector3.UP * 2.90, Vector3(7.65, 0.14, 2.60), mat("c9d1cc"), zone)
	box("TrailerAwning", p + Vector3(0.4, 2.52, 2.09), Vector3(5.68, 0.10, 1.65), mat("f1efe4"), zone)
	box("TrailerDoor", p + Vector3(-2.85, 1.47, 1.26), Vector3(0.78, 1.91, 0.035), mat("a9b9b8"), zone)
	for x in [-1.0, 0.18]:
		for z in [-1.24, 1.24]:
			box("TrailerTyre", p + Vector3(x, 0.41, z), Vector3(0.83, 0.79, 0.30), mat("292f34"), zone)
	for z in [1.35, 2.71]:
		box("AwningLeg", p + Vector3(3.15, 1.24, z), Vector3(0.07, 2.48, 0.07), mat("677a80"), zone)
	for x in [-2.5, 0, 2.5]:
		box("RoadCase", p + Vector3(x, 0.37, 3.22), Vector3(0.92, 0.74, 0.65), mat("314b61"), zone)

func _event_crew(zone: Node3D, crowd: RefCounted) -> void:
	var people: Dictionary = {}
	for i in 9:
		var x := -4.4 + float(i % 5) * 2.0 + rng.randf_range(-0.27, 0.27)
		var z := 2.7 + float(i / 5) * 3.4 + rng.randf_range(-0.28, 0.28)
		var colour := Color("d09341") if i % 3 == 0 else Color("46677e")
		var facing := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		var variant: String = "stand_m_relaxed" if i % 2 == 0 else "stand_f_talk"
		Crowd.add_to_group(people, variant, Transform3D(facing, zone.position + Vector3(x, 0, z)), crowd.staff_look(rng, colour, 0.18))
	crowd.emit_group(self, people, zone.name + "Crew", [[1, 0.0, 0.0]])
