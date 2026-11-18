extends SceneTree
const Selection := preload("res://omnium/omnium_selection.gd")
func _initialize() -> void:
	var draft := Selection.new()
	draft.riders = [{"id":"player", "country":"player_country", "is_player":true}]
	for i in range(24):
		draft.catalog.entries.append({"id":str(i), "country":str(i), "category":"men"})
	for i in range(23):
		assert(draft.can_add())
		assert(draft.add(draft.catalog.entries[i]))
	assert(draft.riders.size() == 24 and draft.opponent_count() == 23)
	assert(not draft.can_add())
	assert(not draft.add(draft.catalog.entries[23]))
	assert(draft.riders.size() == 24)
	assert(draft.remove(1))
	assert(draft.can_add() and draft.add(draft.catalog.entries[23]))
	assert(draft.riders.size() == 24 and draft.opponent_count() == 23)
	# Oversized or older copied lists cannot add a second player or a 24th AI.
	var old := {"riders":[{"id":"player", "country":"other"}]}
	old.riders.append_array(draft.catalog.entries)
	draft.copy_from(old, {"id":"player", "country":"player_country"})
	assert(draft.riders.size() == 24 and draft.opponent_count() == 23)
	assert(not draft.can_add())
	print("PASS omnium selection: one player plus at most 23 opponents")
	quit()
