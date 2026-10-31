extends Node3D
## Visible LED clusters only. The existing 4 Omni + 8 Spot lights stay intact.
const Steel := preload("res://arena_steel.gd")
func build(arena: Node3D) -> void:
	name = "ProfessionalFloodlights"
	arena.add_child(self)
	var kit := Steel.new()
	kit.material("HousingsAndYokes", "303c49")
	kit.material("CoolingFins", "687780")
	kit.material("LEDReflectors", "d4e0e8", 0.75)
	kit.material("LEDSegments", "f0f5ff", 0.0, 0.65)
	for i in 24:
		var s := 250.0 * (float(i) + 0.5) / 24.0
		var mount: Vector3 = arena._stadium_point(s, 28.8, 18.0)
		var target: Vector3 = arena._point(s, 3.6)
		var normal := (target - mount).normalized()
		var x := Vector3.UP.cross(normal).normalized()
		var basis := Basis(x, normal.cross(x), normal)
		var row := 3 if absf(mount.z) < 32.0 else 4
		kit.beam("HousingsAndYokes", mount - x * 3.5, mount + x * 3.5, 0.15)
		for hook in [-2.7, 2.7]:
			kit.beam("HousingsAndYokes", mount + x * hook, mount + x * hook + Vector3.UP * 0.95, 0.09)
		for j in row:
			var p := mount + x * (float(j) - float(row - 1) * 0.5) * 1.60 - Vector3.UP * 0.65
			kit.box("HousingsAndYokes", p, Vector3(1.37, 0.91, 0.32), basis)
			# U-shaped bracket and tilt pivots visibly connect each fixture.
			for side in [-0.75, 0.75]:
				kit.beam("CoolingFins", p + x * side, p + x * side + Vector3.UP * 0.65, 0.07)
			for f in 8:
				kit.box("CoolingFins", p + basis * Vector3(-0.58 + f * 0.165, 0, -0.21), Vector3(0.035, 0.78, 0.15), basis)
			for col in 4:
				for r in 2:
					var cell := p + basis * Vector3(-0.48 + col * 0.32, -0.21 + r * 0.42, 0.17)
					kit.box("LEDReflectors", cell, Vector3(0.28, 0.35, 0.035), basis)
					kit.box("LEDSegments", cell + normal * 0.025, Vector3(0.21, 0.27, 0.025), basis)
	kit.flush(self)
