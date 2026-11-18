extends "res://omnium/omnium_race_controller.gd"
func discipline() -> String: return "elimination"
func stage() -> int: return 2
func mode() -> int: return 2
func elimination_interval_m() -> float:
	return 250.0 * int(Formats.settings(String(context.format)).elimination_interval)

func result_data(game: Node) -> Dictionary:
	var result := super.result_data(game)
	var eliminated: Array = []
	for index in game.elimination_rules.eliminated: eliminated.append(String(game.rider_identities[index].id))
	result["elimination_order"] = eliminated
	result["elimination_interval_m"] = elimination_interval_m()
	return result
