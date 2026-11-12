extends Node3D
## User-provided GLB. Ride loops; signals play once then return to riding.
const MODEL := preload("res://assets/derny/derny_pilot.glb")
const CLIPS := {"ride":"DP_DernyRide", "look_back":"DP_DernyLookBack", "speed_up":"DP_DernySpeedUp", "slow_down":"DP_DernySlowDown"}
var animator: AnimationPlayer
var last_gesture := "ride"
var gesture_count := {"look_back":0, "speed_up":0, "slow_down":0}
func _ready() -> void:
	var model := MODEL.instantiate()
	# Blender forward -Y becomes glTF +Z, matching the game rider rigs.
	add_child(model)
	animator = model.find_child("AnimationPlayer", true, false)
	if animator == null:
		push_error("Derny model has no AnimationPlayer")
		return
	for key in CLIPS:
		var clip: Animation = animator.get_animation(CLIPS[key])
		clip.loop_mode = Animation.LOOP_LINEAR if key == "ride" else Animation.LOOP_NONE
	animator.animation_finished.connect(_finished)
	animator.play(CLIPS.ride)
func gesture(action: String) -> void:
	if animator == null or not CLIPS.has(action): return
	# A speed signal has priority over a look over the shoulder.
	if action == "look_back" and last_gesture in ["speed_up","slow_down"] and animator.is_playing(): return
	last_gesture = action
	gesture_count[action] += 1
	animator.play(CLIPS[action], .18)
func _finished(_clip: StringName) -> void:
	last_gesture = "ride"
	animator.play(CLIPS.ride, .18)
