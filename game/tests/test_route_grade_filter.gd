extends SceneTree
## Trainer grade on a constant line: the bend climb must not become a pedal wall,
## while sustained height changes still reach the full grade.
const Client := preload("res://trainer_control.gd")
class StillGame extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run_test")

func ride(game: Node, lane: float, speed_mps: float, seconds: float) -> Dictionary:
	var filter := Client.RouteGradeFilter.new()
	var dt := 1.0 / 60.0
	var distance := 0.0
	var raw_peak := 0.0
	var trainer_peak := 0.0
	var trainer_low := 0.0
	var t := 0.0
	while t < seconds:
		var previous: Vector3 = game._at(distance, lane)
		distance += speed_mps * dt
		var raw := Client.route_grade(previous, game._at(distance, lane))
		var value := filter.step(raw, dt)
		if t > 20.0: # One lap of settling before measuring.
			raw_peak = maxf(raw_peak, raw)
			trainer_peak = maxf(trainer_peak, value)
			trainer_low = minf(trainer_low, value)
		t += dt
	return {"raw": raw_peak, "peak": trainer_peak, "low": trainer_low}

func run_test() -> void:
	var game := StillGame.new(); root.add_child(game)
	var blue := ride(game, 3.555, 35.0 / 3.6, 60.0)
	print("ROUTE_GRADE_FILTER blue_35kmh ", JSON.stringify(blue))
	check(blue.raw > 5.5, "Stayers line really climbs into the bend (%.2f%%)" % blue.raw)
	check(blue.peak < 3.0 and blue.low > -3.0, "Trainer sees a damped bend wave (%.2f / %.2f%%)" % [blue.peak, blue.low])
	check(blue.peak > 1.0, "Bend climb remains noticeable (%.2f%%)" % blue.peak)
	var black := ride(game, 1.005, 35.0 / 3.6, 60.0)
	check(black.peak < 0.3, "Measuring line stays practically flat (%.2f%%)" % black.peak)
	game.free()
	var filter := Client.RouteGradeFilter.new()
	for i in range(60 * 30): filter.step(5.0, 1.0 / 60.0)
	check(absf(filter.value - 5.0) < 0.01, "Sustained grade reaches the full value (%.3f)" % filter.value)
	filter.reset()
	var first := filter.step(5.0, 1.0 / 60.0)
	check(first > 0.0 and first < 0.2, "Step response starts with the small direct share (%.3f)" % first)
	check(filter.step(5.0, 0.0) == first, "Zero time step changes nothing")
	print("ROUTE_GRADE_FILTER_OK" if failures == 0 else "ROUTE_GRADE_FILTER_FAILED %d" % failures)
	quit(failures)
