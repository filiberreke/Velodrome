extends Node3D
## Radial Warren trusses follow the existing faceted canopy, including its
## banking-dependent eave height. No pillars are introduced in the infield.
const Steel := preload("res://arena_steel.gd")
var arena: Node3D

func build(owner_arena: Node3D) -> void:
	arena = owner_arena
	name = "ArenaRoofStructure"
	arena.add_child(self)
	var kit := Steel.new()
	kit.material("TrussChords", "465362")
	kit.material("DiagonalBracing", "35414d")
	kit.material("GussetsAndWalkways", "64717b")
	kit.material("SafetyRails", "a49b79")
	# Closed crown compression rings join the inner ends of every radial truss.
	for i in 24:
		for h in [0.6, -0.55]:
			kit.beam("TrussChords", rib_point(float(i), 0.0) + Vector3.UP * h, rib_point(float(i + 1), 0.0) + Vector3.UP * h, 0.20)
	for i in 24:
		var s := 250.0 * float(i) / 24.0
		var edge: Vector3 = arena._stadium_point(s, 28.8, 12.0)
		var crown := Vector3(edge.x, 0, edge.z).normalized() * 3.5
		crown.y = 22.5
		edge.y -= 0.25
		# Twelve triangulated bays, slender chords and real node plates.
		for j in 12:
			var a := crown.lerp(edge, float(j) / 12.0)
			var b := crown.lerp(edge, float(j + 1) / 12.0)
			var low_a := a - Vector3.UP * 1.15
			var low_b := b - Vector3.UP * 1.15
			kit.beam("TrussChords", a, b, 0.19, 0.25)
			kit.beam("TrussChords", low_a, low_b, 0.19, 0.25)
			kit.beam("DiagonalBracing", a if j % 2 == 0 else low_a, low_b if j % 2 == 0 else b, 0.085)
			kit.beam("DiagonalBracing", a, low_a, 0.07)
			kit.box("GussetsAndWalkways", low_a, Vector3(0.29, 0.34, 0.10))
		# Continue the load path into the retained outer columns.
		var outer: Vector3 = arena._stadium_point(s, 32.35, 12.40)
		kit.beam("TrussChords", edge - Vector3.UP * 0.6, outer, 0.20, 0.32)
	# Longitudinal ties / X braces at two radii connect adjacent trusses.
	for fraction in [0.38, 0.72]:
		for i in 24:
			var a := rib_point(float(i), fraction)
			var b := rib_point(float(i + 1), fraction)
			kit.beam("DiagonalBracing", a, b, 0.11)
			if i % 2 == 0:
				kit.beam("DiagonalBracing", a, rib_point(float(i + 1), fraction + 0.12), 0.065)
	# Technical racetrack ring supports all screen hoists. A pair of service
	# bridges links it to radial trusses; narrow grating and double guardrails.
	for i in 24:
		var low := service_point(float(i) / 24.0)
		var nearest := Vector3.ZERO
		var best_distance := INF
		for rib in 24:
			var a := rib_point(float(rib), 0.0)
			var b := rib_point(float(rib), 1.0)
			var along := Vector2(b.x - a.x, b.z - a.z)
			var t := clampf(Vector2(low.x - a.x, low.z - a.z).dot(along) / along.length_squared(), 0.0, 1.0)
			var high := a.lerp(b, t)
			var separation := Vector2(high.x - low.x, high.z - low.z).length_squared()
			if separation < best_distance:
				best_distance = separation
				nearest = high
		kit.beam("DiagonalBracing", low, nearest, 0.095)
		kit.box("GussetsAndWalkways", nearest, Vector3(0.30, 0.25, 0.30))
	for i in 96:
		var a := service_point(float(i) / 96.0)
		var b := service_point(float(i + 1) / 96.0)
		kit.beam("GussetsAndWalkways", a, b, 0.65, 0.12)
		for side in [-1.0, 1.0]:
			var n: Vector3 = Vector3(a.x, 0, a.z * 0.35).normalized() * float(side) * 0.32
			for h in [0.55, 1.05]:
				kit.beam("SafetyRails", a + n + Vector3.UP * h, b + n + Vector3.UP * h, 0.035)
			if i % 3 == 0: kit.beam("SafetyRails", a + n, a + n + Vector3.UP * 1.05, 0.04)
	for sign_x in [-1.0, 1.0]:
		var a := Vector3(sign_x * 7.0, 19.5, 0)
		# Locate the actual side-straight centre through the arena coordinate API.
		var side_s := 0.0
		var best := INF
		for sample in 250:
			var candidate: Vector3 = arena._point(float(sample), 28.8)
			var score := absf(candidate.z) + (1000.0 if candidate.x * sign_x < 0.0 else 0.0)
			if score < best:
				best = score
				side_s = float(sample)
		var edge: Vector3 = arena._stadium_point(side_s, 28.8, 10.8)
		kit.beam("GussetsAndWalkways", a, edge, 0.65, 0.12)
		for side in [-0.32, 0.32]:
			kit.beam("SafetyRails", a + Vector3(0, 1.05, side), edge + Vector3(0, 1.05, side), 0.04)
	kit.flush(self)

func rib_point(index: float, fraction: float) -> Vector3:
	var edge: Vector3 = arena._stadium_point(fposmod(index, 24.0) * 250.0 / 24.0, 28.8, 11.75)
	var crown := Vector3(edge.x, 0, edge.z).normalized() * 3.5
	crown.y = 22.5
	return crown.lerp(edge, fraction) - Vector3.UP * 0.6

func service_point(u: float) -> Vector3:
	var p: Vector3 = arena._point(u * 250.0, -7.0)
	return Vector3(p.x * 7.0 / 11.0, 19.5, p.z * 0.39)
