extends SceneTree
const Store := preload("res://training_store.gd")
const History := preload("res://training_history.gd")
class ActivityPage extends RefCounted:
	var selected := {}
	func show_activity(activity: Dictionary) -> void: selected = activity
class Menu extends RefCounted:
	var training_store := Store.new()
	var derny_page := ActivityPage.new()
	var madison_page := ActivityPage.new()
	var exercise_page := ActivityPage.new()
	var route := ""
	func show_piste_training() -> void: route = "piste"
	func show_derny() -> void: route = "derny"
	func show_madison_training() -> void: route = "madison"
	func show_piste_exercise(kind: String) -> void: route = kind
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900)
	var menu := Menu.new()
	menu.training_store.folder = "user://test_piste_history_%d" % Time.get_ticks_usec()
	var records: Array[Dictionary] = [
		{"id":"zzzz-old","kind":"derny","title":"Dernytraining","started_unix":1794800000,"started_local":"2026-11-16 07:30:00","duration_s":1234,"start_speed_kmh":30,"completed_kmh":42,"final":true},
		{"id":"aaaa-new","kind":"flying_start","title":"Vliegende start","started_unix":1794810000,"started_local":"2026-11-16 10:20:00","duration_s":180,"exercise_success":true,"entry_speed_kmh":51.4,"peak_power_w":930,"final":true},
		{"id":"legacy","title":"Dernytraining","started_unix":1794790000,"started_local":"2026-11-16 06:00:00","duration_s":600,"final":true},
		{"id":"madison","kind":"madison","title":"Aflossingstraining","started_unix":1794804000,"started_local":"2026-11-16 08:40:00","duration_s":900,"reason":"Training voltooid","final":true},
		{"id":"free","kind":"free_ride","title":"Vrij rijden","started_unix":1794805000,"started_local":"2026-11-16 09:00:00","duration_s":1200,"reason":"Handmatig gestopt","demo":true},
		{"id":"lap","kind":"take_lap","title":"Ronde nemen","started_unix":1794806000,"started_local":"2026-11-16 09:20:00","duration_s":480,"reason":"Ronde genomen","final":true},
		{"id":"ftp","kind":"ftp_test","title":"FTP test","started_unix":1794820000},
		{"id":"erg","kind":"erg_workout","title":"ERG workout","started_unix":1794830000},
		{"id":"unknown","kind":"race","started_unix":1794840000}
	]
	for record in records:
		record.version = 1; record.samples = []
		check(menu.training_store.save(record),"Save history fixture")
	var latest := menu.training_store.recent(1,History.PISTE_KINDS)
	check(latest.size() == 1 and latest[0].id == "aaaa-new","Filter and timestamp sort happen before limit, independent of filename")
	check(menu.training_store.recent(1)[0].id == "unknown","Default archive uses timestamp order for other consumers")
	var fallback := Store.activity_time({"started_local":"2026-11-16 10:20:00"})
	check(fallback > 0,"Legacy local dates remain sortable")
	var canvas := PanelContainer.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.theme = preload("res://menu_theme.gd").create()
	canvas.add_theme_stylebox_override("panel",preload("res://menu_theme.gd").panel(Color("f5f1e7"),Color("bc8a43"),48,16))
	root.add_child(canvas)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation",24); canvas.add_child(layout)
	var title := Label.new(); title.text = "Opgeslagen pistetrainingen"; title.add_theme_font_size_override("font_size",36); layout.add_child(title)
	var page := History.new(); page.menu = menu; layout.add_child(page); page.refresh()
	check(page.rows.get_child_count() == 6,"Only piste kinds and legacy derny appear, excluding FTP, ERG and races")
	check(page.rows.get_child(0).get_meta("activity_id") == "aaaa-new" and page.rows.get_child(5).get_meta("activity_id") == "legacy","Newest session appears first and oldest last")
	page.rows.get_child(0).pressed.emit()
	check(menu.route == "flying_start" and menu.exercise_page.selected.id == "aaaa-new","Click opens correct exercise details")
	page._open_activity(records[0]); check(menu.route == "derny","Derny navigation preserved")
	page._open_activity(records[3]); check(menu.route == "madison","Madison navigation preserved")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://piste_history.png")
	for record in records: DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store._path(record.id)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.training_store.folder))
	page.refresh()
	check(page.rows.get_child_count() == 1 and page.rows.get_child(0) is Label,"Empty history shows helpful message")
	canvas.free()
	print("PISTE_HISTORY failures=",failures)
	quit(0 if failures == 0 else 1)
