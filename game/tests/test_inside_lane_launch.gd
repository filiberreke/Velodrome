extends SceneTree
class TestRace extends "res://main.gd":
	func _ready() -> void:set_physics_process(false)
	func _spawn_peloton() -> void:pass
	func _take_finish_photo(_winner: int) -> void:pass
	func _save_recording(_reason: String) -> void:pass
	func _capture_demo_fit_sample() -> void:pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	for count in [8,12,16]:
		var reference: Dictionary = {}
		var baseline_slow: Array[int] = []
		for enabled in [false,true]:
			var game = TestRace.new();root.add_child(game)
			game.rider_count=count;game.race_laps=10 if count==8 else 50
			game._configure_peloton()
			# Official racing starts after the approach and full neutral opening lap.
			game.watts=300.0;game._begin_riding()
			for tick in range(1500):
				if game.start_state!="NEUTRAL":break
				game.neutral_start.step(game,.1)
			check(game.start_state=="RACING","Launch fixture completes the neutral start")
			game.rider_forms.fill(1.0)
			game.x_ai.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
			game.x_ai.prefer_inside_when_free=enabled;game.x_ai.rng.seed=23102026
			for i in range(1,count):
				game.x_ai.cooldown[i]=75.0+5.0*i;game.x_ai.cooperation[i]=0.6;game.x_ai.aggression[i]=0.6
			game.watts=300.0;game.running=true;game.start_state="RACING"
			while game.clock<10.0:
				game.clock+=0.1;game._update_race(0.1)
			var slow: Array[int] = []
			for i in range(1,count):
				if game.speeds[i]<=2.0 or game.distances[i]<=10.0:slow.append(i)
				if count<=12:check(game.speeds[i]>2.0 and game.distances[i]>10.0,"AI starts under own power in field %d" % count)
			var snapshot := {"speed":game.speeds.duplicate(),"distance":game.distances.duplicate(),"lanes":game.lane_offsets.duplicate(),"wprime":game.x_ai.wprime.duplicate()}
			if not enabled:reference=snapshot;baseline_slow=slow.duplicate()
			else:
				for ident in slow:check(baseline_slow.has(ident),"Default inside creates a new slow launch in field %d" % count)
			print("INSIDE_LANE_LAUNCH ",JSON.stringify({"count":count,"enabled":enabled,"baseline_equal":snapshot==reference,"slow_ids":slow,"baseline_slow_ids":baseline_slow}))
			game.free()
	print("INSIDE_LANE_LAUNCH_OK" if failures==0 else "INSIDE_LANE_LAUNCH_FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
