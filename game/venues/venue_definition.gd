extends Resource
## Venue data in metres/degrees. Scenery belongs to a location; shared actors
## are explicitly listed rather than inherited from the default stadium.
@export var id := ""
@export var display_name := ""
@export var lap_length_m := 250.0
@export var bend_radius_m := 18.0
@export var transition_m := 36.0
@export var apron_width_m := 0.78
@export var track_outer_offset_m := 9.03
@export var apron_bank_deg := 12.0
@export var straight_bank_deg := 12.0
@export var corner_bank_deg := 42.0
@export var finish_straight_clearance_m := 2.0
@export_file("*.gd") var arena_path := ""
@export_file("*.gd") var infield_path := ""
@export_file("*.gd") var spectator_details_path := ""
@export var stand_rim_offset_m := 9.1
@export var stand_tiers: Array[Dictionary] = []
@export var seat_spacing_m := 0.94
@export var palette: Dictionary = {}
@export var race_ambient_energy := 0.25
@export var training_ambient_energy := 0.7
@export var track_light_energy := 2.7
@export var track_light_range_m := 62.326
@export var track_light_attenuation := 0.7
@export var track_light_specular := 0.15
# Descriptive ownership manifest. Builders remain location-specific; this is
# deliberately not a generic auto-instantiator of every asset in this list.
@export var scenery: PackedStringArray = []
@export var shared_actors: Dictionary = {}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or display_name.is_empty(): errors.append("Venue id and display name are required")
	for value in [lap_length_m, bend_radius_m, transition_m, apron_width_m, track_outer_offset_m, apron_bank_deg, straight_bank_deg, corner_bank_deg, finish_straight_clearance_m, stand_rim_offset_m, seat_spacing_m, race_ambient_energy, training_ambient_energy, track_light_energy, track_light_range_m, track_light_attenuation, track_light_specular]:
		if not is_finite(float(value)):
			errors.append("Venue measurements must be finite")
			return errors
	var straight := (lap_length_m - TAU * bend_radius_m) * 0.5
	if lap_length_m <= 0.0 or bend_radius_m <= 0.0 or transition_m <= 0.0 or transition_m > minf(straight, PI * bend_radius_m):
		errors.append("Oval needs positive, non-overlapping straight and bend transitions")
	if apron_width_m < 0.0 or track_outer_offset_m <= apron_width_m:
		errors.append("Track surface width must be positive")
	for angle in [apron_bank_deg, straight_bank_deg, corner_bank_deg]:
		if angle < 0.0 or angle >= 85.0: errors.append("Bank angles must be in [0, 85) degrees")
	if finish_straight_clearance_m < 0.0 or finish_straight_clearance_m > straight - transition_m:
		errors.append("Finish reference must lie on the straight")
	if arena_path.is_empty() or infield_path.is_empty(): errors.append("Venue needs explicit arena and infield builders")
	return errors
