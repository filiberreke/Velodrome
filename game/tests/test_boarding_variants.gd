extends SceneTree
const Sponsors := preload("res://boarding_sponsors.gd")
class Track extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
class Shell extends "res://arena.gd":
	func _ready() -> void: pass
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; push_error(message)

func weight(color: Color, corrected: bool, linear_input: bool = true) -> float:
	var c := color.srgb_to_linear() if linear_input else color
	var mask := smoothstep(0.02, 0.06, c.b - maxf(c.r, c.g))
	var brightness := minf(c.r, minf(c.g, c.b)) if corrected else maxf(c.r, maxf(c.g, c.b))
	return mask * (1.0 - smoothstep(0.4 if corrected else 0.65, 0.75 if corrected else 0.9, brightness))

func _initialize() -> void: call_deferred("run_test")

func run_test() -> void:
	check(Sponsors.POSTER_SHADER.code.contains("min(color.r, min(color.g, color.b))"), "Shader protects neutral white rather than bright blue")
	var old_partial := 0
	var samples := 0
	for file in ["wielerpraat-boarding.png", "pelotonpredictor-boarding.png"]:
		var texture: Texture2D = load("res://assets/boarding/" + file)
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		for x in range(0, image.get_width(), 17):
			for y in range(0, image.get_height(), 17):
				var color := image.get_pixel(x, y)
				var linear := color.srgb_to_linear()
				# Exclude lettering/antialiasing: sample the blue background across
				# the whole image, including brighter central parts of its gradient.
				if linear.b - maxf(linear.r, linear.g) < 0.061 or minf(color.r, color.g) > 0.38: continue
				check(is_equal_approx(weight(color, true), 1.0), "Both poster backgrounds map fully to shared blue")
				check(is_equal_approx(weight(color, true, false), 1.0), "Shared blue also exact for Compatibility renderer sRGB input")
				if weight(color, false, false) < 0.999: old_partial += 1
				samples += 1
	check(weight(Color.WHITE, true) == 0.0 and weight(Color("ff8000"), true) == 0.0, "White and orange remain unchanged")
	var game := Track.new(); root.add_child(game)
	var arena := Shell.new(); game.add_child(arena); arena.main = game
	Sponsors.build(arena)
	var blue: MeshInstance3D = arena.get_node("VelodromeLaatsteRechteLijn_0")
	var light: MeshInstance3D = arena.get_node("VelodromeLaatsteRechteLijn_1")
	var count: int = light.get_meta("total_panels")
	check(count % 2 == 0, "Even blue/light alternation ends with light")
	check(blue.material_override.get_shader_parameter("poster") == Sponsors.VELODROME and light.material_override.get_shader_parameter("poster") == Sponsors.VELODROME_LIGHT, "Correct light and blue artwork")
	check(not light.material_override.get_shader_parameter("match_blue") and not blue.material_override.get_shader_parameter("match_blue"), "Velodrome variants retain their colours")
	var arrays: Array = light.mesh.surface_get_arrays(0)
	var end: Vector3 = arena._point(game.LAP, Sponsors.OFFSET) - arena._outward(game.LAP) * Sponsors.INSET + Vector3.UP * Sponsors.BASE
	var touches_end := false
	for point in arrays[Mesh.ARRAY_VERTEX]:
		if point.distance_to(end) < 0.001: touches_end = true
	check(touches_end, "Final light panel reaches finish and start of first bend")
	for name in ["SponsorsEersteBocht_0", "SponsorsEersteBocht_1"]:
		check(arena.get_node(name).material_override.get_shader_parameter("match_blue"), "Both curve sponsors use shared background correction")
	game.free()
	print("BOARDING_VARIANTS_OK samples=%d old_partial=%d panels=%d" % [samples, old_partial, count] if failures == 0 else "BOARDING_VARIANTS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
