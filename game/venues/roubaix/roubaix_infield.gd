extends "res://venues/gent/gent_build.gd"

const Bike := preload("res://venues/gent/parked_bike.gd")
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

func build(host: Node3D, profile: Resource, route: RefCounted) -> void:
	venue = profile
	track = route
	gate_distance = venue.transition_m * 0.5 + venue.finish_straight_clearance_m - track.geometry.STRAIGHT * 0.5
	var inward: Vector3 = -track.outward(gate_distance)
	var origin: Vector3 = track.at(gate_distance, 0.0)
	origin.y = 0.015
	transform = Transform3D(Basis(Vector3.UP.cross(inward), Vector3.UP, inward), origin)
	box("GravelCrossing", Vector3(0, -0.022, 2.15), Vector3(PASSAGE_WIDTH, 0.05, 4.4), mat("ab9d82"))
	box("AccessPath", Vector3(0, -0.04, 5.60), Vector3(33.2, 0.045, 3.15), mat("a5a69d"))
	for index in 3:
		_waiting_bay(index, -11.0 + index * 11.0)
	_technical_zone()
	for z in [22.0, 28.5]:
		for x in [-18.0, -11.0, -4.0]:
			_tent(Vector3(x, 0, z))
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
		box("BarrierFoot", p + Vector3.UP * 0.043, Vector3(0.34, 0.073, 0.34), metal, parent)
	for i in range(divisions * 9 + 1):
		var p := a.lerp(b, float(i) / (divisions * 9))
		box("BarrierPicket", p + Vector3.UP * 0.58, Vector3(0.027, 0.79, 0.027), metal, parent)

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

func _tent(center: Vector3) -> void:
	for x in [-2.1, 2.1]:
		for z in [-1.9, 1.9]:
			box("TentLeg", center + Vector3(x, 1.16, z), Vector3(0.055, 2.32, 0.055), mat("e4e7de"))
	var corners := [Vector3(-2.25, 2.25, -2.05), Vector3(2.25, 2.25, -2.05), Vector3(2.25, 2.25, 2.05), Vector3(-2.25, 2.25, 2.05)]
	var vertices := PackedVector3Array()
	for i in 4:
		vertices.append_array(PackedVector3Array([center + corners[i], center + corners[(i + 1) % 4], center + Vector3.UP * 3.15]))
	surface("WhiteEventTent", vertices, mat("f1efe2"))
	box("EventCounter", center + Vector3(0, 0.51, 0.95), Vector3(2.55, 1.02, 0.48), mat("354f66"))
