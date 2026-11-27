extends Node
## One persistent queue for races, training and manual uploads from saved results.
signal changed(id: String)
signal status_changed(message: String)
const Store := preload("res://activity_store.gd")
var store := Store.new()
var client: Node
var auto_upload := false
var busy := false
var manual: Array[String] = []
var settings := ConfigFile.new()
var settings_path := "user://activity_settings.cfg"
var elapsed := 0.0

func _ready() -> void:
	settings.load(settings_path)
	auto_upload = bool(settings.get_value("strava", "auto_upload", false))
	client = preload("res://strava_client.gd").new()
	add_child(client)
	client.status_changed.connect(func(message: String): status_changed.emit(message))
	for entry in store.all():
		if entry.status == "submitting":
			entry.status = "uncertain"
			store.save(entry)

func set_auto_upload(enabled: bool) -> void:
	settings.set_value("strava", "auto_upload", enabled)
	if settings.save(settings_path) != OK:
		status_changed.emit(tr("ACTIVITY_SAVE_FAILED")); return
	auto_upload = enabled
	elapsed = 60.0

func capture(metadata: Dictionary, samples: Array[Dictionary], gps: bool = true) -> String:
	if metadata.get("demo", false): return ""
	var entry := store.capture(metadata, samples, gps)
	if entry.is_empty():
		status_changed.emit(tr("ACTIVITY_SAVE_FAILED")); return ""
	changed.emit(str(entry.id))
	elapsed = 60.0
	return str(entry.id)

func capture_training(activity: Dictionary, virtual: bool = false) -> String:
	if activity.get("demo", false) or virtual: return ""
	var samples: Array[Dictionary] = []
	for sample in activity.get("samples", []): samples.append(sample)
	var metadata := activity.duplicate(true)
	metadata.erase("samples")
	metadata.merge(preload("res://training_activity_metadata.gd").build(activity), true)
	return capture(metadata, samples, true)

func request_upload(id: String) -> void:
	var entry := store.load_activity(id)
	if entry.is_empty() or entry.status == "uploaded" or manual.has(id): return
	if busy and client.upload_path == store.path(id, "fit"): return
	entry["manual_upload"] = true
	if not store.save(entry):
		status_changed.emit(tr("ACTIVITY_SAVE_FAILED")); return
	manual.append(id)
	changed.emit(id)
	if not client.has_account() or entry.get("needs_auth", false): client.reconnect()
	elapsed = 60.0

func _process(delta: float) -> void:
	elapsed += delta
	if busy or elapsed < 30.0: return
	elapsed = 0.0
	_run_next()

func _checkpoint(entry: Dictionary) -> bool:
	var saved := store.save(entry)
	if saved: changed.emit(str(entry.id))
	else: status_changed.emit(tr("ACTIVITY_SAVE_FAILED"))
	return saved

func _run_next() -> void:
	if busy or client.working or is_instance_valid(client.pending_dialog): return
	if not client.has_account(): return
	var entry := {}
	while not manual.is_empty() and entry.is_empty(): entry = store.load_activity(manual.pop_front())
	if entry.is_empty():
		for candidate in store.all():
			if (auto_upload or candidate.get("manual_upload", false)) and candidate.status in ["pending", "processing", "uncertain", "retry"] and float(candidate.get("retry_at", 0)) <= Time.get_unix_time_from_system():
				if entry.is_empty() or float(candidate.get("retry_at", 0)) < float(entry.get("retry_at", 0)):
					entry = candidate
	if entry.is_empty() or entry.status == "uploaded": return
	busy = true
	status_changed.emit(tr("ACTIVITY_UPLOADING"))
	await client.archive_step(entry, store.path(str(entry.id), "fit"), _checkpoint)
	busy = false
	status_changed.emit(tr("ACTIVITY_RECONNECT") if entry.get("needs_auth", false) else tr("ACTIVITY_" + str(entry.status).to_upper()))
