extends RefCounted
## Only approved, playable venues belong here. Gent remains a design proposal:
## race rules, scenery and replays must be migrated before it can be selectable.
const DEFAULT_ID := "velodrome"
const DEFAULT := preload("res://venues/velodrome.tres")

static func available_ids() -> PackedStringArray:
	return PackedStringArray([DEFAULT_ID])

static func default_venue():
	# Resources are cached by Godot. Each game owns its data and nested arrays.
	return DEFAULT.duplicate(true)

static func find(venue_id: String):
	return default_venue() if venue_id == DEFAULT_ID else null
