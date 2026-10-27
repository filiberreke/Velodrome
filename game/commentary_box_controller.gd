extends Node3D
## Independent, engine-driven mouth animations. Call set_speaking for audio cues.
var voices: Array[AnimationPlayer] = []
var talk_clips: Array[StringName] = []

func setup(model: Node3D) -> void:
	var imported := model.find_children("*", "AnimationPlayer", true, false)
	if imported.is_empty():
		push_error("EuroMaxCycling: missing mouth animations")
		return
	var source := imported[0] as AnimationPlayer
	source.stop()
	for label in ["LeftTalk", "RightTalk"]:
		var clip: StringName = &""
		for candidate in source.get_animation_list():
			if String(candidate).contains(label):
				clip = candidate
				break
		if clip == &"":
			push_error("EuroMaxCycling: missing " + label)
			continue
		var player := AnimationPlayer.new()
		player.name = label + "Player"
		# Same parent/root as the glTF player preserves imported blend-shape paths.
		for library_name in source.get_animation_library_list():
			player.add_animation_library(library_name, source.get_animation_library(library_name))
		source.get_parent().add_child(player)
		player.root_node = source.root_node
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR
		voices.append(player)
		talk_clips.append(clip)
		player.play(clip)
		player.pause()
		player.seek(0.0, true)

func set_speaking(commentator: int, speaking: bool) -> void:
	if commentator < 0 or commentator >= voices.size():
		return
	var player := voices[commentator]
	if speaking:
		player.play(talk_clips[commentator])
	else:
		player.pause()
		# Rest frame is an almost closed, relaxed smile.
		player.seek(0.0, true)
