extends SceneTree

class Race:
	extends Node3D
	var start_state := "NEUTRAL"
	var finished := false
	var distances := [0.0, 0.0]
	var finish_times := [-1.0, -1.0]
	var race_laps := 4
	var countdown := 1.0
	func _at(s: float, offset: float) -> Vector3:
		return Vector3(18.0 + offset, 0.0, s)

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var details = load("res://infield_details.gd").new()
	var race := Race.new()
	details.game = race
	# Build only the production official, without constructing the stadium.
	details._build_flag_official()
	var player: AnimationPlayer = details.flag_anim
	check(details.official_clips.size() == 4, "Four exact animation names must be discovered")
	check(details.official_clips["VO_StartFire"] != details.official_clips["VO_StartReady"], "Ready must not shadow fire")
	race.distances = [189.0, 180.0]
	details._process(0.0)
	check(not details.official_start_ready, "Do not prepare before 60 m")
	race.distances = [190.0, 180.0]
	details._process(0.0)
	check(details.official_action == "VO_StartReady", "Use dedicated ready at 60 m")
	player.advance(0.0)
	player.seek(player.current_animation_length, true)
	check(not details.flag_node.find_child("FX_MuzzleFlash*",true,false).visible, "Ready has no flash")
	check(not details.flag_node.find_child("FX_Smoke*",true,false).visible, "Ready has no smoke")
	check(details.flag_node.find_child("PROP_StartPistol*",true,false).visible, "Ready shows pistol")
	var skeleton: Skeleton3D = details.flag_node.find_child("Skeleton3D",true,false)
	check(skeleton != null and skeleton.get_bone_count() == 21, "Keep user 21 bone rig")
	var hand := skeleton.find_bone("hand.R")
	var raised := skeleton.get_bone_global_pose(hand)
	race.distances = [245.0, 230.0]
	details._process(0.0)
	player.advance(0.0)
	check(details.official_action == "VO_StartFire", "Fire at 5 m")
	check(details.flag_node.find_child("FX_MuzzleFlash*",true,false).visible, "Fire shows original flash")
	check(raised.origin.distance_to(skeleton.get_bone_global_pose(hand).origin) < 0.03, "Ready to fire keeps raised hand continuous")
	race.start_state = "RACING"
	race.distances = [700.0, 680.0]
	details._process(0.0)
	player.advance(0.0)
	check(details.official_action == "VO_LastLapBell", "Bell starts 50 m before final lap")
	check(player.get_animation(details.official_clips["VO_LastLapBell"]).loop_mode == Animation.LOOP_LINEAR, "Bell loops")
	race.distances = [750.0, 740.0]
	details._process(0.0)
	check(details.official_action == "VO_LastLapBell", "Bell waits for last rider")
	race.distances = [900.0, 740.0]
	details._process(0.0)
	check(details.official_action == "VO_FinishFlag", "Finish overrides bell at 100 m")
	race.finish_times = [10.0, 11.0]
	details._process(0.0)
	check(details.official_action == "", "Finish stops when all riders finish")
	details._process(0.0)
	check(details.official_action == "", "Finish does not restart")
	race.start_state = "SETUP"
	details._process(0.0)
	check(not details.official_start_ready and not details.official_start_fired, "Next race resets start states")
	var report := {"passed": failures.is_empty(), "failures": failures, "clips": player.get_animation_list(), "rig_bones": skeleton.get_bone_count()}
	var f := FileAccess.open("user://official_ready_validation.json",FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(report,"  "))
	print("OFFICIAL_VALIDATION ", JSON.stringify(report))
	details.flag_node.free()
	details.free()
	race.free()
	quit(0 if failures.is_empty() else 1)
