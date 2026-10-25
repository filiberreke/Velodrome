extends SceneTree
const Pacer := preload("res://pursuit_pacer.gd")
class Model extends "res://main.gd":
	func _ready() -> void:
		pass
	func _save_recording(_reason: String) -> void:
		pass

func _initialize() -> void:
	var game = Model.new()
	game.race_mode = 4
	var failed := false
	for cp in [50.0, 100.0, 250.0, 500.0, 800.0]:
		for distance in [1000.0, 4000.0]:
			var pacer = Pacer.new()
			pacer.prepare(game, distance, cp, game._rider_distance(1, 0.0), game.LANES[0])
			print("PURSUIT_LEVEL cp=%.0f distance=%.0f watts=%.2f predicted_s=%.2f" % [cp, distance, pacer.target_w, pacer.predicted_seconds])
			if not is_finite(pacer.predicted_seconds) or pacer.predicted_seconds <= 0.0:
				failed = true
	game.free()
	print("PURSUIT_LEVELS_OK" if not failed else "PURSUIT_LEVELS_FAILED")
	quit(1 if failed else 0)
