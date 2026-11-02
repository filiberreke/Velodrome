extends SceneTree
const Page := preload("res://records_page.gd")
class History extends "res://time_trial_records.gd":
	var rides: Array = []
	func all_rides() -> Array: return rides
class Store extends "res://performance_records.gd":
	func import_saved(_libraries: Array = []) -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var history := History.new()
	history.rides = [
		{"id":"legacy", "distance_m":500, "seconds":48.5, "finished_at":100.0, "splits":[15.0,26.0,37.0,48.5]},
		{"id":"flying_1k", "distance_m":1000, "start_type":"flying", "seconds":92.0, "finished_at":101.0, "splits":[12.0,23.0,34.0,45.0,56.0,67.0,79.0,92.0]}]
	var page := Page.new()
	page.time_trials = history
	page.store = Store.new()
	root.add_child(page)
	page.open_records()
	check(page.mode_choice.get_selected_id() == 7 and page.distance_choice.selected == 1 and page.distance_choice.get_selected_id() == 1000 and page.start_choice.selected == 1, "Latest flying 1 km opens at correct filters")
	check(page.shown.size() == 1 and page.shown[0].id == "flying_1k", "Saved 1 km flying result is visible")
	page.refresh()
	check(page.distance_choice.selected == 1 and page.shown.size() == 1, "Refreshing never resets 1 km time trial to 500 m")
	page.distance_choice.select(0)
	page.start_choice.select(0)
	page.refresh()
	check(page.shown.size() == 1 and page.shown[0].id == "legacy", "Legacy standing 500 m remains separate")
	page.open_records()
	check(page.distance_choice.selected == 0 and page.start_choice.selected == 0, "Reopening keeps deliberate filters when no new result exists")
	history.rides.append({"id":"new_flying_1k", "distance_m":1000, "start_type":"flying", "seconds":90.0, "finished_at":102.0, "splits":[11.0,22.0,33.0,44.0,55.0,66.0,78.0,90.0]})
	page.open_records()
	check(page.distance_choice.selected == 1 and page.start_choice.selected == 1 and page.shown.size() == 2 and page.shown[0].id == "new_flying_1k", "New ride selects its category and sorts all matching records")
	page.mode_choice.select(0)
	page.distance_choice.select(1)
	page.refresh()
	check(page.distance_choice.get_selected_id() == 4000 and page.category.text.contains("4 km"), "Pursuit keeps its 4 km filter")
	page.mode_choice.select(2)
	page.refresh()
	check(page.distance_choice.get_selected_id() == 1000 and page.shown.size() == 2, "Returning to time trial converts 4 km index into 1 km")
	page.free()
	print("TIME_TRIAL_RECORD_FILTERS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
