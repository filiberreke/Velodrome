extends SceneTree
class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)
	func _spawn_peloton() -> void: pass
	func _save_recording(_reason: String) -> void: pass
	func _take_finish_photo(_winner: int) -> void: pass
	func _register_performance() -> void: pass
	func _capture_demo_fit_sample() -> void: pass
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for mode in [0,1,2,3]:
		for percent in [40.,60.,80.,100.]:
			var game := Game.new(); root.add_child(game)
			game.race_mode = mode; game.rider_count = 6; game.ai_difficulty = percent
			game.race_laps = 20
			game._configure_peloton()
			var ai = game.x_ai
			var reference = ai.get_script().new()
			reference.reset(game.rider_profiles,game.rider_forms,game.lane_offsets)
			reference.configure_riders(game.rider_identities,game.rider_forms)
			for i in range(1,game.rider_count):
				check(is_equal_approx(ai.cp[i],reference.cp[i]*percent/100.),"Startup scales CP after identity/form")
				check(is_equal_approx(ai.wmax[i],reference.wmax[i]*percent/100.),"Startup scales Wprime")
				check(is_equal_approx(ai.pmax[i],reference.pmax[i]*percent/100.),"Startup scales peak")
				check(ai.wprime[i] == ai.wmax[i],"Reserve starts full")
				check(ai._phys_power(i,100000.,.1) <= ai.pmax[i] + .000001,"Actual watts respect scaled peak")
			check(ai.cp[0] == reference.cp[0],"Human is not scaled")
			if mode in [0,1,2]:
				game._finish_neutral_start()
				for i in range(1,game.rider_count):
					check(is_equal_approx(ai.cp[i],reference.cp[i]*percent/100.),"Neutral start preserves scaled CP")
					check(is_equal_approx(ai.pmax[i],reference.pmax[i]*percent/100.),"Neutral start preserves scaled peak")
					check(is_equal_approx(ai.wprime[i],reference.wmax[i]*percent/100.),"Neutral start preserves scaled reserve")
			game.free()
	var game := Game.new(); root.add_child(game); game.race_mode = 4
	var last_target := 0.; var last_seconds := INF
	for percent in [40.,60.,80.,100.]:
		var pacer = preload("res://pursuit_pacer.gd").new()
		pacer.difficulty_percent = percent; pacer.wprime_j = 24000.; pacer.max_power_w = 900.
		pacer.prepare(game,1000.,300.,game._rider_distance(1,0.),game.LANES[0])
		check(is_equal_approx(pacer.cp_w,300.*percent/100.),"Pursuit CP percentage")
		check(is_equal_approx(pacer.reserve_j,24000.*percent/100.),"Pursuit energy percentage")
		check(is_equal_approx(pacer.power_limit_w,900.*percent/100.),"Pursuit peak percentage")
		check(pacer.target_w > last_target and pacer.predicted_seconds < last_seconds,"Stronger pursuit rider predicts faster finish")
		check(is_equal_approx(pacer.power(0),pacer.target_w),"No second difficulty multiplier")
		last_target = pacer.target_w; last_seconds = pacer.predicted_seconds
		pacer.prepare(game,1000.,300.,game._rider_distance(1,0.),game.LANES[0])
		check(is_equal_approx(pacer.target_w,last_target),"Repeated preparation does not compound scaling")
		pacer.power(100000.)
		check(pacer.reserve_j >= 0. and is_equal_approx(pacer.power(1.),pacer.cp_w),"Exhausted reserve falls back to scaled CP")
		print("V02_PURSUIT percent=",percent," watts=",last_target," seconds=",last_seconds)
	game.free()
	# The team opponent uses the same scaled pacer through its actual setup path.
	for percent in [40.,60.,80.,100.]:
		var team := Game.new(); root.add_child(team)
		team.race_mode = 5; team.race_laps = 4; team.pursuit_opponent_percent = percent
		team._configure_peloton(); team.team_race.prepare(team,{},300.)
		check(is_equal_approx(team.team_race.pacer.cp_w,300.*percent/100.),"Team pursuit scales opponent CP")
		check(is_equal_approx(team.team_race.pacer.reserve_j,20000.*percent/100.),"Team pursuit scales opponent reserve")
		team.free()
	print("V02_CAPACITY failures=",failures)
	quit(0 if failures == 0 else 1)
