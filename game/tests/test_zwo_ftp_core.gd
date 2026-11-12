extends SceneTree
const Zwo := preload("res://zwo_workout.gd")
const Twenty := preload("res://ftp_twenty_min.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var workout := Zwo.new()
	var xml := '<workout_file><author>Velodrome</author><name>Voorbeeld</name><description>Test</description><workout><Warmup Duration="300" PowerLow="0.4" PowerHigh="0.7"><textevent timeoffset="30" message="Rustig beginnen"/></Warmup><SteadyState Duration="120" Power="0.8"/><IntervalsT Repeat="2" OnDuration="30" OffDuration="30" OnPower="1.1" OffPower="0.5"/></workout></workout_file>'
	check(workout.parse(xml), "Valid ZWO must parse")
	check(workout.name == "Voorbeeld", "Workout name")
	check(workout.blocks.size() == 6, "IntervalsT expands into on/off steps")
	check(is_equal_approx(workout.duration(), 540.0), "Duration includes repeated intervals")
	check(workout.blocks[0].events.size() == 1, "Timed text is preserved")
	check(not workout.parse("<workout_file><workout/></workout_file>"), "Empty workout rejected")
	var ftp := Twenty.new()
	ftp.start(0.0)
	for t in range(1201):
		ftp.sample(float(t), 200.0)
	check(ftp.complete(), "Twenty minutes of continuous power completes")
	check(is_equal_approx(ftp.ftp(), 190.0), "FTP is 95 percent of mean")
	ftp.start(0.0)
	ftp.sample(0.0, 200.0)
	ftp.sample(2.0, 200.0)
	check(not ftp.complete() and ftp.ftp() == 0.0, "Missing samples cannot produce FTP")
	print("ZWO_FTP_CORE failures=", failures)
	quit(0 if failures == 0 else 1)
