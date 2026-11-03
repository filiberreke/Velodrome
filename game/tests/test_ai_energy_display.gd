extends SceneTree

class Game extends "res://main.gd":
	func _ready() -> void: set_physics_process(false)

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var game := Game.new()
	game.rider_count = 4
	game.rider_profiles.assign([0, 1, 2, 3])
	game.rider_forms.assign([1.0, 0.97, 1.04, 1.02])
	game.rider_names.assign(["Speler", "Tijdrijder", "Sprinter", "Aanvaller"])
	game.ai_power_w.assign([0.0, 239.0, 156.0, 229.0])
	game.ai_energy_j.assign([0.0, 90000.0, 90000.0, 90000.0])
	game.tt_effort_remaining = 0.01
	var identities: Array[Dictionary] = [{}, {"w_prime_factor":0.85,"cp_factor":1.0,"max_power_factor":1.0}, {"w_prime_factor":1.3,"cp_factor":1.0,"max_power_factor":1.0}, {"w_prime_factor":1.6,"cp_factor":1.0,"max_power_factor":1.0}]
	var lanes: Array[float] = [1.18,1.18,2.38,3.58]
	for mode in [0, 1, 2]:
		game.race_mode = mode
		game.x_ai.reset(game.rider_profiles, game.rider_forms, lanes)
		game.x_ai.configure_riders(identities, game.rider_forms)
		for difficulty in [60.0, 100.0]:
			game.ai_difficulty = difficulty
			for fraction in [0.0, 0.42, 1.0]:
				for i in range(1, 4): game.x_ai.wprime[i] = game.x_ai.wmax[i] * fraction
				var text := game._ai_diagnostics_text()
				check(text.contains("CP / W-prime model X") and not text.contains("beta.10"), "All shared-model events identify the current energy model")
				for i in range(1, 4):
					check(text.contains("%s: %d%%  %.0f W" % [game.rider_names[i], roundi(fraction*100.0), game.ai_power_w[i]]), "Correct real capacity and once-scaled watts, mode %d rider %d fraction %.2f" % [mode,i,fraction])
	# Recreate the screenshot values with neutral base physiology.
	game.race_mode = 2
	game.rider_forms.fill(1.0)
	game.x_ai.reset(game.rider_profiles, game.rider_forms, lanes)
	game.x_ai.wprime[2] = 18000.0 * 1.59
	game.x_ai.wprime[3] = 30000.0 * 1.05
	var corrected := game._ai_diagnostics_text()
	check(corrected.contains("Sprinter: 93%  156 W") and corrected.contains("Aanvaller: 96%  229 W"), "Screenshot reserves use their real maximum instead of legacy capacity")
	for i in range(1,4):
		for tick in range(1000):
			game.x_ai._phys_power(i, game.x_ai.pmax[i] if tick < 500 else 0.0, 0.1)
			check(game.x_ai.wprime[i] >= 0.0 and game.x_ai.wprime[i] <= game.x_ai.wmax[i], "Physical reserve stays bounded during depletion and recovery")
	game.free()
	print("AI_ENERGY_DISPLAY failures=",failures)
	quit(0 if failures == 0 else 1)
