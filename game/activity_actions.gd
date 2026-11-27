extends HBoxContainer
## Shared saved-activity controls, also usable without an active race scene.
var activity_id := ""
var uploads: Node
var status: Label
var upload: Button
var export: Button
var view: Button

func _ready() -> void:
	uploads = get_node("/root/ActivityUploads")
	status = Label.new()
	status.custom_minimum_size.x = 180
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	upload = Button.new(); upload.text = "MAIN_EXPORT_TO_STRAVA"; add_child(upload)
	upload.pressed.connect(func(): uploads.request_upload(activity_id))
	export = Button.new(); export.text = "RESULT_EXPORT_FIT"; add_child(export)
	export.pressed.connect(_export)
	view = Button.new(); view.text = "ACTIVITY_VIEW_STRAVA"; add_child(view)
	view.pressed.connect(func():
		var entry: Dictionary = uploads.store.load_activity(activity_id)
		if not str(entry.get("activity_id", "")).is_empty(): OS.shell_open("https://www.strava.com/activities/" + str(entry.activity_id)))
	uploads.changed.connect(_changed)
	_refresh()

func _changed(id: String) -> void:
	if id == activity_id: _refresh()

func _refresh() -> void:
	var entry: Dictionary = uploads.store.load_activity(activity_id)
	var available := not entry.is_empty() and FileAccess.file_exists(uploads.store.path(activity_id, "fit"))
	export.visible = available
	upload.visible = available and entry.get("status") != "uploaded"
	upload.disabled = (entry.get("status") in ["submitting", "processing"] and not entry.get("needs_auth", false)) or uploads.manual.has(activity_id)
	view.visible = available and entry.get("status") == "uploaded"
	if entry.get("needs_auth", false):
		status.text = tr("ACTIVITY_RECONNECT"); return
	status.text = tr("ACTIVITY_" + str(entry.get("status", "pending")).to_upper()) if available else tr("ACTIVITY_NO_DATA")

func _export() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.fit ; FIT"])
	dialog.current_file = activity_id + ".fit"
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty(): dialog.current_dir = downloads
	dialog.file_selected.connect(func(destination: String):
		var result: Error = uploads.store.export_fit(activity_id, destination)
		status.text = tr("ACTIVITY_EXPORTED") if result == OK else tr("ACTIVITY_SAVE_FAILED")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog); dialog.popup_centered(Vector2i(900, 600))
