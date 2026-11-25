extends SceneTree
const Catalog := preload("res://venues/venue_catalog.gd")
const Geometry := preload("res://track_geometry.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var venue = Catalog.default_venue()
	check(venue.id == "velodrome" and venue.display_name == "Vélodrome", "Named default venue")
	check(venue.validation_errors().is_empty(), "Default venue validates")
	check(Catalog.available_ids() == PackedStringArray(["velodrome"]), "Only approved playable venue is exposed")
	check(Catalog.find("gent") == null and Catalog.find("missing") == null, "Unbuilt venues cannot silently load Vélodrome scenery")
	venue.stand_tiers[0]["rows"] = 99
	venue.palette["navy"] = "ffffff"
	check(Catalog.default_venue().stand_tiers[0]["rows"] == 7 and Catalog.default_venue().palette["navy"] == "142a43", "Games do not share nested mutable venue data")
	venue = Catalog.default_venue()
	check(venue.shared_actors.size() == 3 and venue.scenery.has("rider_boxes"), "Shared actors and local scenery are explicit")
	for path in [venue.arena_path, venue.infield_path, venue.spectator_details_path]:
		check(ResourceLoader.exists(path), "Configured builder exists: " + path)
	for path in venue.shared_actors.values():
		check(ResourceLoader.exists(path), "Configured shared actor exists: " + str(path))
	var game = preload("res://main.gd").new()
	check(game.venue.display_name == "Vélodrome", "Game consumes default configuration before scene construction")
	check(game.LAP == 250.0 and game.RADIUS == 18.0 and game.BANK_TRANSITION_M == 36.0, "Existing track dimensions retained")
	check(game.TRACK_EDGE == 0.78 and game.TRACK_OUTER_EDGE == 9.03 and game.CORNER_BANK_DEG == 42.0, "Existing surface and banking retained")
	check(game.FINISH_REFERENCE_S == 20.0, "Existing finish reference retained")
	check(game.track_geometry.LAP == game.LAP, "Race and geometry use same venue")
	check_geometry(venue)
	# A synthetic short profile tests the geometry machinery, not an approved
	# reconstruction of Gent. Radius/width/transition need a separate art review.
	var short = Catalog.default_venue()
	short.lap_length_m = 166.66
	short.bend_radius_m = 12.0
	short.transition_m = 24.0
	short.corner_bank_deg = 52.0
	check(short.validation_errors().is_empty(), "Synthetic short geometry is valid")
	check_geometry(short)
	short.transition_m = 100.0
	check(not short.validation_errors().is_empty(), "Overlapping transitions rejected")
	short = Catalog.default_venue()
	short.lap_length_m = NAN
	check(not short.validation_errors().is_empty(), "Non-finite dimensions rejected")
	short = Catalog.default_venue()
	short.corner_bank_deg = 90.0
	check(not short.validation_errors().is_empty(), "Vertical banking rejected")
	game.free()
	print("VENUE_CONFIGURATION_OK" if failures == 0 else "VENUE_CONFIGURATION_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)

func check_geometry(venue) -> void:
	var geometry = Geometry.new(venue)
	check(absf(geometry.HALF_SAMPLES * geometry.sample_step - venue.lap_length_m * 0.5) < 0.0000001, "Lookup table reaches exact half lap")
	for i in range(2000):
		var s: float = venue.lap_length_m * float(i) / 2000.0
		check(geometry.position(s).distance_to(geometry.position(s + venue.lap_length_m)) < 0.0001, "Periodic position on configured lap")
		check(geometry.position(s).distance_to(-geometry.position(s + venue.lap_length_m * 0.5)) < 0.0001, "Opposite straight remains half a lap away")
		var tangent: Vector2 = (geometry.position(s + 0.01) - geometry.position(s - 0.01)) / 0.02
		check(absf(tangent.length() - 1.0) < 0.001, "Reference distance remains measured in metres")
	for seam in [0.0, venue.lap_length_m * 0.5, venue.lap_length_m]:
		var left: Vector2 = (geometry.position(seam) - geometry.position(seam - 0.01)) / 0.01
		var right: Vector2 = (geometry.position(seam + 0.01) - geometry.position(seam)) / 0.01
		check(left.distance_to(right) < 0.003, "Continuous tangent at lookup-table seam")
