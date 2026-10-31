extends SceneTree
const Model := preload("res://infinity_scoreboard_model.gd")
const Rules := preload("res://points_race_rules.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func frame(mode := 0) -> Dictionary:
	return {"mode": mode, "discipline": "PUNTENKOERS" if mode == 1 else "SCRATCH", "phase": "RACING", "clock": 20.0,
		"laps": 20, "length": 5000.0, "lap_length": 250.0, "positions": [1000., 990., 980., 970.],
		"names": ["Ada", "Bram", "Cleo", "Daan"], "order": [0, 1, 2, 3], "finishes": [-1., -1., -1., -1.], "winner": -1,
		"all_finished": false, "lap_times": [[], []], "half_splits": [[], []], "events": [], "sprints": [], "points": [0, 0, 0, 0], "gains": [0, 0, 0, 0], "next_sprint": 10, "breakaway": ""}
func run() -> void:
	var model := Model.new()
	var cues: Array[String] = []
	model.stadium_cue.connect(func(kind: String, _data: Dictionary): cues.append(kind))
	var f := frame()
	f.phase = "INTRO"
	model.update(f, .1)
	check(model.state == Model.INTRO and model.view().footer.contains("20 RONDEN"), "Intro has actual discipline and distance")
	f.phase = "RACING"
	model.update(f, .1)
	check(model.state == Model.RACE and model.laps_left() == 16, "Scratch shows leader laps")
	f.positions = [4750., 4700., 4600., 4500.]
	model.update(f, .1)
	check(model.view().headline == "FINAL LAP" and cues.count("final_lap") == 1, "Final lap stadium moment")
	for i in 60: model.update(f, .1)
	check(cues.count("final_lap") == 1 and model.moment.is_empty(), "Final lap never repeats every frame")
	# Real jury records and awards, including a physically lapped sprinter.
	var jury := Rules.new()
	jury.reset(4, 20)
	var ends: Array[float] = [-1., -1., -1., -1.]
	jury.advance([2498.,2248.,2497.,2497.], [2502.,2251.,2501.,2500.5], 12., 2., ends)
	f = frame(1)
	f.clock = 12.; f.positions = [2502.,2251.,2501.,2500.5]
	f.sprints = jury.sprints; f.points = jury.points; f.events = jury.events; f.gains = jury.gains
	model.update(f, .1)
	check(model.state == Model.SPRINT and model.moment == "sprint_result", "Jury crossing triggers sprint result")
	check(model.view().rows[0].contains("+5 PT") and model.view().rows[1].contains("Bram"), "Official sprint order and awards displayed")
	for i in 70: model.update(f, .1)
	check(cues.count("sprint_result") == 1, "Sprint result consumed once")
	f = frame(1); f.positions = [2390., 2380., 2370., 2360.]
	model.reset(); model.update(f, .1)
	check(model.state == Model.SPRINT and model.moment == "sprint", "Actual sprint proximity triggers opening animation")
	# Read an actual +20 lap award, not a display-invented score.
	jury.reset(5, 20)
	jury._judge_laps([1002.,1004.,1006.,1008.,1252.], 15.)
	f = frame(1); f.clock = 15.
	f.names.append("Elin"); f.positions.append(1252.); f.finishes.append(-1.)
	f.order = [4, 0, 1, 2, 3]; f.points = jury.points; f.events = jury.events; f.gains = jury.gains
	model.reset(); model.update(f, .1)
	check(model.state == Model.LAP_GAIN and model.view().headline == "+20 POINTS" and model.view().badge == "Elin", "Lap gain name and score")
	var locked: Array = jury.points.duplicate()
	for i in 30: model.update(f, .1)
	check(jury.points == locked and jury.events.size() == 1, "Display never changes jury points/events")
	# Finish immediately preempts any queued animation, while keeping results live.
	f.winner = 0; f.finishes[0] = 51.0
	model.update(f, .1)
	check(model.state == Model.FINISH and model.pending.is_empty() and model.view().badge.contains("VOORLOPIG"), "Finish wins event priority")
	f.winner = 4; f.all_finished = true
	model.update(f, .1)
	check(model.view().headline == "Elin" and model.view().badge == "WINNAAR", "Late jury standings update provisional winner")
	check(cues.count("finish") == 1, "Victory cue does not repeat")
	check(cues.count("winner_confirmed") == 1 and model.age < .01, "Confirmed jury winner receives its own victory cue")
	model.update(f, 16.)
	check(model.view().page == 1 and model.view().rows[0].begins_with("4"), "Final results page through the entire field")
	f.phase = "SETUP"; f.clock = 0.; f.winner = -1; f.events = []; f.sprints = []
	model.update(f, .1)
	check(model.state == Model.INTRO and model.pending.is_empty() and model.event_cursor == 0, "Reset removes stale events")
	for mode in [4, 5]:
		f = frame(mode)
		f.discipline = "PLOEGENACHTERVOLGING" if mode == 5 else "ACHTERVOLGING"
		f.names = ["Team Alpha", "Team Beta"] if mode == 5 else ["Ada", "Bram"]
		f.positions = [1000., 990.]; f.order = [0, 1]; f.finishes = [-1., -1.]
		f.lap_times = [[18.2, 17.7], [18.6]]
		f.split_times = [35.9, 27.0]; f.checkpoint_m = 375.; f.gap_seconds = .42
		model.update(f, .1)
		check(model.view().headline.contains("0.42") and model.view().rows[0].contains("0:17.70"), "Pursuit lap and shared checkpoint gap")
	print("INFINITY_MODEL_OK failures=", failures)
	quit(1 if failures else 0)
