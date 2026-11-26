extends SceneTree
## Real race motors on both geometries, without rendering or live devices.
const Venues := preload("res://venues/venue_catalog.gd")
const Runtime := preload("res://venues/venue_runtime.gd")
class Race extends "res://main.gd":
 func _ready() -> void:
  set_physics_process(false)
  elimination_notice = Label.new(); add_child(elimination_notice)
 func _spawn_peloton() -> void: pass
 func _take_finish_photo(_winner: int) -> void: pass
 func _take_elimination_photo(_rider: int, _line: float) -> void: pass
 func _save_recording(_reason: String) -> void: pass
 func _register_performance() -> void: pass
 func _record_ai_performances() -> void: pass
 func _capture_demo_fit_sample() -> void: pass
 func _capture_player_demo_fit_sample(_force: bool = false) -> void: pass
var failures := 0
func check(value: bool, message: String) -> void:
 if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for id in Venues.available_ids():
  for mode in [0, 1, 2, 3, 4, 5, 7, 8]:
   var game := Race.new(); root.add_child(game)
   Runtime.configure(game, Venues.find(id))
   game.race_mode = mode; game.rider_count = 8; game.team_size = 3
   game.race_laps = 10 if mode == 1 else 6 if mode in [3, 8] else 14 if mode == 2 else roundi(1000.0 / game.LAP) if mode in [4, 5, 7] else 3
   game._configure_peloton()
   game.demo_launch_watts = 320.0; game.watts = 320.0
   if mode in [4, 5, 7]:
    game._prepare_pursuit({}, 300.0)
    if mode == 5: game.team_race.prepare(game, {}, 300.0)
   game._begin_riding()
   if mode in [0, 1, 2, 8]: game._finish_neutral_start()
   check(is_equal_approx(game.track_geometry.LAP, game.LAP), id + " geometry uses race length")
   if mode in [0, 1, 2, 3, 8]: check(is_equal_approx(game.x_ai.LAP, game.LAP), id + " AI wraps on venue length")
   var ticks := 0
   while not game._all_riders_finished() and ticks < 12000:
    if mode == 3: game.keirin.advance(game, .1)
    else:
     game.clock += .1
     game._advance_race(.1)
    ticks += 1
   check(game._all_riders_finished(), "%s mode %d completes" % [id, mode])
   if mode not in [2, 5]:
    for distance in game.distances: check(absf(distance - game._race_length()) < .01 or mode in [0, 1, 8], "%s mode %d finishes at exact event distance" % [id, mode])
   if mode == 5:
    for distance in game.team_race.progress: check(absf(distance - game._race_length()) < .01, id + " first-wheel team finish")
   if mode in [4, 5, 7]:
    check(game.pursuit_half_crossings[0].size() == game.race_laps * 2, id + " half-lap crossings")
   if mode == 1: check(game.points_rules.sprints[-1].lap == 10, id + " final points sprint")
   if mode == 8: check(game.tempo_rules.sprints[0].lap == 5, id + " tempo starts at lap five")
   if mode == 3: check(absf(game.keirin.EXIT_M - game.LAP * 3.0) < .001, id + " derny exits after three laps")
   print("VENUE_RACE ", id, " mode=", mode, " ticks=", ticks, " finished=", game._all_riders_finished())
   game.free()
   await process_frame
 print("MULTIPLE_VENUE_RULES_OK" if failures == 0 else "MULTIPLE_VENUE_RULES_FAILED %d" % failures)
 quit(0 if failures == 0 else 1)
