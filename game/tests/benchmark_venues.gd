extends SceneTree
## Run with a real renderer, --resolution 1600x900 --disable-vsync.
## Isolate user preferences with XDG_DATA_HOME and explicitly opt in below.
const OUTPUT := "res://verification/venue_benchmark"
const WARMUP_SECONDS := 8.0
const SETTLE_SECONDS := 2.0
const SAMPLE_SECONDS := 10.0
var viewport: SubViewport
var results := {"samples": []}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("VELODROME_BENCHMARK_ISOLATED") != "1":
		push_error("Set a separate XDG_DATA_HOME and VELODROME_BENCHMARK_ISOLATED=1; benchmark writes display settings.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark requires a real rendered display, not --headless.")
		quit(2)
		return
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(preview)
	results["hardware"] = {"godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(), "renderer": RenderingServer.get_current_rendering_method(), "cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(), "display": DisplayServer.get_name(), "vsync_mode": DisplayServer.window_get_vsync_mode()}
	results["protocol"] = {"resolution": [1600, 900], "msaa": 4, "crowd_density": .60, "riders": 12, "rider_rpm": 92, "race_simulation": false, "hud": false, "static_rider_positions": true, "native_venue_lighting": true, "warmup_seconds": WARMUP_SECONDS, "warmup_min_frames": 12, "camera_settle_seconds": SETTLE_SECONDS, "camera_settle_min_frames": 4, "sample_seconds": SAMPLE_SECONDS, "repeats": 3, "source_commit": OS.get_environment("VELODROME_BENCHMARK_COMMIT"), "started_utc": Time.get_datetime_string_from_system(true)}
	print("VENUE BENCHMARK HARDWARE ", JSON.stringify(results.hardware))
	_save()
	# Reverse venue order for simple mode. Only one stadium is resident at a time.
	for simple in [false, true]:
		var venues := ["velodrome", "gent"] if not simple else ["gent", "velodrome"]
		for venue_id in venues:
			var config := ConfigFile.new()
			config.set_value("arena", "crowd_density", .60)
			config.set_value("arena", "simple_infield", simple)
			config.save(preload("res://config_paths.gd").user_path("display_settings.cfg"))
			seed(20261126)
			var game := preload("res://tests/venue_benchmark_game.gd").new()
			game.venue = load("res://venues/%s.tres" % venue_id).duplicate(true)
			game.benchmark_simple = simple
			print("VENUE BENCHMARK BUILD ", venue_id, " simple=", simple)
			viewport.add_child(game)
			await _wait_seconds(WARMUP_SECONDS, 12)
			for repeat in 3:
				var views := ["overview", "track"] if repeat % 2 == 0 else ["track", "overview"]
				for view in views:
					game.set_benchmark_view(view)
					await _wait_seconds(SETTLE_SECONDS, 4)
					if repeat == 0:
						viewport.get_texture().get_image().save_jpg(OUTPUT + "/%s_%s_%s.jpg" % [venue_id, "simple" if simple else "normal", view], .88)
					var sample: Dictionary = await _measure()
					sample.merge({"venue": venue_id, "simple": simple, "view": view, "repeat": repeat + 1, "nodes": game.get_child_count(true)})
					results.samples.append(sample)
					_save()
					print("VENUE BENCHMARK SAMPLE ", JSON.stringify(sample))
			game.free()
			await process_frame
	results["completed_utc"] = Time.get_datetime_string_from_system(true)
	_save()
	print("VENUE BENCHMARK COMPLETE ", results.samples.size(), " samples")
	quit()

func _wait_seconds(seconds: float, minimum_frames: int) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	var frames := 0
	while Time.get_ticks_usec() < until or frames < minimum_frames:
		await RenderingServer.frame_post_draw
		frames += 1

func _measure() -> Dictionary:
	var times: Array[float] = []
	var calls := 0.0
	var primitives := 0.0
	var began := Time.get_ticks_usec()
	var previous := began
	while Time.get_ticks_usec() - began < int(SAMPLE_SECONDS * 1000000.0):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		calls += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		primitives += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var elapsed := float(previous - began) / 1000000.0
	times.sort()
	var count := times.size()
	return {"frames": count, "elapsed_seconds": elapsed, "fps": float(count) / elapsed, "mean_frame_ms": elapsed * 1000.0 / count, "median_frame_ms": times[count / 2], "p95_frame_ms": times[mini(count - 1, ceili(count * .95) - 1)], "draw_calls_mean": calls / count, "primitives_mean": primitives / count}

func _save() -> void:
	var file := FileAccess.open(OUTPUT + "/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  ") + "\n")
