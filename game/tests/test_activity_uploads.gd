extends SceneTree
const Store := preload("res://activity_store.gd")
class Transport extends "res://strava_client.gd":
	signal release_request
	var hold_upload := false
	var responses: Array[Dictionary] = []
	var requests: Array[Dictionary] = []
	func _ready() -> void: pass
	func has_account() -> bool: return true
	func _save_tokens(_data: Dictionary) -> void: pass
	func _http(method: int, url: String, _headers: PackedStringArray, payload: PackedByteArray) -> Dictionary:
		requests.append({"method":method, "url":url, "payload":payload})
		if url == TOKEN_URL: return {"ok":true, "data":{"access_token":"fixture"}}
		if hold_upload and method == HTTPClient.METHOD_POST: await release_request
		assert(not responses.is_empty())
		return responses.pop_front()
var failures := 0
var receipts: Array[Dictionary] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func checkpoint(entry: Dictionary) -> bool:
	receipts.append(entry.duplicate(true)); return true
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var store := Store.new(); store.folder = "user://activities_test_%d" % Time.get_ticks_usec()
	var samples: Array[Dictionary] = [{"time_s":0,"distance_m":0,"power_w":120,"game_speed_kmh":30,"cadence_rpm":80,"heart_rate_bpm":130},{"time_s":10,"distance_m":90,"power_w":220,"game_speed_kmh":35,"cadence_rpm":90,"heart_rate_bpm":140}]
	var metadata := {"id":"race_fixture","started_unix":1730000000,"title":"Vélodrome - Omnium - Scratch","description":"Fixture","omnium_id":"tournament","discipline":"scratch"}
	var entry := store.capture(metadata, samples)
	check(not entry.is_empty(), "Completed activity persists")
	var fit := FileAccess.get_file_as_bytes(store.path(entry.id,"fit"))
	check(fit.slice(8,12).get_string_from_ascii() == ".FIT", "Permanent FIT written")
	check(store.load_activity(entry.id).started_unix == metadata.started_unix, "Original time survives reload")
	entry.status = "uploaded"; entry.activity_id = "12345678900"; check(store.save(entry), "Receipt persists")
	check(store.capture(metadata,samples).status == "uploaded", "Repeated capture retains upload receipt")
	check(FileAccess.get_file_as_bytes(store.path(entry.id,"fit")) == fit, "FIT is immutable")
	check(store.export_fit(entry.id,store.folder.path_join("export.fit")) == OK, "FIT export after reload")
	check(store.load_activity("../unsafe").is_empty(), "Reject unsafe IDs")
	check(store.load_activity("old-result").is_empty(), "No invented ride data for older results")
	var client := Transport.new(); root.add_child(client)
	entry.status = "pending"; entry.upload_id = ""; entry.activity_id = ""
	client.responses = [{"ok":true,"data":{"id":9876543210,"id_str":"9876543210","activity_id":null,"error":null}}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(receipts[0].status == "submitting", "Persist uncertainty before POST")
	check(entry.status == "processing" and entry.upload_id == "9876543210", "Persist upload ID before polling")
	check('name="external_id"\r\n\r\nrace_fixture.fit' in client.requests[-1].payload.get_string_from_utf8(), "Stable external ID")
	client.responses = [{"ok":false,"code":0}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "processing", "Offline poll never resubmits")
	client.responses = [{"ok":true,"data":{"activity_id":12345678900,"error":null}}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uploaded" and entry.activity_id == "12345678900", "Poll completes original upload")
	entry.status = "pending"; entry.upload_id = ""; entry.activity_id = ""
	client.responses = [{"ok":false,"code":0}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uncertain", "POST timeout remains uncertain")
	client.responses = [{"ok":true,"items":[{"external_id":"race_fixture.fit","id":12345678900}]}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uploaded", "Reconcile timed-out POST without resubmitting")
	entry.status = "uncertain"; entry.upload_id = ""; entry.activity_id = ""; entry.submitted_at = Time.get_unix_time_from_system()
	client.responses = [{"ok":false,"code":403}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uncertain", "Missing read scope never permits another upload")
	client.responses = [{"ok":true,"items":[]}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uncertain", "Allow server processing to settle")
	entry.status = "pending"
	client.responses = [{"ok":false,"code":400,"message":"fixture duplicate of activity 12345678900"}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "uploaded", "Strava duplicate resolves original activity ID")
	entry.status = "pending"; entry.upload_id = ""; entry.activity_id = ""
	client.responses = [{"ok":false,"code":429,"message":"rate limit"}]
	await client.archive_step(entry,store.path(entry.id,"fit"),checkpoint)
	check(entry.status == "retry" and entry.retry_at > Time.get_unix_time_from_system()+800, "Rate limits defer retry")
	var uploads := root.get_node("ActivityUploads")
	check(not uploads.auto_upload, "Auto-upload defaults off")
	check(uploads.capture({"demo":true},samples).is_empty(), "No auto archive/upload of simulated rides")
	var queue := preload("res://activity_uploads.gd").new()
	queue.store.folder = store.folder
	queue.settings_path = store.folder.path_join("settings.cfg")
	root.add_child(queue); queue.set_process(false)
	queue.client.free(); queue.client = client
	var next_metadata := metadata.duplicate(); next_metadata.id = "queue_fixture"
	var queued := store.capture(next_metadata, samples)
	var before := client.requests.size()
	await queue._run_next()
	check(client.requests.size() == before, "Auto-upload off makes no requests")
	queue.request_upload(str(queued.id))
	client.responses = [{"ok":false,"code":0}]
	await queue._run_next()
	check(store.load_activity(queued.id).status == "uncertain", "Manual upload works with auto-upload off and persists timeout")
	# A manually requested upload keeps polling even while the automatic option
	# is off. It must not leave the result permanently in 'processing'.
	queued = store.load_activity(queued.id)
	queued.status = "processing"; queued.upload_id = "777"; queued.retry_at = 0
	store.save(queued)
	client.responses = [{"ok":true,"data":{"activity_id":34567,"error":null}}]
	await queue._run_next()
	check(store.load_activity(queued.id).status == "uploaded", "Manual upload continues polling with auto-upload off")
	queued.status = "submitting"; queued.upload_id = ""; queued.activity_id = ""; queued.retry_at = 0
	store.save(queued)
	var double_metadata := metadata.duplicate(); double_metadata.id = "double_fixture"
	store.capture(double_metadata, samples)
	queue.request_upload("double_fixture"); queue.request_upload("double_fixture")
	check(queue.manual.size() == 1, "Repeated clicks enqueue exactly one request")
	client.hold_upload = true
	client.responses = [{"ok":true,"data":{"activity_id":77777,"error":null}}]
	queue._run_next()
	check(queue.busy, "One upload owns the queue during network wait")
	queue.request_upload("double_fixture")
	await queue._run_next()
	check(queue.manual.is_empty(), "Repeated clicks during POST do not enqueue another upload")
	client.hold_upload = false; client.release_request.emit()
	await process_frame
	check(store.load_activity("double_fixture").status == "uploaded", "Original request completes once")
	queue.set_auto_upload(true)
	queue.free()
	var restored := preload("res://activity_uploads.gd").new()
	restored.store.folder = store.folder; restored.settings_path = store.folder.path_join("settings.cfg")
	root.add_child(restored); restored.set_process(false)
	check(restored.auto_upload, "Auto-upload option survives restart")
	check(restored.store.load_activity(queued.id).status == "uncertain", "Interrupted submission becomes uncertain after restart")
	client.responses = [{"ok":true,"items":[{"external_id":"queue_fixture.fit","id":12345}]}]
	restored.client.free(); restored.client = client
	queued = store.load_activity(queued.id); queued.retry_at = 0; store.save(queued)
	await restored._run_next()
	check(store.load_activity(queued.id).status == "uploaded", "Automatic queue resumes and verifies after reconnection/restart")
	# Do not let the fixture queue own the transport, which is a root child.
	restored.free()
	var gps: Array[int] = preload("res://fit_export.gd")._location_position(0, {"latitude":50.0,"longitude":3.0})
	check(absf(float(gps[0])*180.0/2147483648.0 - 50.0) < 0.001, "FIT supports saved venue latitude")
	check(absf(float(gps[1])*180.0/2147483648.0 - 3.0) < 0.001, "FIT supports saved venue longitude")
	client.queue_free()
	var directory := DirAccess.open(store.folder)
	for filename in directory.get_files(): directory.remove(filename)
	DirAccess.remove_absolute(store.folder)
	print("ACTIVITY_UPLOADS failures=",failures)
	quit(1 if failures else 0)
