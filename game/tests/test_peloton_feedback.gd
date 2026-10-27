extends SceneTree
const State := preload("res://peloton_state.gd")
const Rules := preload("res://points_race_rules.gd")
class TestRace extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var jury = Rules.new()
	jury.reset(5)
	var raw: Array[float] = [1002.,1004.,1006.,1008.,1252.]
	jury._judge_laps(raw,20.)
	var positions: Array[float] = State.race_positions(raw,jury.credits)
	check(jury.points[4] == 20 and positions[4] == positions[0],"Lap gain adds 20 and returns rider to bunch race position")
	check(raw[4] == 1252.,"Odometer is retained independently")
	var state = State.new()
	var bunch: Dictionary = state.sample(raw,jury.credits,[])
	check(bunch.ids.size() == 5 and State.gap_text(positions[4],bunch) == "In het peloton","Rejoined rider is recognized inside main bunch")
	check(State.gap_text(1030.,bunch).contains("vóór") and State.gap_text(980.,bunch).contains("achter"),"Signed bunch gap uses front and rear")
	jury.reset(4,10)
	jury.credits.assign([1,0,0,0])
	var ends: Array[float] = [-1.,-1.,-1.,-1.]
	jury.advance([2499.,2240.,2242.,2244.],[2501.,2242.,2244.,2246.],2.,2.,ends)
	check(jury.finish_clock < 0. and jury.sprints.is_empty(),"Gained lap cannot trigger an early sprint or finish")
	jury.advance([2749.,2490.,2492.,2494.],[2751.,2492.,2494.,2496.],4.,2.,ends)
	check(jury.finish_clock == 3. and jury.sprints.size() == 1,"Normalized race lap triggers the correct finish")
	var game = TestRace.new()
	root.add_child(game)
	game.race_mode=1; game.race_laps=40; game.rider_count=8
	game._configure_peloton()
	game.distances.assign([110.,107.,105.,60.,62.,64.,66.,68.])
	game.speeds.fill(11.5)
	game.baseline_speed=11.5
	game.rider_forms.fill(1.)
	game.x_ai.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
	game.x_ai.rng.seed=2
	game.x_ai.cooldown.fill(999.)
	game.x_ai.cooperation.fill(0.8)
	game.watts=310.; game.clock=100.; game.start_state="RACING"; game.running=true
	var passed := false
	for tick in range(350):
		game.clock+=0.1
		game._advance_race(0.1)
		if maxf(game.distances[1],game.distances[2]) > game.distances[0]+1.0: passed=true
	check(not game.x_ai.rotation_events.is_empty(),"Small escape including human rotates turns")
	var ai_turn := false
	for event in game.x_ai.rotation_events:
		if event.members.has(0) and event.leader > 0: ai_turn=true
	check(ai_turn and passed,"AI actually passes human to take a turn")
	check(game.x_ai.wprime[1] < game.x_ai.wmax[1],"Taking over costs real Wprime")
	print("ESCAPE_ROTATIONS ",JSON.stringify(game.x_ai.rotation_events))
	# Explicit human + one AI fixture, with the main bunch kept separate.
	var ai = preload("res://x_scratch_ai.gd").new()
	var profiles: Array[int] = [0,1,1,2,3,1,2,3]
	var forms: Array[float] = [1.,1.,1.,1.,1.,1.,1.,1.]
	var lanes: Array[float] = [1.18,1.18,1.18,2.38,3.58,4.78,5.98,7.18]
	ai.reset(profiles,forms,lanes); ai.rng.seed=3; ai.cooldown.fill(999.); ai.cooperation.fill(0.8); ai.human_power_w=310.
	var distances: Array[float] = [110.,107.,60.,62.,64.,66.,68.,70.]
	var speeds: Array[float] = [11.5,11.5,11.,11.,11.,11.,11.,11.]
	var drafts: Array[float] = [0.,0.6,0.,0.6,0.6,0.6,0.6,0.6]
	var finished: Array[float] = [-1.,-1.,-1.,-1.,-1.,-1.,-1.,-1.]
	var credits: Array[int] = [0,0,0,0,0,0,0,0]
	ai.step(0.1,30.,distances,speeds,lanes,drafts,finished,profiles,40,80.,credits)
	ai.step(0.1,39.,distances,speeds,lanes,drafts,finished,profiles,40,80.,credits)
	check(ai.turns.has("[0, 1]") and ai.turns["[0, 1]"].leader == 1,"Human/AI duo is a real rotating group")
	check(ai.modes[1] == ai.MODE_BREAK_PULL and absf(ai.lane_targets[1]-lanes[0]) >= 1.0,"Taking over selects passing corridor")
	check(distances == [110.,107.,60.,62.,64.,66.,68.,70.],"Tactics never teleport physical positions")
	# Physical order remains independent from score order in the same UI update.
	game.distances.assign([100.,110.,90.,96.,98.,102.,104.,106.])
	game.points_rules.credits.fill(0)
	game.points_rules.points.assign([0,0,50,0,0,0,0,0])
	game.finish_times.fill(-1.)
	game.peloton_info=game.peloton_state.sample(game.distances,game.points_rules.credits,game.finish_times)
	game.race_overlay=preload("res://race_hud.gd").new()
	root.add_child(game.race_overlay)
	game.minimap=game.race_overlay.map
	game._update_compact_hud([2,1,7,6,5,0,4,3])
	check(game.race_overlay.points_rows[0].name.text == game._rider_name(2),"Right panel ranks by points")
	check(game.race_overlay.rider_rows[0].shell.get_meta("rider_id") == 7 and game.race_overlay.rider_rows[0].rank.text == "2","Nearby panel keeps actual rank while showing closest riders")
	check(game.race_overlay.rider_rows[0].gap.text.ends_with("m"),"Nearby gaps stay in metres")
	check(not game.race_overlay.peloton_label.text.is_empty() and not game.race_overlay.map.peloton.is_empty(),"Bunch gap and minimap indication are always supplied")
	game.peloton_markers.update_bunch(game,game.peloton_info,true)
	check(game.peloton_markers.visible and game.peloton_markers.strips.size() == 2,"Both virtual bunch boundaries exist")
	check(game._at(1002.,1.18).distance_to(game._at(1252.,1.18)) < 0.001,"Subtracting race lap keeps physical world position")
	var badge = preload("res://rider_energy_badge.gd").new()
	root.add_child(badge)
	badge.show_rider(312.,0.75,Vector3.ZERO,true,12,true)
	check(badge.reserve_label.text == "75%" and badge.watts_label.text.contains("312 W") and badge.watts_label.text.contains("12 pt"),"Badge shows actual reserve, watts and points")
	badge.show_rider(300.,-1.,Vector3.ZERO,true)
	check(badge.reserve_label.text == "W′ —","Human energy is not fabricated without CP/Wprime")
	game._announce_race_event("RONDE GEWONNEN · +20 PUNTEN")
	check(game.race_event_until == game.clock+10. and game.race_event_message.contains("+20"),"Explicit lap-gain notification persists for ten seconds")
	badge.free(); game.race_overlay.free(); game.free()
	print("PELOTON_FEEDBACK_OK" if failures == 0 else "PELOTON_FEEDBACK_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
