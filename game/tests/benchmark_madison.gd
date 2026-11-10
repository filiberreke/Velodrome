extends SceneTree
## Performance with 16 visible riders: 16 normal riders vs 14 normal + 2 in a Madison exchange (AnimationTree + IK).
## Measures CPU time of the per-frame rider update (pedal + controller tick + idle frame processing) and, when run
## windowed, the real frame time. Usage:
##   godot --headless --path game --script res://tests/benchmark_madison.gd
##   godot --rendering-driver opengl3 --rendering-method gl_compatibility --path game --script res://tests/benchmark_madison.gd
const FRAMES := 600
func _initialize() -> void:
	call_deferred("run_test")

func _riders(n: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in n:
		var v: Node3D = load("res://rider_visual.gd").new()
		v.set_meta("rider_index", i % 4)
		root.add_child(v)
		v.position = Vector3(-1.2 * float(i % 4), 0.0, 3.0 * float(i / 4))
		out.append(v)
	return out

func _measure(riders: Array[Node3D], ex: MadisonDemoExchange, label: String) -> Dictionary:
	var work := 0.0
	var wall := 0.0
	var worst := 0.0
	var t_wall := Time.get_ticks_usec()
	for f in FRAMES:
		var t0 := Time.get_ticks_usec()
		if ex != null:
			if ex.state == MadisonDemoExchange.State.IDLE:
				ex.start(riders[5], riders[6], MadisonDemoExchange.Mode.EASY, "")     # loop: setup/teardown cost is included
			ex.set_gameplay(1.2, MadisonProfile.delta_f(ex.sling_t))
			ex.tick(1.0 / 60.0)
		for r in riders:
			r.pedal(1.0 / 60.0, 80.0, 300.0)
		var dt := float(Time.get_ticks_usec() - t0)
		work += dt
		worst = maxf(worst, dt)
		await process_frame
	wall = float(Time.get_ticks_usec() - t_wall)
	var res := {"label": label, "update_ms_avg": work / FRAMES / 1000.0, "update_ms_worst": worst / 1000.0, "frame_ms_avg": wall / FRAMES / 1000.0}
	print("%-34s update %.3f ms/frame (worst %.3f), whole frame %.3f ms" % [label, res["update_ms_avg"], res["update_ms_worst"], res["frame_ms_avg"]])
	return res

func run_test() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var riders := _riders(16)
	for i in 30:
		await process_frame
	var base := await _measure(riders, null, "16 normal riders")
	var ex := MadisonDemoExchange.new()
	root.add_child(ex)
	riders[5].position = Vector3.ZERO
	riders[6].position = Vector3(-1.2, 0.0, 0.0)
	var t0 := Time.get_ticks_usec()
	ex.start(riders[5], riders[6], MadisonDemoExchange.Mode.ADVANCED, "")
	print("exchange setup (2 trees + IK): %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	ex.cancel()
	var with_ex := await _measure(riders, ex, "14 normal + 2 exchanging (looped, Easy)")
	ex.cancel()
	await process_frame
	var after := await _measure(riders, null, "16 normal riders after cleanup")
	var delta := float(with_ex["update_ms_avg"]) - float(base["update_ms_avg"])
	print("extra cost of one exchange (2 riders): %.3f ms/frame; per rider %.3f ms" % [delta, delta / 2.0])
	print("result: base %.3f / exchange %.3f / after %.3f ms update per frame" % [base["update_ms_avg"], with_ex["update_ms_avg"], after["update_ms_avg"]])
	quit(0)
