extends Node3D
const MenuSkin := preload("res://menu_theme.gd")
signal infield_riders_changed
# Velodrome 250: banked track simulation and local bridge SIM control.
const TrainerControl := preload("res://trainer_control.gd")
var trainer_control = TrainerControl.new()
var training_environment
var trainer_road_grade := 0.0
var trainer_telemetry_resume := false
var trainer_control_was_active := false
const LAP := 250.0
const ScratchRules := preload("res://scratch_lap_rules.gd")
var scratch_rules = ScratchRules.new()
const XScratchAI := preload("res://x_scratch_ai.gd")
var x_ai = XScratchAI.new()
const PointsAI := preload("res://points_ai.gd")
const EliminationRules := preload("res://elimination_race_rules.gd")
const EliminationAI := preload("res://elimination_ai.gd")
var elimination_rules = EliminationRules.new()
var elimination_notice: Label
var elimination_notice_until := -1.0
var elimination_exit: Dictionary = {}
const REAR_TRAILING_EDGE_M := 1.674 # Front-tip race reference +1.110; rear hub (0.79-0.98), tyre radius 0.374 => rear edge -0.564. Check against imported bike.
const PointsRules := preload("res://points_race_rules.gd")
var points_rules = PointsRules.new()
const PelotonState := preload("res://peloton_state.gd")
var peloton_state = PelotonState.new()
var peloton_info: Dictionary = {}
var peloton_markers: Node3D
var rider_energy_badges: Array[Node3D] = []
var points_notifications = preload("res://points_notifications.gd").new()
var race_event_message := ""
var race_event_until := -1.0
var race_event_sound: AudioStreamPlayer

const PursuitPacer := preload("res://pursuit_pacer.gd")
const PursuitRecords := preload("res://pursuit_records.gd")
var pursuit_library = PursuitRecords.new()
var pursuit_start = preload("res://pursuit_start.gd").new()
const TimeTrialRecords := preload("res://time_trial_records.gd")
var time_trial_records = TimeTrialRecords.new()
var time_trial_reference: Dictionary = {}
var time_trial_reference_kind := "last"
var time_trial_start_type := "standing"
const TeamRace := preload("res://team_race.gd")
var team_race = TeamRace.new()
var team_size := 3
# Menu preference only; trainer commands are added in a later bridge integration.
var team_resistance_mode := "MANUAL"
var team_library = PursuitRecords.new()
var pursuit_pacer = PursuitPacer.new()
var pursuit_replay: Dictionary = {}
# Elapsed crossing times for each 125 m pursuit segment, per rider.
var pursuit_half_crossings: Array = [[], []]
var pursuit_half_stats: Array = [[], []]
var pursuit_energy: Array[float] = [0.0, 0.0]
var pursuit_crossing_energy: Array[float] = [0.0, 0.0]
var pursuit_trace: Array[Dictionary] = []
var pursuit_saved_id := ""
const PerformanceRecords := preload("res://performance_records.gd")
var performance_records = PerformanceRecords.new()
var performance_context: Dictionary = {}
var performance_id := ""
var performance_recorded := false
var pursuit_save_box: VBoxContainer
var pursuit_save_name: LineEdit
var pursuit_save_button: Button
var pursuit_save_status: Label
var finish_subtitle: Label
# Track art: original, algorithmically generated warm pine and blue apron.
# UV values run along the banked 250 m oval; no change to _at() or race physics.
const WOOD_TEXTURE: Texture2D = preload("res://assets/textures/velodrome_wood_pine.png")
const BLUE_APRON_TEXTURE: Texture2D = preload("res://assets/textures/velodrome_cote_azur.png")
const TRACK_EDGE := 0.78
const TRACK_OUTER_EDGE := 9.03
# The race distance measures the FRONT EDGE of the front wheel, not the rider pivot.
# GLB front hub at +0.79 m, external tire radius 0.374 m. The extra 2 cm
# holds the tyre just behind the line at the stationary start.
const FRONT_WHEEL_TIP_M := 1.110
const RADIUS := 18.0
const STRAIGHT := (LAP - 2.0 * PI * RADIUS) / 2.0
const PURSUIT_START_M := LAP - STRAIGHT * 0.5
const NEUTRAL_DEPARTURE_M := -STRAIGHT * 0.5
const UDP_PORT := 51723
# Player selection is finer than AI corridors; physical track geometry is unchanged.
const PLAYER_LANE_STEP_M := 0.60
const LANES := [1.18, 1.78, 2.38, 2.98, 3.58, 4.18, 4.78, 5.38, 5.98, 6.58, 7.18]
# Keep the original starting grid: 0.60 m is too narrow for bicycles abreast.
const START_LANES := [1.18, 2.38, 3.58, 4.78, 5.98, 7.18]
const TEAM_EXCHANGE_LANE_M := 3.58
const FINISH_CAMERA_LANE_M := 2.38
const GRAVITY := 9.81
# Slipstream is based on physical spacing, not on racer rank.
const DRAFT_MIN_GAP_M := 1.2
const DRAFT_MAX_GAP_M := 12.0
const DRAFT_FULL_GAP_M := 3.0
const DRAFT_MAX_LATERAL_M := 2.4
const DRAFT_MAX_DRAG_REDUCTION := 0.48 # Legacy modes only.
const SCRATCH_DRAFT_MAX_DRAG_REDUCTION := 0.69
# Below 20 km/h: 65% of spatial draft; fully active at 50 km/h.
# The aerodynamic watt saving still scales with speed cubed.
const SCRATCH_DRAFT_RAMP_START_MPS := 20.0 / 3.6
const SCRATCH_DRAFT_RAMP_END_MPS := 50.0 / 3.6
const SCRATCH_DRAFT_LOW_SPEED_SCALE := 0.65
const DRAFT_RESPONSE_SECONDS := 0.55
const DRAFT_MIN_SPEED_MPS := 4.5
var draft_strengths: Array[float] = [0.0, 0.0, 0.0, 0.0]
var draft_leaders: Array[int] = [-1, -1, -1, -1]
# The cote d'azur has a fixed cross-slope; only the wooden track banks up in bends.
const BLUE_APRON_BANK_DEG := 12.0
const STRAIGHT_BANK_DEG := 12.0
const CORNER_BANK_DEG := 42.0
const BANK_TRANSITION_M := 12.0
const LANE_CHANGE_MPS := 1.15
var lane_offsets: Array[float] = [1.18, 2.38, 3.58, 4.78]
var ai_lane_targets: Array[float] = [1.18, 2.38, 3.58, 4.78]
const NAMES := ["JIJ", "TIJDRIJDER", "SPRINTER", "AANVALLER"]
const MODE_NAMES := ["SCRATCH", "PUNTENKOERS", "AFVALLING", "KEIRIN", "ACHTERVOLGING", "ARCADE", "PLOEGKOERS"]
const PROFILE_NAMES := ["TIJDRIJDER", "SPRINTER", "AANVALLER"]
var rider_count := 8
var rider_profiles: Array[int] = [0, 1, 2, 3]
var rider_names: Array[String] = ["JIJ", "TIJDRIJDER", "SPRINTER", "AANVALLER"]
var rider_forms: Array[float] = [1.0, 1.0, 1.0, 1.0]
var rider_kits: Array[Dictionary] = []
var race_mode := 0
var rider_count_input: SpinBox
var form_rng := RandomNumberGenerator.new()
var rider_config := ConfigFile.new()
var rider_config_ready := false
const Catalog := preload("res://rider_catalog.gd")
const ConfigPaths := preload("res://config_paths.gd")
var rider_identities: Array[Dictionary] = []
var selected_startlist: Array[Dictionary] = []
var startlist_mode := -1
var results_podium = preload("res://results_podium.gd").new()
var ai_personal_records = preload("res://rider_records.gd").new()
var ai_recorded: Array[bool] = []
var ai_observed_peak: Array[float] = []
var pursuit_opponent_config: Dictionary = {}
var pursuit_opponent_country := "netherlands"
var pursuit_opponent_percent := 80.0
const RaceCountries := preload("res://rennersboxen/race_countries.gd")

func _load_rider_config() -> void:
	# Personal config is intentionally excluded from distributed ZIP updates.
	# Prefer per-project file so players can edit names in a text editor.
	var err: Error = ConfigPaths.load_project(rider_config, "riders_config.cfg", true)
	rider_config_ready = err == OK
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Velodrome: riders_config.cfg kon niet worden ingelezen (%d); standaardnamen worden gebruikt." % err)

func _configured_rider(i: int, default_profile: int) -> Dictionary:
	return Catalog.entry(rider_config, i, default_profile)

func _profile(i: int) -> int:
	return rider_profiles[i] if i < rider_profiles.size() else 1

func _form(i: int) -> float:
	return rider_forms[i] if i < rider_forms.size() else 1.0

func _configure_peloton() -> void:
	neutral_start.reset()
	flying_start.reset()
	if race_mode == 5:
		rider_count = team_size * 2
	elif race_mode == 4:
		rider_count = 2
	elif race_mode == 7:
		rider_count = 1
	# Deterministic inside each event; new race = new day form.
	form_rng.randomize()
	_load_rider_config()
	rider_profiles.clear()
	rider_names.clear()
	rider_forms.clear()
	rider_identities.clear()
	ai_recorded.resize(rider_count); ai_recorded.fill(false)
	ai_observed_peak.resize(rider_count); ai_observed_peak.fill(0.0)
	rider_kits.clear()
	for i in range(rider_count):
		var kind: int = 0 if i == 0 else 1 + ((i - 1) % 3)
		# 1 = TT, 2 = sprinter, 3 = attacker.
		var configured: Dictionary = _configured_rider(i, kind) if i > 0 else {"profile": 0, "name": player_display_name}
		if race_mode in [0,1,2] and race_mode == startlist_mode and i > 0 and selected_startlist.size() == rider_count - 1:
			configured = selected_startlist[i - 1].duplicate(true)
		if race_mode == 4 and i > 0:
			configured = pursuit_opponent_config.duplicate(true) if not pursuit_opponent_config.is_empty() else _configured_rider(1, 1)
		if race_mode == 5:
			var ours := i < team_size
			var outfit: Dictionary = player_appearance.resolve(get_player_appearance_base()) if ours else {"country_kit": pursuit_opponent_country}
			outfit["country"] = RaceCountries.from_kit(outfit) if ours else pursuit_opponent_country
			if String(outfit.country).is_empty(): outfit["country"] = "belgium"
			configured = {"profile": 0 if ours else 1, "name": player_display_name if i == 0 else ("Ploegmaat %d" % i if ours else "%s %d" % [pursuit_opponent_country, i - team_size + 1]), "jersey": outfit}
		if _restarting_event:
			configured = replay_setup.riders[i].duplicate(true)
		rider_identities.append(configured.duplicate(true))
		rider_profiles.append(int(configured["profile"]))
		rider_names.append(String(configured["name"]))
		rider_forms.append(float(replay_setup.forms[i]) if _restarting_event else (1.0 if i == 0 or race_mode in [4, 5, 7] else form_rng.randf_range(0.975, 1.025)))
		var kit: Dictionary = configured.get("jersey", {})
		kit = kit.duplicate()
		kit["number"] = clampi(int(kit.get("number", i + 1)), 1, 99)
		rider_kits.append(kit)
	var count: int = rider_count
	distances.resize(count); distances.fill(0.0)
	speeds.resize(count); speeds.fill(0.0)
	finish_times.resize(count); finish_times.fill(-1.0)
	scratch_rules.reset(count)
	if race_mode == 1: points_rules.reset(count, race_laps)
	elimination_exit.clear()
	peloton_state.reset(); peloton_info.clear()
	race_event_message = ""; race_event_until = -1.0
	for badge in rider_energy_badges: badge.queue_free()
	rider_energy_badges.clear()
	last_lap_crossing.resize(count); last_lap_crossing.fill(0.0)
	pursuit_half_crossings = [[], []]
	pursuit_half_stats = [[], []]
	pursuit_energy.assign([0.0, 0.0])
	pursuit_crossing_energy.assign([0.0, 0.0])
	lap_times.clear()
	for i in range(count): lap_times.append([])
	draft_strengths.resize(count); draft_strengths.fill(0.0)
	draft_leaders.resize(count); draft_leaders.fill(-1)
	visual_rolls.resize(count); visual_rolls.fill(0.0)
	coast_distances.resize(count); coast_distances.fill(0.0)
	coast_speeds.resize(count); coast_speeds.fill(0.0)
	ai_energy_j.resize(count)
	ai_power_w.resize(count); ai_power_w.fill(0.0)
	ai_stall_time.resize(count); ai_stall_time.fill(0.0)
	ai_role.resize(count); ai_role.fill(0)
	ai_role_until.resize(count); ai_role_until.fill(0.0)
	ai_attack_lap.resize(count); ai_attack_lap.fill(-1)
	ai_lead_seconds.resize(count); ai_lead_seconds.fill(0.0)
	ai_attack_count.resize(count); ai_attack_count.fill(0)
	ai_peloton_changes = 0
	ai_last_leader = -1
	lane_offsets.resize(count)
	ai_lane_targets.resize(count)
	for i in range(count):
		var lane: float = LANES[0] if race_mode in [4, 5, 7] else START_LANES[i % START_LANES.size()]
		# A narrow grid on the lower straight gives every rider room to roll away.
		# Wider rows stretch apart because outside riders cover longer bends.
		if race_mode in [0, 1, 2]:
			lane = LANES[0] + 1.2 * float(i % 2)
			distances[i] = NEUTRAL_DEPARTURE_M - 2.4 * float(i / 2)
		lane_offsets[i] = lane
		ai_lane_targets[i] = lane
		var type_id := _profile(i)
		ai_energy_j[i] = 0.0 if i == 0 else AI_CAPACITY_J[type_id] * _form(i)
	if race_mode in [0, 1, 2]:
		neutral_start.distance_offset = -NEUTRAL_DEPARTURE_M
	# The scratch AI owns CP, Wprime and fatigue; no older beta.16 energy state.
	if race_mode in [0, 1, 2]:
		x_ai = PointsAI.new() if race_mode == 1 else (EliminationAI.new() if race_mode == 2 else XScratchAI.new())
		if race_mode == 1: x_ai.jury = points_rules
		x_ai.reset(rider_profiles, rider_forms, lane_offsets)
		x_ai.configure_riders(rider_identities, rider_forms)
	if race_mode == 2:
		var rear_positions: Array[float] = []
		for distance in distances: rear_positions.append(distance - REAR_TRAILING_EDGE_M)
		elimination_rules.reset(count, rear_positions)
	pursuit_start.clear()
	for node in bikes: node.queue_free()
	bikes.clear()
	crowded_labels.clear()
	_spawn_peloton()
	if race_mode in [0, 1, 2]:
		for i in range(bikes.size()):
			var badge = preload("res://rider_energy_badge.gd").new()
			add_child(badge)
			rider_energy_badges.append(badge)
	if peloton_markers == null:
		peloton_markers = preload("res://peloton_markers.gd").new()
		add_child(peloton_markers)
	infield_riders_changed.emit()

func _spawn_peloton() -> void:
	for i in range(rider_count):
		var node := Node3D.new()
		var rider := preload("res://rider_visual.gd").new()
		rider.set_meta("rider_index", _profile(i))
		rider.set_meta("peloton_index", i)
		rider.set_meta("pursuit_mode", race_mode in [4, 5, 7])
		rider.set_meta("jersey_config", rider_kits[i])
		rider.set_meta("body_shapes", rider_identities[i].get("morphs", {}))
		if rider_config_ready and race_mode not in [4, 5]:
			var source_slot := int(rider_identities[i].get("slot",i)) if i > 0 else 0
			var kit_section := "player" if i == 0 else "rider_%02d" % source_slot
			rider.set_meta("country_kit", String(rider_config.get_value(kit_section, "country_kit", rider_kits[i].get("country_kit",""))))
			rider.set_meta("skinsuit_png", String(rider_config.get_value(kit_section, "skinsuit_png", rider_kits[i].get("skinsuit_png",""))))
			rider.set_meta("helmet_png", String(rider_config.get_value(kit_section, "helmet_png", rider_kits[i].get("helmet_png",""))))
			rider.set_meta("visor", String(rider_config.get_value(kit_section, "visor", rider_kits[i].get("visor",""))))
		if race_mode == 5:
			PlayerAppearance.prepare_rider(rider, rider_kits[i])
		if i == 0:
			PlayerAppearance.prepare_rider(rider, player_appearance.resolve(get_player_appearance_base()))
		node.add_child(rider)
		if race_mode != 5:
			var tag := Label3D.new()
			tag.text = _rider_name(i)
			tag.position = Vector3(0.0, 2.26, 0.0)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.font_size = 56
			tag.pixel_size = 0.005
			tag.outline_size = 15
			tag.no_depth_test = true
			tag.layers = 2          # render layer 2: hidden from the finish-photo camera
			node.add_child(tag)
		add_child(node)
		bikes.append(node)

func get_player_appearance_base() -> Dictionary:
	var config: Dictionary = {}
	for key in PlayerAppearance.KEYS:
		config[key] = String(rider_config.get_value("player", key, "")) if rider_config_ready else ""
	return config

func apply_player_appearance() -> void:
	# Update the existing player visual in place: preserve pose, cadence and race.
	if bikes.is_empty() or not is_instance_valid(bikes[0]) or bikes[0].get_child_count() == 0:
		return
	var outfit: Dictionary = player_appearance.resolve(get_player_appearance_base())
	for i in range(team_size if race_mode == 5 else 1):
		if i >= bikes.size(): break
		PlayerAppearance.apply_to_rider(bikes[i].get_child(0), outfit)
		if race_mode == 5:
			rider_kits[i]["country"] = RaceCountries.from_kit(outfit)
			for key in PlayerAppearance.KEYS: rider_kits[i][key] = outfit.get(key, "")
	pursuit_start.refresh_kits(self)
	infield_riders_changed.emit()

# AI riders: reactive drafting, overtaking and limited high-intensity energy.
# Energies are joules ABOVE sustainable output and refill at low intensity.
const AI_SUSTAIN_W := [0.0, 500.0, 365.0, 100.0]
const AI_PEAK_W := [0.0, 620.0, 960.0, 700.0]
const AI_CAPACITY_J := [0.0, 11500.0, 18000.0, 30000.0]
var ai_energy_j: Array[float] = [0.0, 11500.0, 18000.0, 30000.0]
var ai_power_w: Array[float] = [0.0, 0.0, 0.0, 0.0]
# Time-trialist: maximum sustainable CONSTANT output for the chosen event duration.
# Approximate anchors inspired by the supplied upper power-duration curve, with
# the user's preferred illustrative values (30 s = 600 W, 5 min = 350 W).
# Time is estimated before the race, not changed as the cyclist speeds up.
const TT_CURVE_SECONDS := [1.0, 15.0, 30.0, 60.0, 180.0, 300.0, 600.0, 1200.0]
const TT_CURVE_WATTS := [1100.0, 890.0, 600.0, 435.0, 390.0, 350.0, 310.0, 285.0]
var tt_constant_power_w := 0.0
var tt_effort_remaining := 1.0

func _tt_power_for_duration(seconds: float) -> float:
	# Interpolation in logarithmic time follows the shape of a power-duration graph.
	var t: float = clampf(seconds, TT_CURVE_SECONDS[0], TT_CURVE_SECONDS[-1])
	for j in range(1, TT_CURVE_SECONDS.size()):
		if t <= TT_CURVE_SECONDS[j]:
			var fraction: float = (log(t) - log(TT_CURVE_SECONDS[j - 1])) / (log(TT_CURVE_SECONDS[j]) - log(TT_CURVE_SECONDS[j - 1]))
			return lerpf(TT_CURVE_WATTS[j - 1], TT_CURVE_WATTS[j], fraction)
	return TT_CURVE_WATTS[-1]

func _tt_prepare_event() -> void:
	# 250 m in ~30 s; 2.5 km in ~5 min; 5 km in ~10 min.
	# The target is fixed for the WHOLE race: no starting burst, no late sprint.
	var estimated_seconds: float = maxf(1.0, _race_length() / (250.0 / 30.0))
	tt_constant_power_w = _tt_power_for_duration(estimated_seconds) * (ai_difficulty / 100.0)
	tt_effort_remaining = 1.0

var ai_think_timer := 0.0
var ai_stall_time: Array[float] = [0.0, 0.0, 0.0, 0.0]
# 16.16b: peloton tactical state, independent per opponent.
var ai_role: Array[int] = [] # 0=shelter, 1=lead/chase, 2=attack, 3=recover
var ai_role_until: Array[float] = []
var ai_attack_lap: Array[int] = []
var ai_lead_seconds: Array[float] = []
var ai_attack_count: Array[int] = []
var ai_peloton_changes := 0
var ai_last_leader := -1
const AI_CHASE_GAP_M := 11.0
const AI_LEAD_TURN_S := 22.0
const AI_ATTACK_DURATION_S := 14.0

# 80% matches the original beta.10 AI power; adjust all riders proportionally.
var ai_difficulty := 80.0
var laps_input: SpinBox
var race_laps := 1
var difficulty_slider: HSlider
var difficulty_label: Label
var setup_panel: Control
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_graph: Control
var results_shown := false
# Post-finish presentation: timed coast, fixed finish-line camera, then results.
const FINISH_PRESENTATION_SECONDS := 10.0
const COAST_BRAKE_MPS2 := 0.85
var finish_elapsed := 0.0
var coast_distances: Array[float] = [0.0, 0.0, 0.0, 0.0]
var coast_speeds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var finish_overlay: ColorRect
# beta.16.17: finish photo taken from the photographers' spot (infield, a few metres past the line)
# at the moment the winner crosses the line, shown next to the official results.
const FINISH_PHOTO_AFTER_LINE_M := 3.4
const FINISH_PHOTO_INFIELD_OFFSET := -0.72     # lens just behind the glass, photographer behind the camera
var finish_photo_viewport: SubViewport
var finish_photo_camera: Camera3D
var finish_photo_rect: TextureRect
var finish_photo_caption: Label
var team_finish_photo = preload("res://team_finish_photo.gd").new()
var finish_photo_taken := false
# Tracks the photographed provisional winner, independently of the last finisher.
var finish_photo_rider := -1
var finish_photo_capture_pending := false
var finish_results: Label
var finish_table: GridContainer
var finish_heading: Label
var strava_client: Node
var strava_activity_url := ""
var strava_desired_title := "Velodrome"
var strava_desired_description := ""
var strava_save_screenshot := false
var strava_screenshot_path := ""
var finish_badge: Label
const PlayerAppearance = preload("res://player_appearance.gd")
var player_appearance = PlayerAppearance.new()
var player_display_name := "JIJ"
var player_weight_kg := 75.0
var race_hud_items: Array[CanvasItem] = []
var player_power_integral := 0.0
var player_peak_watts := 0.0
var player_speed_peak_kmh := 0.0
var player_samples: Array[Vector2] = []
const AI_THINK_INTERVAL := 0.35
var bikes: Array[Node3D] = []
var boost_dog: Node3D
# Attacker: immediate 700 W until 50 m, then taper to 100 W at the finish.
const ATTACK_FULL_POWER_M := 50.0
const ATTACK_FINISH_POWER_W := 100.0
# Rider tires much earlier: between 50 and 95 m he drops to 100 W.
const ATTACK_FADE_END_M := 95.0
var distances: Array[float] = [0.0, 0.0, 0.0, 0.0]
var speeds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var player_lane := 0
var steering_direction := 0
var steering_steps := 0
var watts := 0.0
# Demo start preset: selected before the countdown, applied ONLY when START fires.
var demo_launch_watts := 300.0
# Virtual power is constrained only for keyboard control, never for Zwift Ride.
const PC_MAX_REQUEST_W := 1300.0
var pc_energy_model = XScratchAI.new()
var pc_delivered_watts := 0.0
var pc_power_limit_watts := -1.0

func _pc_energy_fraction() -> Variant:
	if not pc_energy_model.initialized or pc_energy_model.wmax[1] <= 0.0:
		return null
	return clampf(pc_energy_model.wprime[1] / pc_energy_model.wmax[1], 0.0, 1.0)

func _pc_power(dt: float) -> float:
	if trainer_seen:
		return watts
	if not pc_energy_model.initialized:
		return watts
	pc_power_limit_watts = pc_energy_model.power_limit(1, dt)
	pc_delivered_watts = pc_energy_model._phys_power(1, watts, dt)
	return pc_delivered_watts

func _reset_pc_energy() -> void:
	# Reuse exactly the AI's fatigue, W-prime depletion and recovery.
	var profiles: Array[int] = [0, 3]
	var forms: Array[float] = [1.0, 1.0]
	var lanes: Array[float] = [1.18, 1.18]
	pc_energy_model.reset(profiles, forms, lanes)
	pc_energy_model.cp[1] = 255.0
	pc_energy_model.wmax[1] = 30000.0
	pc_energy_model.wprime[1] = pc_energy_model.wmax[1]
	pc_energy_model.pmax[1] = PC_MAX_REQUEST_W
	pc_delivered_watts = 0.0
	pc_power_limit_watts = -1.0
var trainer_speed_kmh := -1.0
var trainer_ready := false
var trainer_seen := false
var zero_stable := 0.0
const ZERO_CONFIRM_SECONDS := 1.0
const ZERO_WATTS_THRESHOLD := 50.0
const START_FINAL_SECOND_SPEED_KMH := 10.0
# Demo-only burst: never alters real KICKR data or sends trainer commands.
const BOOST_DURATION := 3.0
const BOOST_POWER_W := 1500.0
const BOOST_RECOVERY_SECONDS := 1.5
var boost_left := 0.0
var recovery_left := 0.0
var recovery_excess := 0.0
var baseline_speed := 0.0
var boosted_speed := 0.0
var boost_used := false
var cadence := -1.0
var connected := false
var last_telemetry := -100.0
# beta.16.14: a short KICKR/Bluetooth dropout no longer freezes the race. For up to
# DROPOUT_HOLD_SECONDS after the last valid sample the game keeps riding on the last
# known power and cadence; only a longer outage pauses the race (as before).
const DROPOUT_HOLD_SECONDS := 10.0
var last_good_watts := 0.0
var last_good_cadence := -1.0
var dropout_since := -1.0
# beta.16.14: big floating 3D countdown at the start line.
var countdown_label: Label3D
var countdown_shown := ""
var clock := 0.0
var neutral_start = preload("res://neutral_start.gd").new()
var flying_start = preload("res://flying_start.gd").new()
var countdown := 3.0
var start_state := "WAIT_STOP"
var broadcast_intro: RefCounted
var rider_name_mode := 0 # V: 0 Auto, 1 all, 2 off; persists across race resets.
var crowded_labels: Dictionary = {}
var name_view_notice_until := 0.0
var race_paused := false
var trainer_pause_resume := false
var exit_menu
var replay_setup: Dictionary = {}
var _restarting_event := false
var running := false
var finished := false
var finish_times: Array[float] = [-1.0, -1.0, -1.0, -1.0]
# Per-rider completed lap times (seconds), and crossing timestamps.
var lap_times: Array = [[], [], [], []]
var last_lap_crossing: Array[float] = [0.0, 0.0, 0.0, 0.0]
var lap_notice_until: float = 0.0
var lap_notice: String = ""
var udp := PacketPeerUDP.new()
var bridge_bind_error: Error = OK
var race_overlay
var trainer_gear := "—"
# Bridge v0.13.1 optional fields: null means unavailable, independent of KICKR valid.
var trainer_selected_gear: Variant = null
var trainer_heart_rate_bpm: Variant = null
var last_bridge_telemetry := -1.0
const BRIDGE_OPTIONAL_TIMEOUT_SECONDS := 1.0
var hud: Label
var note: Label
var rankings: Label
var minimap: Control
var camera: Camera3D
var camera_mode := 1 # 0 Close, 1 Wide, 2 POV, 3 Side
var look_back_held := false # Hold B to look behind; release to restore selected camera.
var keyboard_look_back := false
var ride_look_back := false
var ride_look_source := "B"
var ride_buttons: Dictionary = {}
var ride_mapping := preload("res://ride_mapping.gd").new()
var last_controller_signal := -1.0
var ride_navigation: CanvasLayer
# Visual-only lean; race physics remains untouched.
var visual_rolls: Array[float] = [0.0, 0.0, 0.0, 0.0]
var camera_roll := 0.0
const LEAN_MIN_SPEED_KMH := 12.0
const LEAN_FULL_SPEED_KMH := 47.0
const CAMERA_NAMES := ["CLOSE", "WIDE", "POV", "SIDE"]
var arena: Node3D
var last_right := false
var last_left := false
# Real KICKR FTMS notifications only (never demo/arcade data).
var ride_records: Array[Dictionary] = []
# Temporary simulation-only samples, never written into the real KICKR CSV.
var demo_fit_records: Array[Dictionary] = []
const DEMO_FIT_SAMPLE_INTERVAL := 0.2
var recording_active := false
var recording_saved := false
var last_sample_id := -1
var last_record_tick := -1000
const FALLBACK_SAMPLE_INTERVAL_MS := 200
var recording_message := ""
var recording_folder := ""
var ride_start_unix: int = 0
var strava_export_path := ""
var fit_export_path := ""
var fit_gps_export_path := ""


func _ready() -> void:
	var legacy_mapping := OS.get_executable_path().get_base_dir().path_join("bridge/button_mapping.json")
	if not FileAccess.file_exists(legacy_mapping):
		legacy_mapping = ProjectSettings.globalize_path("res://").path_join("../bridge/button_mapping.json")
	ride_mapping.load_settings(ride_mapping.PATH, legacy_mapping)
	player_appearance.load_preferences()
	Engine.max_fps = 90
	if _bind_bridge() != OK:
		push_warning("UDP poort 51723 niet beschikbaar. Sluit andere spelinstanties en herstart Godot.")
	strava_client = preload("res://strava_client.gd").new()
	add_child(strava_client)
	strava_client.status_changed.connect(_on_strava_status)
	strava_client.activity_created.connect(_on_strava_activity_created)
	_build_world()
	arena = load("res://arena.gd").new()
	add_child(arena)
	_build_hud()
	var preferences := preload("res://display_settings.gd").new()
	preferences.name = "GameSettings"
	ride_navigation = preload("res://ride_navigation.gd").new()
	add_child(ride_navigation)
	add_child(preferences)
	broadcast_intro = preload("res://broadcast_intro.gd").new()
	broadcast_intro.setup(self)
	exit_menu = preload("res://exit_menu.gd").new()
	add_child(exit_menu)
	exit_menu.setup(self)
	_reset()
	setup_panel.show_hub()

func _bind_bridge(port: int = UDP_PORT) -> Error:
	bridge_bind_error = udp.bind(port, "127.0.0.1")
	return bridge_bind_error

func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

func _power_hold_active() -> bool:
	return dropout_since >= 0.0 and _now_s() - dropout_since <= DROPOUT_HOLD_SECONDS

func _begin_dropout(since: float) -> void:
	# Only bridge a dropout while actually racing on a real trainer.
	if dropout_since < 0.0 and trainer_seen and _riding() and not finished:
		dropout_since = since

func _physics_process(delta: float) -> void:
	_read_bridge()
	if training_environment != null and training_environment.active:
		trainer_control.tick(false, 0.0, 1.0, _now_s())
		exit_menu.set_exit_visible(false)
		training_environment.advance(delta)
		return
	if _now_s() - last_telemetry > 1.0:
		trainer_ready = false
		_begin_dropout(last_telemetry)
		if connected:
			connected = false
			if not _power_hold_active():
				trainer_speed_kmh = -1.0
				watts = 0.0
	if dropout_since >= 0.0 and not connected:
		if _power_hold_active():
			watts = last_good_watts
			cadence = last_good_cadence
		else:
			watts = 0.0
			trainer_speed_kmh = -1.0
	if exit_menu != null:
		exit_menu.set_exit_visible(start_state in ["SETUP", "INTRO"] or finished)
	if race_paused:
		trainer_control.tick(false, 0.0, 1.0, _now_s())
		return
	if start_state == "INTRO": broadcast_intro.advance(delta)
	if not finished:
		if start_state == "WAIT_STOP":
			var stopped: bool = _start_conditions_met()
			zero_stable = minf(ZERO_CONFIRM_SECONDS, zero_stable + delta) if stopped else 0.0
			if stopped and (not _start_requires_standstill() or zero_stable >= ZERO_CONFIRM_SECONDS):
				start_state = "COUNTDOWN"
				countdown = 3.0
		elif start_state == "COUNTDOWN":
			if not _start_conditions_met() or (countdown <= 1.0 and not _final_start_speed_ok()):
				start_state = "WAIT_STOP"
				zero_stable = 0.0
			elif countdown > 0.0:
				countdown = maxf(0.0, countdown - delta)
			else:
				_begin_riding()
		elif start_state in ["NEUTRAL", "RUN_UP"]:
			if not trainer_seen or (connected and trainer_ready) or _power_hold_active():
				var previous: Vector3 = _at(_rider_distance(0, distances[0]), lane_offsets[0])
				if start_state == "RUN_UP": flying_start.step(self, delta)
				else: neutral_start.step(self, delta)
				var current: Vector3 = _at(_rider_distance(0, distances[0]), lane_offsets[0])
				var grade: float = TrainerControl.route_grade(previous, current)
				trainer_road_grade = lerpf(trainer_road_grade, grade, 1.0 - exp(-8.0 * delta))
		elif start_state == "RACING":
			# Once a real trainer was used, a lost signal must not become demo mode.
			if not trainer_seen or (connected and trainer_ready) or _power_hold_active():
				clock += delta
				_update_race(delta)
	# After the player finishes, let AI riders complete their own races.
	# The player's distance and time are frozen by finish_times[0].
	if finished and start_state == "RACING" and not _all_riders_finished():
		clock += delta
		_update_race(delta)
	# Run each finished rider's coast immediately after THEIR finish, even while
	# the player is still racing. Their race times/distances remain frozen.
	if start_state == "RACING":
		_update_coasting(delta)
		_record_ai_performances()
	if finished:
		_clear_look_back()
		finish_elapsed += delta
		if (finish_elapsed >= FINISH_PRESENTATION_SECONDS or _all_riders_finished()) and finish_overlay != null:
			finish_overlay.show()
			_set_race_hud_visible(false)
			_refresh_fullscreen_results()
	_update_trainer_control()
	_update_visuals(delta)
	_update_boost_dog(delta)
	_update_countdown_display()
	_update_hud()
	if elimination_notice != null:
		elimination_notice.visible = race_mode == 2 and clock < elimination_notice_until and start_state == "RACING"

func _riding() -> bool:
	return start_state in ["NEUTRAL", "RUN_UP", "RACING"]

func _begin_riding() -> void:
	running = true
	_reset_pc_energy()
	if not trainer_seen:
		watts = demo_launch_watts
	else:
		recording_active = true
		ride_start_unix = int(Time.get_unix_time_from_system())
	if race_mode in [0, 1, 2]:
		neutral_start.begin(self)
	elif race_mode == 7 and time_trial_start_type == "flying":
		flying_start.begin(self)
	else:
		start_state = "RACING"
		pursuit_start.release(self)
	_capture_player_demo_fit_sample(true)

func _finish_neutral_start() -> void:
	# Rebasing by one whole lap preserves every bike's physical position.
	clock = 0.0
	baseline_speed = speeds[0]
	boost_left = 0.0
	boosted_speed = speeds[0]
	recovery_left = 0.0
	last_lap_crossing.fill(0.0)
	for laps in lap_times: laps.clear()
	scratch_rules.reset(rider_count)
	if race_mode == 1: points_rules.reset(rider_count, race_laps)
	if race_mode == 2:
		var rear: Array[float] = []
		for distance in distances: rear.append(distance - REAR_TRAILING_EDGE_M)
		elimination_rules.reset(rider_count, rear)
	points_notifications.reset()
	peloton_state.reset()
	peloton_info.clear()
	x_ai.reset(rider_profiles, rider_forms, lane_offsets)
	x_ai.configure_riders(rider_identities, rider_forms)
	start_state = "RACING"

func _finish_flying_start() -> void:
	clock = 0.0
	baseline_speed = speeds[0]
	last_lap_crossing.fill(0.0)
	for laps in lap_times: laps.clear()
	pursuit_half_crossings = [[], []]
	pursuit_half_stats = [[], []]
	pursuit_energy.assign([0.0, 0.0])
	pursuit_crossing_energy.assign([0.0, 0.0])
	pursuit_trace.clear()
	pursuit_trace.append({"t": 0.0, "d": 0.0, "p": watts, "lane": lane_offsets[0]})
	start_state = "RACING"

func _training_seconds() -> float:
	return neutral_start.elapsed + flying_start.elapsed + clock

func _training_distance() -> float:
	return neutral_start.distance_offset + flying_start.distance_offset + distances[0]

func _update_countdown_display() -> void:
	# A single screen-space cue stays centered in every race camera.
	var value := ""
	if not finished and start_state == "COUNTDOWN":
		value = str(maxi(1, ceili(countdown)))
	elif not finished and start_state == "RACING" and clock < 1.1:
		value = "START!" if race_mode in [0, 1, 2] else "GO!"
	countdown_shown = value
	if countdown_label != null:
		countdown_label.text = value
		countdown_label.hide()
	if race_overlay == null: return
	race_overlay.signals.set_countdown(value)
	race_overlay.signals.update_last_lap(start_state == "RACING", maxf(0.0, _race_length() - distances[0]), _race_length(), finished)

func _start_requires_standstill() -> bool:
	return race_mode not in [0, 1, 2] and not (race_mode == 7 and time_trial_start_type == "flying")

func _start_conditions_met() -> bool:
	if bridge_bind_error != OK:
		return false
	if trainer_seen:
		return connected and trainer_ready and (not _start_requires_standstill() or watts <= ZERO_WATTS_THRESHOLD)
	return not _start_requires_standstill() or watts <= 0.0

func _final_start_speed_ok() -> bool:
	if not _start_requires_standstill(): return true
	# Only check trainer speed during the final second of the countdown.
	if trainer_seen:
		return trainer_speed_kmh >= 0.0 and trainer_speed_kmh <= START_FINAL_SECOND_SPEED_KMH
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_B and not event.pressed:
		keyboard_look_back = false
		_refresh_look_back()
	# Escape must also work when a race HUD button has keyboard focus.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var preferences := get_node_or_null("GameSettings")
		if ride_navigation != null and ride_navigation.keyboard_action("B"):
			pass
		elif preferences != null and preferences.panel_root.visible:
			preferences._close_settings()
		elif exit_menu != null and exit_menu.quitting_application:
			exit_menu.cancel_or_resume()
		elif race_paused:
			exit_menu.cancel_or_resume()
		elif start_state not in ["SETUP", "INTRO"] and not finished:
			_pause_race()
		else:
			return
		get_viewport().set_input_as_handled()

func _pause_race() -> void:
	if race_paused or finished or start_state in ["SETUP", "INTRO"]: return
	race_paused = true
	_clear_look_back()
	trainer_telemetry_resume = false
	trainer_pause_resume = false
	trainer_control.tick(false, 0.0, 1.0, _now_s())
	exit_menu.show_pause()

func _resume_race() -> void:
	if not race_paused: return
	race_paused = false
	# Finish servicing any pending release before re-probing our own session.
	trainer_pause_resume = trainer_control.error.is_empty()
	exit_menu.hide_pause()

func _quit_application() -> void:
	if setup_panel != null and setup_panel.ftp_page != null: setup_panel.ftp_page.shutdown()
	trainer_control.close()
	_save_recording("exit")
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if race_paused: return
	var key_event := event as InputEventKey
	if key_event == null or key_event.echo:
		return
	if key_event.keycode == KEY_B and not key_event.pressed:
		keyboard_look_back = false
		_refresh_look_back()
		return
	var preferences := get_node_or_null("GameSettings")
	if preferences != null and preferences.panel_root.visible: return
	if setup_panel != null and setup_panel.visible:
		# The menu owns navigation; race shortcuts must not reset/quit it.
		return
	if broadcast_intro != null and broadcast_intro.active:
		if key_event.pressed and key_event.keycode in [KEY_ENTER, KEY_SPACE]: broadcast_intro.finish()
		elif key_event.pressed and key_event.keycode == KEY_R: _reset()
		elif key_event.pressed and key_event.keycode == KEY_ESCAPE: _reset()
		return
	# Handle both key-down and key-up, without modifying the selected camera mode.
	if key_event.keycode == KEY_B:
		keyboard_look_back = key_event.pressed and not finished
		_refresh_look_back()
		return
	if not key_event.pressed:
		return
	match key_event.keycode:
		KEY_X:
			if race_overlay != null and race_overlay.is_visible_in_tree():
				race_overlay.toggle_developer()
		KEY_V:
			if not key_event.echo: _cycle_rider_names()
		KEY_R:
			if finished: _restart_same_race()
			else: _reset()
		KEY_C:
			camera_mode = (camera_mode + 1) % 4
			# Never display own model in first-person view.
			bikes[0].visible = look_back_held or camera_mode != 2
		KEY_P:
			_save_recording("manual")
		KEY_A, KEY_LEFT:
			_steer_player(-1)
		KEY_D, KEY_RIGHT:
			_steer_player(1)
		KEY_UP, KEY_EQUAL:
			if not trainer_seen:
				if _riding():
					watts = minf(PC_MAX_REQUEST_W, watts + 25.0)
				else:
					demo_launch_watts = minf(PC_MAX_REQUEST_W, demo_launch_watts + 25.0)
		KEY_DOWN, KEY_MINUS:
			if not trainer_seen:
				if _riding():
					watts = maxf(0.0, watts - 25.0)
				else:
					demo_launch_watts = maxf(0.0, demo_launch_watts - 25.0)
		KEY_SPACE:
			if not trainer_seen and start_state == "RACING" and running and not finished and not boost_used and race_mode not in [1, 4, 5]:
				boost_left = BOOST_DURATION
				boosted_speed = speeds[0]
				baseline_speed = speeds[0]
				recovery_left = 0.0
				boost_used = true
		KEY_ESCAPE:
			if finished: _reset()
			else: _pause_race()

func _cycle_camera(direction: int) -> void:
	camera_mode = posmod(camera_mode + direction, CAMERA_NAMES.size())
	if not bikes.is_empty():
		bikes[0].visible = look_back_held or camera_mode != 2

func _refresh_look_back() -> void:
	look_back_held = keyboard_look_back or ride_look_back
	if not bikes.is_empty(): bikes[0].visible = look_back_held or camera_mode != 2

func _clear_look_back() -> void:
	keyboard_look_back = false
	ride_look_back = false
	_refresh_look_back()

func _ride_context() -> String:
	var preferences := get_node_or_null("GameSettings")
	if preferences != null and preferences.panel_root.visible: return "settings"
	if race_paused or (exit_menu != null and exit_menu.quitting_application): return "pause"
	if setup_panel != null and setup_panel.visible: return "setup"
	if broadcast_intro != null and broadcast_intro.active: return "intro"
	if finished: return "results"
	return "race"

func _ride_action(key: String, source: String = "B") -> void:
	# Physical gears stay owned by the bridge during training, including when
	# a user mapped their shift paddles to menu confirmation/back actions.
	if setup_panel != null and setup_panel.visible and setup_panel.page == 8 and source.begins_with("SHIFT_"):
		return
	var preferences := get_node_or_null("GameSettings")
	# The diagnostic page consumes every gameplay action. Z explicitly exits it.
	if preferences != null and preferences.controller_test_active():
		if key == "Z": preferences.bridge_action(key)
		return
	if ride_navigation != null and ride_navigation.keyboard_action(key): return
	match _ride_context():
		"settings": preferences.bridge_action(key)
		"pause":
			if key in ["B", "Z"]: exit_menu.cancel_or_resume()
			else: ride_navigation.navigate(exit_menu.backdrop, key, exit_menu.resume_button, true)
		"setup":
			if key == "Z": preferences.toggle_menu()
			elif key == "B" and setup_panel.page == 0: exit_menu.show_quit()
			elif setup_panel.selected in [1, 2] and setup_panel.pursuit_flow.visible:
				# The pursuit flow owns its rows; generic range editing must not
				# consume arrows or A before that screen can navigate/confirm.
				setup_panel.bridge_action(key)
			elif not ride_navigation.edit_control(key): setup_panel.bridge_action(key)
		"intro":
			if key == "A": broadcast_intro.finish()
			elif key == "B": _reset()
		"results":
			_clear_look_back()
			if key == "B": _reset()
			elif key == "Z": preferences.toggle_menu()
			elif finish_overlay.visible:
				var fallback: Button = finish_overlay.find_child("MainMenuButton", true, false)
				ride_navigation.navigate(finish_overlay, key, fallback)
		"race":
			match key:
				"Z": _pause_race()
				"B":
					ride_look_source = source
					ride_look_back = _riding()
					_refresh_look_back()
				"Y":
					if _riding(): _cycle_rider_names()
				"UP": _cycle_camera(-1)
				"DOWN": _cycle_camera(1)

func _ride_profile() -> String:
	return "race" if _ride_context() == "race" else "menu"

func _ride_raw_button(packet: Dictionary, testing: bool) -> void:
	var source := ride_mapping.physical(str(packet.get("source_button", "")))
	if source not in ride_mapping.BUTTONS or not packet.get("pressed") is bool: return
	if packet.pressed:
		if ride_buttons.has(source): return
		var action: String = ride_mapping.action_for(_ride_profile(), source)
		var trigger := "press"
		if not action.is_empty(): trigger = ride_mapping.profiles[_ride_profile()][action].trigger
		var key: String = ride_mapping.KEYS.get(action, "")
		# Older/custom bridge files remain authoritative until a UI mapping is saved.
		if not ride_mapping.customized and packet.has("mapped_action"):
			key = str(packet.mapped_action) if not source.begins_with("SHIFT_") else ""
			trigger = "hold" if key == "B" and _ride_profile() == "race" else "press"
		ride_buttons[source] = {"context":_ride_context(), "key":key, "trigger":trigger, "testing":testing}
		if testing:
			var preferences := get_node("GameSettings")
			if source == "Z" and not preferences.controller_test.capture_consumed:
				preferences.bridge_action("Z")
		elif trigger != "release" and not key.is_empty(): _ride_action(key, source)
	else:
		var edge: Dictionary = ride_buttons.get(source, {})
		ride_buttons.erase(source)
		if source == ride_look_source: ride_look_back = false
		if not testing and not edge.is_empty() and not edge.testing and edge.context == _ride_context() and edge.trigger == "release" and not edge.key.is_empty():
			_ride_action(edge.key, source)

func _steer_player(direction: int) -> void:
	if _ride_context() != "race" or not running or finished or not _riding():
		return
	if race_mode == 5:
		if direction > 0:
			team_race.request_player_exchange()
		return
	player_lane = clampi(player_lane + direction, 0, LANES.size() - 1)

func _read_bridge() -> void:
	while udp.get_available_packet_count() > 0:
		_process_bridge_json(udp.get_packet().get_string_from_utf8())
	_expire_bridge_optional_fields(_now_s())

func _process_steering(value: Variant) -> void:
	if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 100.0:
		return
	var pressure: float = absf(float(value))
	# Must return to neutral before another click is recognized.
	if pressure <= 15.0:
		steering_direction = 0
		steering_steps = 0
		return
	if pressure < 25.0:
		return
	var direction: int = 1 if float(value) > 0.0 else -1
	# One press = one lane, irrespective of how far the analog paddle moves.
	# Rising pressure and reversing without release never count as another click.
	if steering_direction != 0:
		return
	steering_direction = direction
	steering_steps = 1
	# Consume presses during menus/countdown so holding through GO cannot steer.
	if _ride_context() != "race" or not running or finished or not _riding():
		return
	if race_mode == 5:
		if direction > 0:
			team_race.request_player_exchange()
	else:
		player_lane = clampi(player_lane + direction, 0, LANES.size() - 1)

func _process_bridge_json(raw: String) -> void:
	var parser := JSON.new()
	if parser.parse(raw) != OK or not parser.data is Dictionary:
		return
	_process_bridge_packet(parser.data)

func _process_bridge_packet(packet: Dictionary) -> void:
	if setup_panel != null and setup_panel.ftp_page != null:
		setup_panel.ftp_page.receive(packet, _now_s())
	var preferences: Node = get_node_or_null("GameSettings")
	var testing: bool = preferences != null and preferences.call("controller_test_active")
	if packet.get("type", "") in ["controller_button", "controller_connection"]:
		if preferences != null:
			preferences.call("receive_controller_packet", packet)
		last_controller_signal = _now_s()
		if packet.get("type") == "controller_connection":
			if not bool(packet.get("connected", false)):
				ride_buttons.clear()
				ride_look_back = false
			elif packet.get("buttons") is Array:
				for held in ride_buttons.keys():
					if held not in packet.buttons: ride_buttons.erase(held)
				if ride_look_source not in packet.buttons: ride_look_back = false
		else:
			_ride_raw_button(packet, testing)
		_refresh_look_back()
		return
	if packet.get("type", "") == "steering":
		if preferences != null:
			preferences.call("receive_controller_packet", packet)
		_process_steering(packet.get("value"))
	elif packet.get("type", "") == "telemetry":
		if not trainer_seen and _riding() and not testing and _ride_context() == "race":
			_reset() # Avoid attaching a live trainer mid-demo with a flying start.
		_apply_bridge_optional_fields(packet)
		trainer_seen = true
		trainer_ready = bool(packet.get("valid", false))
		connected = trainer_ready
		if trainer_ready:
			watts = maxf(0.0, _bridge_number(packet.get("power_w"), 0.0))
			trainer_speed_kmh = _bridge_number(packet.get("speed_kmh"), -1.0)
			cadence = _bridge_number(packet.get("cadence_rpm"), -1.0)
			last_telemetry = Time.get_ticks_msec() / 1000.0
			last_good_watts = watts
			last_good_cadence = cadence
			dropout_since = -1.0
			# UDP telemetry can repeat; record each original FTMS notification once.
			var sample_id: int = int(_bridge_number(packet.get("sample_id"), -1.0))
			# New bridge: use sample_id. Older bridge: record at 5 Hz,
			# even when no sequence number is provided.
			var tick: int = Time.get_ticks_msec()
			var accept: bool = sample_id > last_sample_id if sample_id >= 0 else tick - last_record_tick >= FALLBACK_SAMPLE_INTERVAL_MS
			if not race_paused and recording_active and not recording_saved and accept:
				if sample_id >= 0:
					last_sample_id = sample_id
				last_record_tick = tick
				ride_records.append({"time_s": _training_seconds(), "distance_m": _training_distance(), "power_w": watts, "trainer_speed_kmh": trainer_speed_kmh, "game_speed_kmh": speeds[0] * 3.6, "cadence_rpm": cadence, "heart_rate_bpm": trainer_heart_rate_bpm, "lane": player_lane + 1, "draft_pct": _draft_drag_reduction(0) * 100.0})
		else:
			# Invalid sample (e.g. trainer briefly lost its sensor): bridge it like a dropout.
			_begin_dropout(_now_s())
			if _power_hold_active():
				watts = last_good_watts
				cadence = last_good_cadence
			else:
				trainer_speed_kmh = -1.0
				watts = 0.0
	elif packet.get("type", "") == "button":
		var key := str(packet.get("button", ""))
		var source: String = ride_mapping.physical(str(packet.get("source_button", key)))
		# Raw edges already routed this press; suppress the bridge's legacy copy.
		if ride_buttons.has(source): return
		if packet.get("pressed", true) != true: return
		if testing:
			if source == "Z" and key == "Z" and not preferences.controller_test.capturing and preferences.controller_test.candidate.is_empty():
				preferences.bridge_action("Z")
			return
		if ride_mapping.customized:
			var action: String = ride_mapping.action_for(_ride_profile(), source)
			if action.is_empty() or ride_mapping.profiles[_ride_profile()][action].trigger != "press": return
			_ride_action(ride_mapping.KEYS.get(action, ""), source)
			return
		if source.begins_with("SHIFT_") or key.begins_with("SHIFT_") or source in ["POWER_LEFT", "POWER_RIGHT", "DROP_LEFT", "DROP_RIGHT", "ONOFF_LEFT", "ONOFF_RIGHT"]:
			return
		_ride_action(key, source)

static func _bridge_number(value: Variant, fallback: float) -> float:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)):
		return float(value)
	return fallback

static func _bridge_optional_integer(value: Variant, minimum: int = 1, maximum: int = 2147483647) -> Variant:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null
	var number: float = float(value)
	if not is_finite(number) or number < minimum or number > maximum or floor(number) != number:
		return null
	return int(value)

func _apply_bridge_optional_fields(packet: Dictionary) -> void:
	# These fields can change at 10 Hz without a new FTMS sample or valid KICKR.
	trainer_selected_gear = _bridge_optional_integer(packet.get("gear"), 1, 12)
	trainer_heart_rate_bpm = _bridge_optional_integer(packet.get("heart_rate_bpm"))
	trainer_gear = _gear_from_packet(packet)
	last_bridge_telemetry = _now_s()

func _expire_bridge_optional_fields(now: float) -> void:
	if last_controller_signal >= 0.0 and now - last_controller_signal > 2.0:
		ride_look_back = false
		ride_buttons.clear()
		last_controller_signal = -1.0
		_refresh_look_back()
	# The bridge itself owns the ANT+ five-second freshness check. This watchdog
	# only clears optional data if the entire telemetry stream has stopped.
	if last_bridge_telemetry >= 0.0 and now - last_bridge_telemetry > BRIDGE_OPTIONAL_TIMEOUT_SECONDS:
		trainer_selected_gear = null
		trainer_heart_rate_bpm = null
		trainer_gear = "—"
		last_bridge_telemetry = -1.0

func _restart_same_race() -> void:
	if replay_setup.is_empty(): return
	for key in ["race_mode", "race_laps", "rider_count", "ai_difficulty", "demo_launch_watts", "time_trial_start_type", "time_trial_reference_kind", "time_trial_reference", "team_size", "team_resistance_mode", "pursuit_opponent_percent", "pursuit_opponent_country", "pursuit_opponent_config"]:
		set(key, replay_setup[key])
	_restarting_event = true
	_reset()
	_restarting_event = false
	if race_mode in [4, 5, 7]:
		_prepare_pursuit(replay_setup.replay, float(replay_setup.cp))
		if race_mode == 5:
			team_race.prepare(self, replay_setup.replay, float(replay_setup.cp))
			team_race.ours.configure_factors(replay_setup.team_factors)
	trainer_control.arm()
	zero_stable = 0.0
	_set_menu_visible(false)
	start_state = "WAIT_STOP"

func _reset() -> void:
	_clear_look_back()
	pursuit_start.clear()
	race_paused = false
	trainer_pause_resume = false
	if exit_menu != null:
		exit_menu.hide_pause()
		exit_menu.set_exit_visible(true)
	results_podium.clear()
	_clear_elimination_feedback()
	points_notifications.reset()
	if race_overlay != null:
		race_overlay.popup.clear()
		race_overlay.signals.clear()
	if broadcast_intro != null: broadcast_intro.cancel()
	trainer_control.release(_now_s())
	trainer_telemetry_resume = false
	trainer_road_grade = 0.0
	_save_recording("restart")
	ride_records = []
	demo_fit_records = []
	ride_start_unix = 0
	strava_export_path = ""
	fit_export_path = ""
	fit_gps_export_path = ""
	recording_active = false
	recording_saved = false
	last_sample_id = -1
	last_record_tick = -1000
	recording_message = ""
	lap_notice_until = 0.0
	lap_notice = ""
	clock = 0.0
	neutral_start.reset()
	flying_start.reset()
	countdown = 3.0
	dropout_since = -1.0
	countdown_shown = ""
	start_state = "SETUP"
	zero_stable = 0.0
	if setup_panel != null:
		setup_panel.show()
	if laps_input != null and race_mode not in [4, 5]:
		laps_input.value = race_laps
	if rider_count_input != null and race_mode not in [4, 5]:
		rider_count_input.value = rider_count
	if not trainer_seen:
		watts = 0.0
	running = false
	finished = false
	player_lane = 0
	steering_direction = 0
	steering_steps = 0
	camera_roll = 0.0
	pursuit_trace.clear()
	performance_context.clear(); performance_id = ""; performance_recorded = false
	pursuit_saved_id = ""
	if pursuit_save_box != null:
		pursuit_save_box.hide()
		pursuit_save_button.disabled = false
		pursuit_save_status.text = ""
	_configure_peloton()
	_tt_prepare_event()
	ai_think_timer = 0.0
	boost_left = 0.0
	recovery_left = 0.0
	recovery_excess = 0.0
	baseline_speed = 0.0
	boosted_speed = 0.0
	boost_used = false
	player_power_integral = 0.0
	player_peak_watts = 0.0
	player_speed_peak_kmh = 0.0
	player_samples = []
	results_shown = false
	finish_elapsed = 0.0
	if finish_overlay != null:
		finish_overlay.hide()
	team_finish_photo.clear(self)
	finish_photo_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	finish_photo_taken = false
	finish_photo_rider = -1
	finish_photo_capture_pending = false
	if finish_photo_rect != null:
		finish_photo_rect.texture = null
		finish_photo_caption.text = "FINISHFOTO"
	_set_race_hud_visible(true)
	if result_panel != null:
		result_panel.hide()
	if race_overlay != null:
		race_overlay.developer_enabled = false
		race_overlay.developer_panel.hide()
	team_race.hide_badges()
	_set_menu_visible(true)

# An opponent in front and approximately on the same line shields a rider.
# The game has no collisions yet: gaps < 1.2m are excluded to avoid rewarding overlap.
func _draft_target(rider: int) -> float:
	if race_mode in [4, 5, 7]:
		draft_leaders[rider] = -1
		return 0.0
	# Non-scratch modes retain the exact prior drafting model.
	if race_mode not in [0, 1, 2]:
		if speeds[rider] < DRAFT_MIN_SPEED_MPS:
			return 0.0
		var old_best := 0.0
		var old_leader := -1
		for other in range(rider_count):
			if other == rider or finish_times[other] >= 0.0:
				continue
			var forward_gap: float = distances[other] - distances[rider]
			if forward_gap < DRAFT_MIN_GAP_M or forward_gap > DRAFT_MAX_GAP_M:
				continue
			var lateral_gap: float = absf(lane_offsets[other] - lane_offsets[rider])
			if lateral_gap >= DRAFT_MAX_LATERAL_M:
				continue
			var real_gap: float = _at(distances[other], lane_offsets[other]).distance_to(_at(distances[rider], lane_offsets[rider]))
			if real_gap > DRAFT_MAX_GAP_M or real_gap < DRAFT_MIN_GAP_M:
				continue
			var longitudinal: float = clampf((DRAFT_MAX_GAP_M - real_gap) / (DRAFT_MAX_GAP_M - DRAFT_FULL_GAP_M), 0.0, 1.0)
			var lateral: float = clampf(1.0 - lateral_gap / DRAFT_MAX_LATERAL_M, 0.0, 1.0)
			var protection: float = longitudinal * lateral
			if protection > old_best:
				old_best = protection
				old_leader = other
		draft_leaders[rider] = old_leader
		return old_best
	if speeds[rider] < DRAFT_MIN_SPEED_MPS:
		draft_leaders[rider] = -1
		return 0.0
	var best: float = 0.0
	var best_wheel := -1
	for other in range(rider_count):
		if other == rider or finish_times[other] >= 0.0:
			continue
		var gap: float = ScratchRules.ahead_gap(distances[rider], distances[other]) if race_mode in [0, 1, 2] else distances[other] - distances[rider]
		if gap <= 0.35 or gap >= 9.0:
			continue
		var lateral: float = absf(lane_offsets[other] - lane_offsets[rider])
		if lateral >= 1.15:
			continue
		var real_gap: float = _at(distances[other], lane_offsets[other]).distance_to(_at(distances[rider], lane_offsets[rider]))
		if real_gap < 1.0 or real_gap > 9.0:
			continue
		var drag_benefit: float = 0.62 * maxf(0.0, 1.0 - gap / 10.0) * maxf(0.18, 1.0 - lateral / 1.25)
		if race_mode in [0, 1, 2]:
			var more_wheels := 0
			for third in range(rider_count):
				if third == rider or finish_times[third] >= 0.0:
					continue
				var third_gap: float = ScratchRules.ahead_gap(distances[rider], distances[third])
				if third_gap > 0.35 and third_gap < 15.0 and absf(lane_offsets[third] - lane_offsets[rider]) < 1.5:
					more_wheels += 1
			drag_benefit += minf(0.12, 0.04 * float(maxi(0, more_wheels - 1)))
		var strength: float = clampf(drag_benefit / 0.69, 0.0, 1.0)
		if strength > best:
			best = strength
			best_wheel = other
	draft_leaders[rider] = best_wheel
	return best

func _update_drafting(dt: float) -> void:
	# Evaluate everyone from the SAME positions before this frame's physics step.
	for i in range(rider_count):
		var target: float = _draft_target(i)
		var blend: float = 1.0 - exp(-dt / DRAFT_RESPONSE_SECONDS)
		draft_strengths[i] = lerpf(draft_strengths[i], target, blend)

# Effective (speed-adjusted) draft is shared by physics, AI planning, HUD and CSV.
# Only scratch uses the new speed ramp. Legacy modes remain unchanged.
func _effective_draft_strength(rider: int) -> float:
	if race_mode in [4, 5, 7]:
		return 0.0
	var strength: float = clampf(draft_strengths[rider], 0.0, 1.0)
	if race_mode not in [0, 1, 2]:
		return strength
	var speed_ratio: float = clampf((speeds[rider] - SCRATCH_DRAFT_RAMP_START_MPS) / (SCRATCH_DRAFT_RAMP_END_MPS - SCRATCH_DRAFT_RAMP_START_MPS), 0.0, 1.0)
	return strength * lerpf(SCRATCH_DRAFT_LOW_SPEED_SCALE, 1.0, speed_ratio)

func _draft_drag_reduction(rider: int) -> float:
	if race_mode in [4, 5, 7]:
		return 0.0
	var limit: float = SCRATCH_DRAFT_MAX_DRAG_REDUCTION if race_mode in [0, 1, 2] else DRAFT_MAX_DRAG_REDUCTION
	return limit * _effective_draft_strength(rider)

func _next_speed(current_speed: float, power_w: float, dt: float, draft_strength: float = 0.0) -> float:
	if race_mode in [4, 5, 7]:
		draft_strength = 0.0
	# Both player and AI use the same force balance in scratch mode, with NO speed cap.
	if race_mode in [0, 1, 2, 4, 5]:
		var v: float = maxf(current_speed, 0.0)
		var aero_factor: float = maxf(1.0 - SCRATCH_DRAFT_MAX_DRAG_REDUCTION, 1.0 - SCRATCH_DRAFT_MAX_DRAG_REDUCTION * draft_strength)
		var drag: float = 0.5 * 1.20 * 0.334 * v * v * aero_factor
		var rolling: float = 0.004 * 80.0 * GRAVITY
		var drive: float = maxf(0.0, power_w) * 0.975 / maxf(v, 2.5)
		return maxf(0.0, v + (drive - drag - rolling) / 80.0 * dt)
	# Older modes retain their own existing beta rules.
	var force: float = power_w / maxf(current_speed, 3.0)
	var drag_old: float = 0.5 * 1.225 * 0.32 * current_speed * current_speed * (1.0 - DRAFT_MAX_DRAG_REDUCTION * draft_strength)
	var rolling_old: float = 0.004 * 82.0 * 9.81
	var accel: float = clampf((force - drag_old - rolling_old) / 82.0, -3.5, 3.5)
	return clampf(current_speed + accel * dt, 0.0, 26.0)

# Lane distances are physical: outside riders must travel further around both bends.
# Smoothly bank corners and transition into/out of the straights.
func _bank_angle(s: float) -> float:
	var d: float = fposmod(s, LAP)
	var corner_progress: float = -1.0
	var arc_length: float = PI * RADIUS
	if d >= STRAIGHT and d <= STRAIGHT + arc_length:
		corner_progress = d - STRAIGHT
	elif d >= 2.0 * STRAIGHT + arc_length:
		corner_progress = d - (2.0 * STRAIGHT + arc_length)
	if corner_progress < 0.0:
		return deg_to_rad(STRAIGHT_BANK_DEG)
	var entry: float = clampf(corner_progress / BANK_TRANSITION_M, 0.0, 1.0)
	var exit_factor: float = clampf((arc_length - corner_progress) / BANK_TRANSITION_M, 0.0, 1.0)
	var a: float = minf(entry, exit_factor)
	var smooth: float = a * a * (3.0 - 2.0 * a)
	return deg_to_rad(lerpf(STRAIGHT_BANK_DEG, CORNER_BANK_DEG, smooth))

func _path_metric(s: float, offset: float) -> float:
	# d(actual route distance)/d(reference 250 m distance), including banking.
	var h: float = 0.05
	return maxf(0.5, (_at(s + h, offset) - _at(s - h, offset)).length() / (2.0 * h))

# Apply gravity as a bounded acceleration along the path, rather than
# deleting all kinetic energy for a small lateral climb in a single frame.
# A lateral transition remains more demanding but cannot pin a pedalling rider
# at zero speed. The limit is a beta gameplay safeguard, not a full bike model.
func _banked_speed(speed: float, forward_height_delta: float, lateral_height_delta: float, lateral_travel: float, dt: float, power_w: float) -> float:
	if dt <= 0.0:
		return speed
	# Forward slope is a forward force; sideways banking cannot instantly
	# remove the entire longitudinal kinetic energy of a pedalling rider.
	var travel: float = maxf(speed * dt, 0.15)
	var forward_grade: float = clampf(forward_height_delta / travel, -0.45, 0.45)
	var slope_accel: float = clampf(-GRAVITY * forward_grade, -2.0, 2.0)
	# Lateral movement has a small, bounded impact on forward progress.
	# A downward transition can help a stationary rider start rolling again.
	var lateral_accel: float = 0.0
	if lateral_travel > 0.0001:
		var side_grade: float = clampf(lateral_height_delta / lateral_travel, -1.0, 1.0)
		lateral_accel = clampf(-GRAVITY * side_grade * 0.08, -0.35, 0.55)
	# Powered riders must be able to accelerate away from a complete stop.
	var adjusted: float = maxf(0.0, speed + (slope_accel + lateral_accel) * dt)
	if power_w >= 80.0 and speed < 0.5:
		adjusted = maxf(adjusted, speed + 0.13 * dt)
	return adjusted

# Tactical AI is evaluated a few times per second, before physics advances.
# Cooperation is a TARGET-POWER strategy, never a free speed multiplier.
func _ai_decide_lanes(dt: float) -> void:
	ai_think_timer -= dt
	if ai_think_timer > 0.0:
		return
	ai_think_timer = AI_THINK_INTERVAL
	var first_ai := -1
	var first_distance := -1.0
	for j in range(1, rider_count):
		if finish_times[j] < 0.0 and distances[j] > first_distance:
			first_ai = j
			first_distance = distances[j]
	if first_ai != ai_last_leader:
		if ai_last_leader >= 0 and first_ai >= 0:
			ai_peloton_changes += 1
		ai_last_leader = first_ai
	for i in range(1, rider_count):
		if finish_times[i] >= 0.0:
			continue
		var nearest := -1
		var gap := 1000.0
		for j in range(rider_count):
			if i == j or finish_times[j] >= 0.0:
				continue
			var ahead: float = ScratchRules.ahead_gap(distances[i], distances[j]) if race_mode == 0 else distances[j] - distances[i]
			if ahead > 0.0 and ahead < gap:
				nearest = j
				gap = ahead
		var kind: int = _profile(i)
		var remaining: float = _race_length() - distances[i]
		var lap_num: int = int(distances[i] / LAP)
		var post_sprint: bool = race_laps >= 5 and lap_num > 0 and lap_num % 5 == 0 and fposmod(distances[i], LAP) < 85.0
		var chase: bool = distances[0] - distances[i] > AI_CHASE_GAP_M and remaining > 90.0
		var old_role: int = ai_role[i]
		if kind == 3 and post_sprint and ai_attack_lap[i] != lap_num and ai_energy_j[i] > 2800.0:
			# Stagger attackers: a race does not produce twelve identical attacks.
			if (i + lap_num) % 3 != 0:
				ai_role[i] = 2
				ai_role_until[i] = clock + AI_ATTACK_DURATION_S
				ai_attack_lap[i] = lap_num
				ai_attack_count[i] += 1
		elif ai_role[i] == 2 and clock < ai_role_until[i] and ai_energy_j[i] > 250.0:
			pass
		elif kind == 3 and old_role == 2:
			ai_role[i] = 3
			ai_role_until[i] = clock + 15.0
		elif old_role == 3 and clock < ai_role_until[i]:
			pass
		elif kind == 1:
			ai_role[i] = 1 # TT maintains fixed pacing, tactical marker only.
		elif chase and (i + lap_num) % 3 != 0:
			# Rotate which riders contribute; avoid everybody attacking together.
			ai_role[i] = 1 if int(clock / AI_LEAD_TURN_S + i) % 3 == 0 else 0
		else:
			ai_role[i] = 1 if (i == first_ai and int(clock / AI_LEAD_TURN_S) % 2 == 0) else 0
		var preferred: float = LANES[0]
		if ai_role[i] == 0 and nearest >= 0 and gap < 13.0:
			preferred = lane_offsets[nearest]
		elif ai_role[i] == 1 and nearest >= 0 and gap < 7.0:
			preferred = clampf(lane_offsets[nearest] + 1.20, LANES[0], LANES[LANES.size() - 1])
		elif ai_role[i] == 2:
			preferred = LANES[0]
		var sprinting: bool = (kind == 2 and remaining < 75.0) or ai_role[i] == 2
		if nearest >= 0 and gap < 5.5 and (speeds[i] > speeds[nearest] - 0.5 or sprinting):
			preferred = clampf(lane_offsets[nearest] + (1.20 if lane_offsets[nearest] < LANES[LANES.size() - 1] - 0.3 else -1.20), LANES[0], LANES[LANES.size() - 1])
		if ai_stall_time[i] > 1.3:
			preferred = LANES[0]
		ai_lane_targets[i] = preferred

# Sprinter pacing: a one-lap sprint and a ten-lap race cannot share the same
# endlessly sustainable 365 W baseline. The short finish kick still draws from
# the existing finite anaerobic reserve. Percentages are applied once at output.
func _sprinter_cruise_power() -> float:
	var distance_fraction: float = clampf((_race_length() - LAP) / (10.0 * LAP - LAP), 0.0, 1.0)
	# Power at 80% AI: 365 W over 250 m, tapering to 245 W over 2.5 km.
	# These are gameplay tuning values, not a measured sprinter power curve.
	return lerpf(365.0, 245.0, pow(distance_fraction, 0.6))

func _ai_choose_power(i: int, dt: float) -> float:
	var remaining: float = _race_length() - distances[i]
	var kind: int = _profile(i)
	var sustainable: float = (_sprinter_cruise_power() if kind == 2 else AI_SUSTAIN_W[kind]) * _form(i)
	var desired: float = sustainable
	if kind == 1:
		ai_power_w[i] = tt_constant_power_w * _form(i)
		tt_effort_remaining = clampf(1.0 - distances[i] / _race_length(), 0.0, 1.0)
		return ai_power_w[i]
	elif kind == 2:
		if remaining < 65.0:
			desired = 860.0 * _form(i)
		elif ai_role[i] == 1:
			desired = sustainable + 95.0 * _form(i)
		else:
			desired = sustainable * (0.84 if draft_strengths[i] > 0.30 else 1.0)
	else:
		# Attacker conserves energy between attacks, not a permanent 100 W fade.
		var long_race_base: float = _sprinter_cruise_power() * 0.97 * _form(i)
		sustainable = long_race_base
		if ai_role[i] == 2:
			desired = 610.0 * _form(i)
		elif ai_role[i] == 3:
			desired = sustainable * 0.80
		elif ai_role[i] == 1:
			desired = sustainable + 75.0 * _form(i)
		else:
			desired = sustainable * (0.87 if draft_strengths[i] > 0.3 else 1.0)
	var available: float = ai_energy_j[i]
	var excess: float = maxf(0.0, desired - sustainable)
	if excess > 0.0 and dt > 0.0:
		var possible_excess: float = minf(excess, available / dt)
		desired = sustainable + possible_excess
		ai_energy_j[i] = maxf(0.0, available - possible_excess * dt)
	elif desired < sustainable:
		ai_energy_j[i] = minf(AI_CAPACITY_J[kind] * _form(i), available + (sustainable - desired) * 0.35 * dt)
	ai_power_w[i] = minf(desired, AI_PEAK_W[kind] * _form(i))
	if ai_role[i] == 1:
		ai_lead_seconds[i] += dt
	return ai_power_w[i] * (ai_difficulty / 80.0)

func _move_lanes(dt: float) -> Array[float]:
	if race_mode in [4, 7]:
		return _pursuit_move_lanes(dt)
	var heights: Array[float] = []; heights.resize(rider_count); heights.fill(0.0)
	if race_mode not in [0, 1, 2]:
		_ai_decide_lanes(dt)
	for i in range(rider_count):
		var previous_height: float = _at(distances[i], lane_offsets[i]).y
		var target: float = LANES[player_lane] if i == 0 else (x_ai.lane_targets[i] if race_mode in [0, 1, 2] and x_ai.initialized else ai_lane_targets[i])
		lane_offsets[i] = move_toward(lane_offsets[i], target, LANE_CHANGE_MPS * dt)
		heights[i] = _at(distances[i], lane_offsets[i]).y - previous_height
	return heights

func _race_length() -> float:
	return float(race_laps) * LAP

func _all_riders_finished() -> bool:
	for end_time in finish_times:
		if end_time < 0.0:
			return false
	return true

func _register_lap_crossings(rider: int, previous: float, step: float, dt: float) -> void:
	if step <= 0.0:
		return
	var next_lap: int = lap_times[rider].size() + 1
	while next_lap <= race_laps and float(next_lap) * LAP <= previous + step + 0.0001:
		var line_distance: float = float(next_lap) * LAP
		var fraction: float = clampf((line_distance - previous) / step, 0.0, 1.0)
		var crossing_time: float = clock - dt + dt * fraction
		var lap_duration: float = crossing_time - last_lap_crossing[rider]
		lap_times[rider].append(lap_duration)
		last_lap_crossing[rider] = crossing_time
		if rider == 0:
			lap_notice = "JOUW RONDE %d: %.2f s" % [next_lap, lap_duration]
			lap_notice_until = clock + 6.0
		next_lap += 1

func _race_better(a: int, b: int) -> bool:
	if race_mode == 1:
		return points_rules.better(a, b, distances)
	if race_mode == 5:
		return team_race.better(a / team_size, b / team_size) if a / team_size != b / team_size else distances[a] > distances[b]
	if race_mode == 0:
		return scratch_rules.better(a, b, finish_times, distances)
	if race_mode == 2:
		var a_out: int = elimination_rules.eliminated.find(a)
		var b_out: int = elimination_rules.eliminated.find(b)
		if a_out >= 0 and b_out >= 0: return a_out > b_out
		if a_out >= 0: return false
		if b_out >= 0: return true
		if finish_times[a] >= 0.0 and finish_times[b] >= 0.0: return finish_times[a] < finish_times[b]
		if finish_times[a] >= 0.0: return true
		if finish_times[b] >= 0.0: return false
		return distances[a] > distances[b]
	if finish_times[a] >= 0.0 and finish_times[b] >= 0.0:
		return finish_times[a] < finish_times[b]
	if finish_times[a] >= 0.0:
		return true
	if finish_times[b] >= 0.0:
		return false
	return distances[a] > distances[b]

func _winner_index() -> int:
	if race_mode == 2 and elimination_rules.remaining_count() > 2: return -1
	var best := -1
	for i in range(finish_times.size()):
		if finish_times[i] >= 0.0 and (race_mode != 2 or not elimination_rules.eliminated.has(i)) and (best < 0 or _race_better(i, best)):
			best = i
	return best

func _update_trainer_control() -> void:
	if trainer_pause_resume:
		trainer_control.tick(false, 0.0, 1.0, _now_s())
		if trainer_control.phase == "RELEASING": return
		if trainer_control.error.is_empty(): trainer_control.arm(false)
		trainer_pause_resume = false
	var racing: bool = trainer_seen and running and not finished and _riding()
	var live: bool = connected and trainer_ready
	# Ignore very brief invalid samples only for an already active, owned session.
	# The bridge retains its independent three-second safety watchdog.
	var transient_gap: bool = racing and not live and trainer_control.owned and trainer_control.armed and last_telemetry >= 0.0 and _now_s() - last_telemetry <= 0.5
	var active: bool = racing and (live or transient_gap)
	# Loss of the whole UDP stream releases our load. Remember only that
	# release, so fresh telemetry can resume this race through the normal probe.
	# Invalid trainer samples, command errors and another controller never re-arm.
	if racing and not active and last_bridge_telemetry < 0.0 and trainer_control.owned and trainer_control.armed:
		trainer_telemetry_resume = true
	if trainer_telemetry_resume:
		if not racing or not trainer_control.error.is_empty() or (last_bridge_telemetry >= 0.0 and not live):
			trainer_telemetry_resume = false
		elif live and trainer_control.phase != "RELEASING" and trainer_control.may_resume and trainer_control.state.get("mode") == "RELEASED" and trainer_control.state.get("release_confirmed", false) and not trainer_control.state.get("udp_owned", false):
			trainer_control.arm(false)
			trainer_telemetry_resume = false
	# Existing ERG sessions are preserved by the client's initial status check.
	var use_erg: bool = active and race_mode == 5 and team_resistance_mode == "ERG" and team_race.ours.has_player_pull and not team_race.ours.player_is_out() and team_race.ours.player_rank() > 0 and team_race.ours.phase == ""
	var erg_target: int = clampi(roundi(team_race.ours.target_watts()), 1, 1300) if use_erg else 0
	trainer_control.tick(active, trainer_road_grade, 1.0 - _draft_drag_reduction(0), _now_s(), erg_target)

func _update_race(dt: float) -> void:
	var previous: Vector3 = _at(_rider_distance(0, distances[0]), lane_offsets[0])
	_advance_race(dt)
	var current: Vector3 = _at(_rider_distance(0, distances[0]), lane_offsets[0])
	var grade: float = TrainerControl.route_grade(previous, current)
	trainer_road_grade = lerpf(trainer_road_grade, grade, 1.0 - exp(-8.0 * maxf(dt, 0.0)))

func _advance_race(dt: float) -> void:
	if race_mode == 5:
		team_race.step(self, dt)
		return
	if race_mode in [4, 7]:
		_update_pursuit(dt)
		return
	if trainer_seen:
		boost_left = 0.0
		recovery_left = 0.0
	var boost_active: bool = race_mode not in [1, 2] and not trainer_seen and boost_left > 0.0
	var previous_distances: Array[float] = distances.duplicate()
	var prior_lanes: Array[float] = lane_offsets.duplicate()
	var lateral_height_changes: Array[float] = _move_lanes(dt)
	_update_drafting(dt)
	var effective_drafts: Array[float] = []
	for rider in range(rider_count):
		effective_drafts.append(_effective_draft_strength(rider))
	var new_lap_event: int = points_rules.events.size() if race_mode == 1 else scratch_rules.events.size()
	var x_powers: Array[float] = []
	if race_mode in [0, 1, 2]:
		x_ai.human_power_w = watts
		if race_mode == 2:
			x_ai.elimination_line_m = elimination_rules.next_line_m
			x_ai.final_line_m = _race_length()
		var tactical_positions: Array[float] = _race_positions() if race_mode == 1 else distances
		x_powers = x_ai.step(dt, clock, tactical_positions, speeds, lane_offsets, effective_drafts, finish_times, rider_profiles, race_laps, ai_difficulty, scratch_rules.credits)
	var player_actual_power: float = _pc_power(dt)
	var new_finisher := false
	for i in range(rider_count):
		if finish_times[i] >= 0.0:
			continue
		var power: float = player_actual_power if i == 0 else (x_powers[i] if race_mode in [0, 1, 2] else _ai_choose_power(i, dt))
		if race_mode in [0, 1, 2] and i > 0:
			ai_power_w[i] = power
			ai_energy_j[i] = x_ai.wprime[i]
			ai_role[i] = x_ai.modes[i]
		if i == 0:
			# A parallel non-boosted simulation: this is the speed the player
			# would have had if the arcade boost had never been activated.
			baseline_speed = _next_speed(baseline_speed, power, dt, effective_drafts[i])
			if boost_active:
				boosted_speed = _next_speed(boosted_speed, BOOST_POWER_W, dt, effective_drafts[i])
				speeds[i] = maxf(baseline_speed, boosted_speed)
			elif recovery_left > 0.0:
				# Remove ONLY the arcade speed excess, not the real pedalling speed.
				recovery_left = maxf(0.0, recovery_left - dt)
				var share: float = recovery_left / BOOST_RECOVERY_SECONDS
				speeds[i] = baseline_speed + recovery_excess * share
			else:
				speeds[i] = baseline_speed
		else:
			speeds[i] = _next_speed(speeds[i], power, dt, effective_drafts[i])
		# The surface rises/falls along bends as well as across the lanes.
		# Compute gravity with an initial path estimate, then actual distance.
		var previous: float = distances[i]
		var metric: float = _path_metric(previous, lane_offsets[i])
		var first_step: float = speeds[i] * dt / metric
		var slope_dh: float = _at(previous + first_step, lane_offsets[i]).y - _at(previous, lane_offsets[i]).y
		var lateral_travel: float = absf(lane_offsets[i] - prior_lanes[i])
		speeds[i] = _banked_speed(speeds[i], slope_dh, lateral_height_changes[i], lateral_travel, dt, power)
		if i == 0:
			baseline_speed = _banked_speed(baseline_speed, slope_dh, lateral_height_changes[i], lateral_travel, dt, power)
			if boost_active:
				boosted_speed = _banked_speed(boosted_speed, slope_dh, lateral_height_changes[i], lateral_travel, dt, BOOST_POWER_W)
		if i != 0:
			ai_stall_time[i] = ai_stall_time[i] + dt if speeds[i] < 0.6 and power >= 80.0 else 0.0
		var actual_step: float = speeds[i] * dt / metric
		if race_mode != 2:
			_register_lap_crossings(i, previous, actual_step, dt)
		distances[i] = previous + actual_step if race_mode == 1 else minf(_race_length(), previous + actual_step)
		if _profile(i) == 1:
			tt_effort_remaining = clampf(1.0 - distances[i] / _race_length(), 0.0, 1.0)
		if i == 0 and not trainer_seen:
			_capture_demo_fit_sample()
		if i == 0:
			player_power_integral += power * dt
			player_peak_watts = maxf(player_peak_watts, power)
			player_speed_peak_kmh = maxf(player_speed_peak_kmh, speeds[i] * 3.6)
			if player_samples.is_empty() or absf(player_samples[-1].x - distances[i]) >= 2.5 or distances[i] >= _race_length():
				player_samples.append(Vector2(distances[i], power))
		if race_mode not in [1, 2] and distances[i] >= _race_length():
			new_finisher = true
			if i == 1:
				tt_effort_remaining = 0.0
			var fraction: float = (_race_length() - previous) / maxf(actual_step, 0.0001)
			finish_times[i] = clock - dt + dt * fraction
			coast_distances[i] = _race_length()
			coast_speeds[i] = speeds[i]
	if race_mode == 2:
		for i in range(rider_count):
			if finish_times[i] >= 0.0: continue
			var travelled: float = maxf(0.0, distances[i] - previous_distances[i])
			_register_lap_crossings(i, previous_distances[i], travelled, dt)
			if distances[i] >= _race_length() and elimination_rules.remaining_count() <= 2:
				var fraction: float = clampf((_race_length() - previous_distances[i]) / maxf(travelled, 0.00001), 0.0, 1.0)
				finish_times[i] = clock - dt + fraction * dt
				coast_distances[i] = _race_length()
				coast_speeds[i] = speeds[i]
				new_finisher = true
		_update_elimination_jury(dt)
	if race_mode == 1:
		var old_finishes: Array[float] = finish_times.duplicate()
		points_rules.advance(previous_distances, distances, clock, dt, finish_times)
		for message in points_notifications.collect(points_rules, _race_positions().max()):
			if race_overlay != null: race_overlay.popup.enqueue(message)
		for i in range(rider_count):
			if old_finishes[i] < 0.0 and finish_times[i] >= 0.0:
				new_finisher = true
				var fraction: float = clampf((finish_times[i] - clock + dt) / dt, 0.0, 1.0)
				distances[i] = lerpf(previous_distances[i], distances[i], fraction)
				coast_distances[i] = distances[i]
				coast_speeds[i] = speeds[i]
	if race_mode == 0:
		scratch_rules.examine(distances, finish_times, clock)
	if race_mode in [0, 1]:
		var lap_events: Array = points_rules.events if race_mode == 1 else scratch_rules.events
		for index in range(new_lap_event, lap_events.size()):
			if race_mode == 1: continue # Points have their own filtered, transient popup queue.
			var event: Dictionary = lap_events[index]
			var change: int = int(event.get("delta", 1 if event.get("kind", "") == "gain" else -1))
			if int(event.rider) == 0:
				var message: String = "RONDE GEWONNEN · +20 PUNTEN · TERUG IN HET PELOTON" if change > 0 else "RONDE VERLOREN · −20 PUNTEN"
				if race_mode == 0: message = "RONDE GEWONNEN" if change > 0 else "RONDE VERLOREN"
				_announce_race_event(message)
			else:
				var detail: String = "ronde gewonnen" if change > 0 else "ronde verloren"
				if race_mode == 1: detail += " (+20 pt)" if change > 0 else " (−20 pt)"
				_announce_race_event("%s · %s" % [_rider_name(int(event.rider)), detail], false)
		peloton_info = peloton_state.sample(distances, _lap_credits(), finish_times)
	# Capture while the winner is crossing, rather than after the LAST rider
	# finishes. A subsequently finishing lap winner replaces the earlier photo.
	if new_finisher and race_mode != 2:
		var provisional_winner: int = _winner_index()
		if provisional_winner >= 0 and provisional_winner != finish_photo_rider:
			_take_finish_photo(provisional_winner)
	if boost_active:
		boost_left = maxf(0.0, boost_left - dt)
		if boost_left <= 0.0:
			recovery_excess = maxf(0.0, boosted_speed - baseline_speed)
			recovery_left = BOOST_RECOVERY_SECONDS
	if finish_times[0] >= 0.0 and not finished:
		if race_mode != 2: _register_performance()
		finished = true
		finish_elapsed = 0.0
		running = false
		_save_recording("finish")

# ONE coordinate transform for both geometry and banking/lean lookup.
# Start and finish share the same physical line, at the END of the right-hand straight
# when travelling CCW, immediately before the curved section.
func _track_s(distance: float) -> float:
	return fposmod(-distance, LAP)

func _at(distance: float, offset: float) -> Vector3:
	# Counter-clockwise velodrome: reversed traversal of the old clockwise path.
	# Positive offsets stay toward the outside, independent of direction.
	# At the right-hand straight the rider now heads toward -Z; the infield is LEFT.
	var s: float = _track_s(distance)
	var x := 0.0
	var z := 0.0
	var nx := 0.0
	var nz := 0.0
	if s < STRAIGHT:
		x = RADIUS
		z = -STRAIGHT / 2.0 + s
		nx = 1.0
	elif s < STRAIGHT + PI * RADIUS:
		var angle := (s - STRAIGHT) / RADIUS
		x = RADIUS * cos(angle)
		z = STRAIGHT / 2.0 + RADIUS * sin(angle)
		nx = cos(angle)
		nz = sin(angle)
	elif s < 2.0 * STRAIGHT + PI * RADIUS:
		x = -RADIUS
		z = STRAIGHT / 2.0 - (s - STRAIGHT - PI * RADIUS)
		nx = -1.0
	else:
		var angle := PI + (s - 2.0 * STRAIGHT - PI * RADIUS) / RADIUS
		x = RADIUS * cos(angle)
		z = -STRAIGHT / 2.0 + RADIUS * sin(angle)
		nx = cos(angle)
		nz = sin(angle)
	# The blue apron stays at a fixed 12-degree cross-slope all the way around.
	# Wood starts at the same height at TRACK_EDGE, then uses the variable
	# banking angle; the shared boundary therefore remains watertight.
	var apron_width: float = minf(offset, TRACK_EDGE)
	var wood_width: float = maxf(0.0, offset - TRACK_EDGE)
	var height: float = 0.015 + apron_width * tan(deg_to_rad(BLUE_APRON_BANK_DEG)) + wood_width * tan(_bank_angle(s))
	return Vector3(x + offset * nx, height, z + offset * nz)

func _direction(s: float, offset: float) -> Vector3:
	return (_at(s + 0.2, offset) - _at(s - 0.2, offset)).normalized()

# Exact segments of our 250m capsule: two straights, two half-circle bends.
# Do NOT infer a bend from camera yaw, lateral track gradient or heading.
func _curve_factor(s: float) -> float:
	var d: float = _track_s(s)
	var arc: float = PI * RADIUS
	var progress: float = -1.0
	if d >= STRAIGHT and d < STRAIGHT + arc:
		progress = d - STRAIGHT
	elif d >= 2.0 * STRAIGHT + arc and d < LAP:
		progress = d - (2.0 * STRAIGHT + arc)
	if progress < 0.0:
		return 0.0
	# 8 metres of smoothing INSIDE the curve; straights are always zero.
	var edge: float = minf(progress, arc - progress)
	var fraction: float = clampf(edge / 8.0, 0.0, 1.0)
	return fraction * fraction * (3.0 - 2.0 * fraction)

func _visual_lean(i: int) -> float:
	var curve: float = _curve_factor(_rider_distance(i, distances[i]))
	if curve <= 0.0:
		return 0.0
	var speed_factor: float = clampf((speeds[i] * 3.6 - LEAN_MIN_SPEED_KMH) / (LEAN_FULL_SPEED_KMH - LEAN_MIN_SPEED_KMH), 0.0, 1.0)
	var eased: float = speed_factor * speed_factor * (3.0 - 2.0 * speed_factor)
	# All riders travel counter-clockwise. Both bends turn left.
	# Rider local +Z is forward: observed positive Z roll leans OUTWARD in game.
	# Negative Z roll tips toward the infield on our CCW oval.
	return -deg_to_rad(CORNER_BANK_DEG) * curve * eased


# Only appearance continues after crossing; measured race distances and finish times stay locked.
func _update_coasting(dt: float) -> void:
	for i in range(rider_count):
		if finish_times[i] < 0.0:
			continue
		if race_mode == 2 and elimination_exit.has(i):
			_update_eliminated_exit(i, dt)
			continue
		if coast_speeds[i] <= 0.0: continue
		var old_speed: float = coast_speeds[i]
		coast_speeds[i] = maxf(0.0, old_speed - COAST_BRAKE_MPS2 * dt)
		coast_distances[i] += (old_speed + coast_speeds[i]) * 0.5 * dt / _path_metric(_rider_distance(i, coast_distances[i]), lane_offsets[i])

func _place_results_camera() -> void:
	if camera == null: return
	var podium := find_child("Podium", true, false) as Node3D
	if podium == null: return
	results_podium.update(self,podium)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 62.0
	# Keep the actual podium to the right of the ivory results sheet.
	camera.global_position = podium.to_global(Vector3(-5.3, 3.5, 7.0))
	camera.look_at(podium.to_global(Vector3(-5.3, 1.0, 0)))

func _place_finish_camera() -> void:
	# Fixed on the infield, pointing slightly past the finish line along travel direction.
	var line: Vector3 = _at(_rider_distance(0, _race_length()), FINISH_CAMERA_LANE_M)
	var next_point: Vector3 = _at(_rider_distance(0, _race_length()) + 7.0, FINISH_CAMERA_LANE_M)
	var direction: Vector3 = Vector3(next_point.x - line.x, 0.0, next_point.z - line.z).normalized()
	var inner: Vector3 = _at(_rider_distance(0, _race_length()), 0.3)
	var outward: Vector3 = _at(_rider_distance(0, _race_length()), 7.5)
	var infield: Vector3 = Vector3(inner.x - outward.x, 0.0, inner.z - outward.z).normalized()
	camera.global_position = line + infield * 10.0 - direction * 4.0 + Vector3.UP * 4.3
	camera.fov = 68.0
	camera.look_at(line + direction * 6.0 + Vector3.UP * 1.1)

func _player_won() -> bool:
	if race_mode == 5:
		return team_race.better(0, 1)
	if finish_times[0] < 0.0:
		return false
	for i in range(1, rider_count):
		if finish_times[i] >= 0.0 and _race_better(i, 0):
			return false
	return true

func _update_visuals(dt: float) -> void:
	if finish_overlay != null and finish_overlay.visible:
		_place_results_camera()
		return
	if setup_panel != null and setup_panel.visible:
		team_race.hide_badges()
	if setup_panel != null and setup_panel.visible:
		# Quiet architectural view, independent of riders and racing cameras.
		camera.position = Vector3(46, 42, 66)
		camera.look_at(Vector3(0, 1.0, 0))
		camera.fov = 68.0
		camera.rotation.z = 0.0
		return
	for i in range(rider_count):
		var lateral: float = lane_offsets[i]
		var display_distance: float = coast_distances[i] if finish_times[i] >= 0.0 else distances[i]
		var starting_grid: float = float(i / 4) * 2.4 if start_state != "RACING" and not finished and race_mode not in [0, 1, 2, 4, 5] else 0.0
		display_distance = _rider_distance(i, display_distance)
		var position: Vector3 = _at(display_distance - FRONT_WHEEL_TIP_M - starting_grid, lateral)
		# Imported Blender wheel mesh reaches local ground at y=0.  On the
		# bank, visual lean can otherwise push the inboard tyre below the track.
		var model_lift: float = 0.085 + 0.18 * absf(sin(visual_rolls[i]))
		bikes[i].position = position + Vector3(0.0, model_lift, 0.0)
		var tangent: Vector3 = _direction(display_distance, lateral)
		bikes[i].rotation.y = atan2(tangent.x, tangent.z)
		var lean_target: float = _visual_lean(i)
		visual_rolls[i] = lerp_angle(visual_rolls[i], lean_target, clampf(dt * (12.0 if lean_target == 0.0 else 5.0), 0.0, 1.0))
		bikes[i].rotation.z = visual_rolls[i]
		pursuit_start.align_rider(self, i, display_distance - FRONT_WHEEL_TIP_M - starting_grid, model_lift)
		if race_mode == 2 and elimination_exit.has(i) and int(elimination_exit[i]["stage"]) >= 1:
			var exit_state: Dictionary = elimination_exit[i]
			bikes[i].position = Vector3(exit_state["position"]) + Vector3.UP * 0.09
			var head: Vector3 = Vector3(exit_state["heading"])
			bikes[i].rotation.y = atan2(head.x, head.z)
			bikes[i].rotation.z = 0.0
		var visual: Node = bikes[i].get_child(0)
		var cadence_visual: float = cadence if i == 0 and connected and cadence >= 0.0 else clampf(speeds[i] * 6.0, 0.0, 120.0)
		if race_mode == 5 and i == 0 and team_race.ours.player_is_out() and watts <= 0.0:
			cadence_visual = 0.0
		if finish_times[i] >= 0.0:
			# Continue the normal cycling loop at progressively lower cadence while coasting.
			# beta.16.16: the race winner sits up and raises both arms.
			visual.call("set_victory", race_mode != 2 and i == _winner_index())
			visual.call("pedal", dt, clampf(coast_speeds[i] * 5.5, 0.0, 110.0), 120.0)
		else:
			visual.call("set_victory", false)
			visual.call("pedal", dt, cadence_visual, watts if i == 0 else (ai_power_w[i] if race_mode in [0, 1] or _profile(i) == 1 else ai_power_w[i] * ai_difficulty / 80.0))
	pursuit_start.update(self, dt)
	team_race.update_badges(self)
	_update_bunch_presentation()
	if broadcast_intro != null and broadcast_intro.apply_camera(): return
	if finished:
		_place_finish_camera()
		return
	var offset: float = lane_offsets[0]
	var t: Vector3 = _direction(_rider_distance(0, distances[0]), offset)
	var start_view: bool = not _riding() and not finished
	var follow_position: Vector3 = bikes[0].position
	var desired: Vector3
	var target: Vector3
	var target_fov: float = 72.0
	var pov_sway: float = 0.0
	if look_back_held:
		# Rearward view from just ahead of the rider: follow the curved track,
		# so other riders behind remain visible even through the banking.
		# No changes to bike movement, lane choice, or race physics.
		desired = _at(_rider_distance(0, distances[0]) + 3.0, offset) + Vector3(0.0, 2.65, 0.0)
		target = _at(_rider_distance(0, distances[0]) - 13.0, offset) + Vector3(0.0, 1.10, 0.0)
		target_fov = 77.0
	elif camera_mode == 2:
		# Very subtle POV sway synchronized to the standing sprint crank phase.
		# Keep it visual-only; this never changes bike position or race physics.
		var own_visual: Node = bikes[0].get_child(0)
		pov_sway = float(own_visual.call("get_pov_sway"))
		var side: Vector3 = Vector3(t.z, 0.0, -t.x).normalized()
		var sway_shift: Vector3 = side * (0.042 * pov_sway)
		desired = follow_position + Vector3(0.0, 1.63 + 0.012 * absf(pov_sway), 0.0) + t * 0.35 + sway_shift
		target = desired + t * 18.0 + Vector3(0.0, -0.13, 0.0)
		target_fov = 78.0
	elif camera_mode == 3:
		# Infield side camera to inspect rider posture and bike shape.
		var inner_probe: Vector3 = _at(_rider_distance(0, distances[0]), maxf(0.2, offset - 1.8))
		var outer_probe: Vector3 = _at(_rider_distance(0, distances[0]), minf(8.4, offset + 1.8))
		# IMPORTANT: lateral track probe includes vertical banking height.
		# Taking its 3D normal pulled the camera BELOW the infield floor in bends.
		# Use a horizontal-only inward direction and independent camera height.
		var inward: Vector3 = Vector3(inner_probe.x - outer_probe.x, 0.0, inner_probe.z - outer_probe.z).normalized()
		desired = follow_position + inward * 5.1 + Vector3(0.0, 2.65, 0.0) - t * 0.45
		target = follow_position + Vector3(0.0, 1.10, 0.0) + t * 0.55
		target_fov = 66.0
	else:
		var close_mode: bool = camera_mode == 0
		var back: float = (7.8 if start_view else 4.5) if close_mode else (17.0 if start_view else 11.0)
		var height: float = (3.7 if start_view else 2.8) if close_mode else (8.0 if start_view else 5.0)
		# Follow the actual track arc rather than extending the current tangent.
		# This keeps the chase camera inboard of the external advertising wall.
		var safe_lane: float = clampf(offset - 0.75, 1.1, 6.3)
		var back_on_track: Vector3 = _at(_rider_distance(0, distances[0]) - back, safe_lane)
		desired = back_on_track + Vector3(0.0, height, 0.0)
		target = _at(_rider_distance(0, distances[0]) + (7.0 if close_mode else 9.0), offset) + Vector3(0.0, 1.1, 0.0)
		target_fov = (72.0 if close_mode else 77.0) if start_view else (69.0 if close_mode else 72.0)
	if boost_left > 0.0:
		target_fov += 4.0
	camera.global_position = camera.global_position.lerp(desired, clampf(dt * (11.0 if look_back_held else (9.0 if camera_mode == 2 else 5.0)), 0.0, 1.0))
	camera.fov = lerpf(camera.fov, target_fov, clampf(dt * 3.0, 0.0, 1.0))
	camera.look_at(target)
	# The camera is not parented to the animated rider: stable head POV.
	# POV follows most of the lean; chase views intentionally remain subtle.
	var follow_ratio: float = 0.08 if look_back_held else (0.8 if camera_mode == 2 else (0.0 if camera_mode == 3 else (0.22 if camera_mode == 0 else 0.12)))
	# Camera looks along local -Z while the bicycle faces local +Z.
	# Their roll signs therefore differ; negate to follow the visible rider lean.
	var pov_rock_roll: float = deg_to_rad(1.8) * pov_sway if camera_mode == 2 and not look_back_held else 0.0
	camera_roll = lerp_angle(camera_roll, -visual_rolls[0] * follow_ratio + pov_rock_roll, clampf(dt * (12.0 if _curve_factor(_rider_distance(0, distances[0])) == 0.0 else 8.0), 0.0, 1.0))
	camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), camera_roll)

func _update_boost_dog(dt: float) -> void:
	if boost_dog == null or bikes.is_empty():
		return
	var active: bool = boost_left > 0.0 and not trainer_seen and not finished and start_state == "RACING"
	if not active:
		boost_dog.call("set_boost_visual", false, dt, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, 0.0)
		return
	var forward: Vector3 = _direction(distances[0], lane_offsets[0])
	# Place the dog 2.6 metres in front of the front wheel, on the same banked lane.
	var dog_position: Vector3 = _at(distances[0] + 2.6, lane_offsets[0]) + Vector3.UP * 0.03
	# The point is expressed in bicycle-local coordinates: it stays attached to
	# the handlebar even when the bicycle steers or leans on the banking.
	var handlebar_world: Vector3 = bikes[0].to_global(Vector3(0.0, 1.02, 0.53))
	boost_dog.call("set_boost_visual", true, dt, dog_position, forward, handlebar_world, visual_rolls[0])

func _build_world() -> void:
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("192b40")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.7
	sky.environment = env
	add_child(sky)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 28, 0)
	light.light_energy = 1.5
	add_child(light)
	var floor := MeshInstance3D.new()
	floor.name = "ArenaOndergrond"
	# The broad underlay needs the same opening as the visible infield floor;
	# otherwise it hides every below-ground stair despite the cut-out above it.
	var ground := ArrayMesh.new()
	var vertices := PackedVector3Array()
	for bounds in [Rect2(-110,-110,107.725,220),Rect2(2.275,-110,107.725,220),Rect2(-2.275,-110,4.55,105.3),Rect2(-2.275,4.7,4.55,105.3)]:
		var a := Vector3(bounds.position.x,0,bounds.position.y)
		var b := Vector3(bounds.position.x,0,bounds.end.y)
		var c := Vector3(bounds.end.x,0,bounds.position.y)
		var d := Vector3(bounds.end.x,0,bounds.end.y)
		vertices.append_array(PackedVector3Array([a,b,c,c,b,d]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	floor.mesh = ground
	floor.material_override = _mat(Color("294b45"))
	floor.position.y = -0.2
	add_child(floor)
	# Photo-inspired pine wood with UVs following the 250 m track and its bank.
	# Track finish, blue apron and race marks are separate thin paint surfaces.
	_build_realistic_track()
	boost_dog = preload("res://boost_dog.gd").new()
	add_child(boost_dog)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72
	add_child(camera)
	countdown_label = Label3D.new()
	countdown_label.name = "Aftelklok"
	countdown_label.font_size = 256
	countdown_label.outline_size = 56
	countdown_label.outline_modulate = Color("0b1a2d")
	countdown_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	countdown_label.no_depth_test = true
	countdown_label.render_priority = 20
	countdown_label.outline_render_priority = 19
	countdown_label.visible = false
	add_child(countdown_label)

# The normal is perpendicular to the banked track rather than straight upwards.
# Using this for paint avoids the floating-line effect in the old build.
func _track_normal(distance: float, offset: float) -> Vector3:
	var along: Vector3 = _at(distance + 0.12, offset) - _at(distance - 0.12, offset)
	var outward: Vector3 = _at(distance, offset + 0.06) - _at(distance, offset - 0.06)
	return outward.cross(along).normalized()

func _track_textured_surface(inner: float, outer: float, texture: Texture2D, name_text: String, length_tile: float, width_tile: float, tint: Color, roughness: float) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# 1,000 segments for smooth banking, especially in the 42-degree curves.
	for i in range(1000):
		var s0: float = LAP * float(i) / 1000.0
		var s1: float = LAP * float(i + 1) / 1000.0
		var a: Vector3 = _at(s0, inner)
		var b: Vector3 = _at(s0, outer)
		var c: Vector3 = _at(s1, inner)
		var d: Vector3 = _at(s1, outer)
		var n0: Vector3 = _track_normal(s0, (inner + outer) * 0.5)
		var n1: Vector3 = _track_normal(s1, (inner + outer) * 0.5)
		for v in [a, b, c, c, b, d]:
			verts.append(v)
		for n in [n0, n0, n1, n1, n0, n1]:
			normals.append(n)
		for uv in [Vector2(s0 / length_tile, 0.0), Vector2(s0 / length_tile, (outer-inner)/width_tile), Vector2(s1 / length_tile, 0.0), Vector2(s1 / length_tile, 0.0), Vector2(s0 / length_tile, (outer-inner)/width_tile), Vector2(s1 / length_tile, (outer-inner)/width_tile)]:
			uvs.append(uv)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = name_text
	surface.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = tint
	mat.texture_repeat = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

func _build_realistic_track() -> void:
	# The apron and wooden surface share an edge, but now have independent bank angles.
	_track_textured_surface(0.0, TRACK_EDGE, BLUE_APRON_TEXTURE, "Cote d'Azur - licht geschilderde aanloop", 8.0, 0.78, Color("ffffff"), 0.80)
	_track_textured_surface(TRACK_EDGE, TRACK_OUTER_EDGE, WOOD_TEXTURE, "Piste - gelakte grenenhouten latten", 12.5, 2.24, Color("f6f1e7"), 0.65)
	preload("res://track_branding.gd").build(self)
	# The inner and outer edges have a painted lip but NO collision mesh.
	_track_band(0.00, 0.035, Color("e1f4f4"), 0.0, LAP, 0.010)
	_track_band(0.754, 0.786, Color("f2eee2"), 0.0, LAP, 0.010)
	_track_band(8.995, 9.035, Color("dcd3b7"), 0.0, LAP, 0.008)
	_track_band(9.038, 9.095, Color("1b3450"), 0.0, LAP, 0.008)
	# UCI-style longitudinal lines: 5 cm wide, distance from WOOD inner edge.
	# Measuring line 20 cm, sprinters line 85 cm, stayers line >= 2.45 m.
	_track_band(0.98, 1.03, Color("24262a"), 0.0, LAP, 0.010)
	_track_band(1.63, 1.68, Color("c03936"), 0.0, LAP, 0.010)
	_track_band(3.53, 3.58, Color("2874a7"), 0.0, LAP, 0.010)
	# Discreet black distance ticks every 5 metres, slightly longer every 10.
	_track_distance_ticks()
	# Pursuit starting lines sit in the middle of the two straights.
	var pursuit_a: float = fposmod(LAP - STRAIGHT * 0.5, LAP)
	var pursuit_b: float = fposmod(LAP - (1.5 * STRAIGHT + PI * RADIUS), LAP)
	_track_band(TRACK_EDGE + 0.02, TRACK_OUTER_EDGE - 0.05, Color("bb262b"), pursuit_a, 0.10, 0.025)
	_track_band(TRACK_EDGE + 0.02, TRACK_OUTER_EDGE - 0.05, Color("bb262b"), pursuit_b, 0.10, 0.025)
	# A modest 4 cm white 200 m line, 50 m after the lap's finish reference.
	_track_band(TRACK_EDGE, TRACK_OUTER_EDGE, Color("f6f2e7"), 50.0, 0.04, 0.016)
	# Regulation-inspired finish: 72 cm white strip + 4 cm black in centre.
	# Centred at race distance zero; the race timing reference is unchanged.
	_track_band(TRACK_EDGE, TRACK_OUTER_EDGE, Color("f7f6ed"), -0.36, 0.72, 0.017)
	_track_band(TRACK_EDGE, TRACK_OUTER_EDGE, Color("151719"), -0.02, 0.04, 0.024)

func _track_distance_ticks() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(1, 50):
		var s: float = float(i) * 5.0
		var outer: float = 1.20 if (i % 2 == 0) else 1.13
		var n: Vector3 = _track_normal(s, 1.04)
		var a: Vector3 = _at(s - 0.019, 0.978) + n * 0.014
		var b: Vector3 = _at(s - 0.019, outer) + n * 0.014
		var c: Vector3 = _at(s + 0.019, 0.978) + n * 0.014
		var d: Vector3 = _at(s + 0.019, outer) + n * 0.014
		for v in [a, b, c, c, b, d]:
			verts.append(v)
			normals.append(n)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var obj := MeshInstance3D.new()
	obj.name = "Afstandsmerktekens elke vijf meter"
	obj.mesh = mesh
	obj.material_override = _mat(Color("28282b"))
	obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(obj)

func _track_band(inner: float, outer: float, color: Color, start_s: float = 0.0, extent: float = LAP, lift: float = 0.0) -> void:
	# Tiny perpendicular markings require only a few segments, not 1,000.
	var segments: int = maxi(2, int(ceil(extent * 4.0)))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(segments):
		var s0: float = start_s + float(i) / float(segments) * extent
		var s1: float = start_s + float(i + 1) / float(segments) * extent
		var n0: Vector3 = _track_normal(s0, (inner + outer) * 0.5)
		var n1: Vector3 = _track_normal(s1, (inner + outer) * 0.5)
		var a: Vector3 = _at(s0, inner) + n0 * lift
		var b: Vector3 = _at(s0, outer) + n0 * lift
		var c: Vector3 = _at(s1, inner) + n1 * lift
		var d: Vector3 = _at(s1, outer) + n1 * lift
		for vertex in [a, b, c, c, b, d]:
			verts.append(vertex)
		for normal in [n0, n0, n1, n1, n0, n1]:
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = _mat(color)
	obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(obj)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	return material

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	race_overlay = preload("res://race_hud.gd").new()
	layer.add_child(race_overlay)
	race_hud_items.append(race_overlay)
	elimination_notice = Label.new()
	elimination_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	elimination_notice.position = Vector2(-420, 135)
	elimination_notice.custom_minimum_size = Vector2(840, 90)
	elimination_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elimination_notice.add_theme_font_size_override("font_size", 38)
	elimination_notice.add_theme_color_override("font_color", Color("ffe6c8"))
	elimination_notice.visible = false
	layer.add_child(elimination_notice)
	race_hud_items.append(elimination_notice)
	# Existing detailed readouts live in the scrollable developer layer.
	hud = Label.new()
	note = Label.new()
	note.add_theme_color_override("font_color", Color("ffd199"))
	rankings = Label.new()
	var developer_labels: Array[Label] = [hud, note, rankings]
	race_overlay.set_developer_texts(developer_labels)
	minimap = race_overlay.map
	# Separate mode gallery and race configuration, above a quiet arena.
	var menu = preload("res://race_menu.gd").new()
	menu.library = pursuit_library
	menu.records_store = performance_records
	setup_panel = menu
	layer.add_child(menu)
	rider_count_input = menu.count_input
	laps_input = menu.laps_input
	difficulty_slider = menu.difficulty_slider
	difficulty_label = menu.difficulty_label
	rider_count_input.value = rider_count
	laps_input.value = race_laps
	difficulty_slider.value = ai_difficulty
	menu.difficulty_changed.connect(_difficulty_changed)
	menu.start_requested.connect(_confirm_start)
	menu.training_environment_requested.connect(_training_environment_requested)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(24, 255)
	result_panel.custom_minimum_size = Vector2(425, 380)
	result_panel.visible = false
	layer.add_child(result_panel)
	race_hud_items.append(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 6)
	result_panel.add_child(result_box)
	result_title = Label.new()
	result_title.add_theme_font_size_override("font_size", 22)
	result_box.add_child(result_title)
	result_body = Label.new()
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(405, 170)
	result_body.add_theme_font_size_override("font_size", 16)
	result_box.add_child(result_body)
	result_graph = preload("res://stats_graph.gd").new()
	result_graph.custom_minimum_size = Vector2(340, 118)
	result_box.add_child(result_graph)
	# Finishing overlay: semi-transparent backdrop and a proper results table.
	finish_overlay = ColorRect.new()
	finish_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish_overlay.theme = MenuSkin.create()
	finish_overlay.color = Color(0.07, 0.16, 0.27, 0.08)
	finish_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	finish_overlay.hide()
	layer.add_child(finish_overlay)
	var center := MarginContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: center.add_theme_constant_override("margin_"+side,64)
	center.add_theme_constant_override("margin_top",22);center.add_theme_constant_override("margin_bottom",30)
	finish_overlay.add_child(center)
	var results_stack := VBoxContainer.new();results_stack.add_theme_constant_override("separation",14);center.add_child(results_stack)
	var results_brand := HBoxContainer.new();results_stack.add_child(results_brand);results_brand.add_child(MenuSkin.logo());results_brand.add_spacer(false)
	var results_body := HBoxContainer.new();results_body.size_flags_vertical=Control.SIZE_EXPAND_FILL;results_stack.add_child(results_body)
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(1320, 0)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = MenuSkin.IVORY
	shell_style.border_color = MenuSkin.WOOD
	shell_style.set_border_width_all(0)
	shell_style.border_width_top = 5
	shell_style.set_corner_radius_all(22)
	shell_style.set_content_margin_all(26)
	shell.add_theme_stylebox_override("panel", shell_style)
	results_body.add_child(shell)
	results_body.add_spacer(false)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 13)
	shell.add_child(sheet)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	sheet.add_child(title_row)
	var heading_stack := VBoxContainer.new()
	title_row.add_child(heading_stack)
	finish_heading = Label.new()
	finish_heading.add_theme_font_override("font", MenuSkin.heading())
	finish_heading.add_theme_font_size_override("font_size", 36)
	finish_heading.add_theme_color_override("font_color", MenuSkin.INK)
	heading_stack.add_child(finish_heading)
	var subtitle := Label.new()
	finish_subtitle = subtitle
	subtitle.text = "S P R I N T   2 5 0 M     |     OFFICIELE WEDSTRIJDRESULTATEN"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", MenuSkin.MUTED)
	heading_stack.add_child(subtitle)
	title_row.add_spacer(false)
	finish_badge = Label.new()
	finish_badge.add_theme_font_size_override("font_size", 26)
	finish_badge.add_theme_color_override("font_color", MenuSkin.INK)
	title_row.add_child(finish_badge)
	var accent := ColorRect.new()
	accent.color = MenuSkin.WOOD
	accent.custom_minimum_size = Vector2(0, 3)
	sheet.add_child(accent)
	finish_results = Label.new()
	finish_results.add_theme_font_size_override("font_size", 16)
	finish_results.add_theme_color_override("font_color", MenuSkin.INK)
	sheet.add_child(finish_results)
	var table_row := HBoxContainer.new()
	table_row.add_theme_constant_override("separation", 16)
	table_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(table_row)
	var table_scroll := ScrollContainer.new()
	table_scroll.custom_minimum_size = Vector2(815, 270)
	table_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_row.add_child(table_scroll)
	_build_finish_photo_ui(table_row)
	finish_table = GridContainer.new()
	finish_table.columns = 5
	finish_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish_table.add_theme_constant_override("h_separation", 3)
	finish_table.add_theme_constant_override("v_separation", 4)
	table_scroll.add_child(finish_table)
	pursuit_save_box = VBoxContainer.new()
	pursuit_save_box.add_theme_constant_override("separation", 8)
	sheet.add_child(pursuit_save_box)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 16)
	pursuit_save_box.add_child(save_row)
	pursuit_save_name = LineEdit.new()
	pursuit_save_name.placeholder_text = "Geef je rit een naam"
	pursuit_save_name.max_length = 48
	pursuit_save_name.custom_minimum_size = Vector2(550, 52)
	pursuit_save_name.add_theme_font_size_override("font_size", 22)
	save_row.add_child(pursuit_save_name)
	pursuit_save_button = Button.new()
	pursuit_save_button.text = "Rit opslaan"
	pursuit_save_button.custom_minimum_size = Vector2(220, 52)
	_style_finish_button(pursuit_save_button, MenuSkin.BLUE, Color.WHITE)
	pursuit_save_button.pressed.connect(_save_pursuit_ride)
	save_row.add_child(pursuit_save_button)
	pursuit_save_status = Label.new()
	pursuit_save_status.add_theme_font_size_override("font_size", 18)
	pursuit_save_status.add_theme_color_override("font_color", MenuSkin.MUTED)
	pursuit_save_box.add_child(pursuit_save_status)
	pursuit_save_box.hide()
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	sheet.add_child(buttons)
	var again := Button.new()
	again.name = "ReplayRaceButton"
	again.text = "Wedstrijd opnieuw rijden"
	again.custom_minimum_size = Vector2(340, 58)
	_style_finish_button(again, MenuSkin.BLUE, Color.WHITE)
	again.pressed.connect(_restart_same_race)
	buttons.add_child(again)
	var strava_button := Button.new()
	strava_button.text = "Export naar Strava"
	strava_button.icon = load("res://strava_logo.svg")
	strava_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	strava_button.custom_minimum_size = Vector2(250, 58)
	_style_finish_button(strava_button, MenuSkin.PAPER, MenuSkin.INK, MenuSkin.LINE)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		strava_button.add_theme_color_override(state, MenuSkin.BLUE)
	strava_button.pressed.connect(_export_to_strava)
	buttons.add_child(strava_button)
	var fit_button := Button.new()
	fit_button.text = "Exporteer .FIT"
	fit_button.custom_minimum_size = Vector2(210, 58)
	_style_finish_button(fit_button, MenuSkin.PAPER, MenuSkin.INK, MenuSkin.LINE)
	fit_button.pressed.connect(func(): _export_strava_fit(true))
	buttons.add_child(fit_button)
	var quit := Button.new()
	quit.name = "MainMenuButton"
	quit.text = "Terug naar hoofdmenu"
	quit.custom_minimum_size = Vector2(300, 58)
	_style_finish_button(quit, MenuSkin.PAPER, MenuSkin.INK, MenuSkin.LINE)
	quit.pressed.connect(_reset)
	buttons.add_child(quit)

func _build_finish_photo_ui(row: HBoxContainer) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.96, 0.94)                 # white photo border
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", style)
	row.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	frame.add_child(stack)
	finish_photo_rect = TextureRect.new()
	finish_photo_rect.custom_minimum_size = Vector2(416, 260)
	finish_photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	finish_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stack.add_child(finish_photo_rect)
	finish_photo_caption = Label.new()
	finish_photo_caption.add_theme_font_size_override("font_size", 14)
	finish_photo_caption.add_theme_color_override("font_color", Color("1b2533"))
	finish_photo_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish_photo_caption.text = "FINISHFOTO"
	stack.add_child(finish_photo_caption)
	# Off-screen camera at the photographers' spot; renders only once, when the winner crosses the line.
	finish_photo_viewport = SubViewport.new()
	finish_photo_viewport.name = "FinishFotoViewport"
	finish_photo_viewport.size = Vector2i(1040, 650)
	finish_photo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	finish_photo_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(finish_photo_viewport)
	finish_photo_camera = Camera3D.new()
	finish_photo_camera.name = "FinishFotoCamera"
	finish_photo_camera.fov = 30.0
	finish_photo_camera.cull_mask = 0xFFFFF & ~2     # no floating name tags on the photo
	finish_photo_viewport.add_child(finish_photo_camera)
	finish_photo_camera.current = true

func _take_team_finish_photo(front: float, offsets: Array[float], lanes: Array[float], seconds: float) -> void:
	team_finish_photo.capture(self, front, offsets, lanes, seconds)

func _take_finish_photo(winner: int) -> void:
	if finish_photo_viewport == null or winner < 0 or winner == finish_photo_rider:
		return
	finish_photo_taken = true
	finish_photo_rider = winner
	var line_d: float = _rider_distance(winner, _race_length())
	var lane: float = lane_offsets[winner] if winner < lane_offsets.size() else 1.0
	# Photographer: infield side, a few metres past the line, camera above the handrail, aiming back at the line.
	var spot: Vector3 = _at(line_d + FINISH_PHOTO_AFTER_LINE_M, FINISH_PHOTO_INFIELD_OFFSET)
	spot.y = 1.5
	var target: Vector3 = _at(line_d - 0.3, lane) + Vector3.UP * 0.85
	finish_photo_camera.global_position = spot
	finish_photo_camera.look_at(target, Vector3.UP)
	finish_photo_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	finish_photo_caption.text = "FINISHFOTO  •  %s  •  %.2f s" % [_rider_name(winner).to_upper(), finish_times[winner]]
	# Avoid duplicate connections if several riders cross within one frame.
	if not finish_photo_capture_pending:
		finish_photo_capture_pending = true
		RenderingServer.frame_post_draw.connect(_grab_finish_photo, CONNECT_ONE_SHOT)

func _grab_finish_photo() -> void:
	finish_photo_capture_pending = false
	if finish_photo_viewport == null:
		return
	var img: Image = finish_photo_viewport.get_texture().get_image()
	team_finish_photo.clear(self)
	if img == null or img.is_empty():
		return
	finish_photo_rect.texture = ImageTexture.create_from_image(img)
	if race_mode == 2 and arena != null:
		var stadium_screen: Node = arena.find_child("InfinityScreen", true, false)
		if stadium_screen != null and stadium_screen.get("scoreboard") != null:
			stadium_screen.scoreboard.show_elimination_photo(finish_photo_rect.texture, 5.0)

func _rider_name(index: int) -> String:
	return player_display_name if index == 0 else (rider_names[index] if index < rider_names.size() else "AI")

func _set_race_hud_visible(is_visible: bool) -> void:
	for item in race_hud_items:
		if is_instance_valid(item):
			item.visible = is_visible

func _set_menu_visible(is_visible: bool) -> void:
	if setup_panel == null:
		return
	setup_panel.visible = is_visible
	if is_visible:
		results_podium.clear()
		_clear_elimination_feedback()
		setup_panel.call("show_choices")
	_set_race_hud_visible(not is_visible)
	if result_panel != null:
		result_panel.hide()
	for bike in bikes:
		bike.visible = not is_visible
	for person in get_tree().get_nodes_in_group("stadium_people"):
		person.visible = not is_visible
	if boost_dog != null:
		boost_dog.visible = not is_visible
	if arena != null and arena.get("board") != null:
		arena.get("board").visible = not is_visible

func _training_environment_requested(active: bool) -> void:
	if active:
		if training_environment == null:
			training_environment = preload("res://training_environment.gd").new()
			add_child(training_environment)
		broadcast_intro.cancel()
		training_environment.enter()
	elif training_environment != null:
		training_environment.leave()
		exit_menu.set_exit_visible(true)

func _difficulty_changed(value: float) -> void:
	ai_difficulty = value
	difficulty_label.text = "AI-sterkte · %d%%" % int(ai_difficulty)

func _confirm_start() -> void:
	if setup_panel == null or start_state != "SETUP" or bridge_bind_error != OK:
		return
	var choice: int = int(setup_panel.get("selected"))
	if choice not in [0, 1, 2, 3, 5, 7]:
		return
	if choice in [1,2] and setup_panel.page != 4: return
	var replay: Dictionary = {}
	var options = null
	if choice in [1, 2]:
		options = setup_panel.get("pursuit_options" if choice == 1 else "team_options")
		if not options.can_start():
			return
		if options.is_replay():
			replay = options.library.load_ride(options.selected_ride_id())
			if replay.is_empty() or replay["distance_m"] != options.distance_m():
				options.refresh_rides()
				setup_panel.pursuit_flow._load_candidates(true)
				setup_panel.pursuit_flow.status.text = "Deze rit is niet meer beschikbaar. Kies een andere tegenstander."
				setup_panel.pursuit_flow.status.show()
				return
	if choice in [1,2]:
		pursuit_opponent_percent = float(options.opponent_percent)
		if not replay.is_empty(): replay = PursuitRecords.scaled_replay(replay, pursuit_opponent_percent)
	if not trainer_seen:
		demo_launch_watts = float(setup_panel.get("demo_power_input").value)
	race_mode = 7 if choice == 7 else (5 if choice == 2 else (4 if choice == 1 else (2 if choice == 5 else (1 if choice == 3 else 0))))
	race_laps = int(setup_panel.time_trial_distance.get_selected_id() / LAP) if choice == 7 else (int(options.distance_m() / LAP) if choice in [1, 2] else ((2 * (int(setup_panel.elimination_count_picker.get_selected_id()) - 2) + 2) if choice == 5 else (clampi(int(laps_input.value) / 10, 1, 12) * 10 if choice == 3 else clampi(int(laps_input.value), 1, 30))))
	if choice == 2:
		team_size = options.team_size()
		team_resistance_mode = options.resistance_mode()
		team_library.configure_team(team_size)
	rider_count = 1 if choice == 7 else (team_size * 2 if choice == 2 else (2 if choice == 1 else (int(setup_panel.elimination_count_picker.get_selected_id()) if choice == 5 else clampi(int(rider_count_input.value), 6, 16 if choice == 3 else 12))))
	if choice in [1, 2]:
		var selected_ai: Dictionary = options.selected_ai()
		if choice == 1: pursuit_opponent_config = selected_ai
		else: pursuit_opponent_country = String(selected_ai.get("country", "netherlands"))
	_clear_elimination_feedback()
	selected_startlist.clear()
	startlist_mode = -1
	if choice in [0,3,5] and setup_panel.page == 5:
		if not setup_panel.startlist_page.can_start(): return
		selected_startlist.assign(setup_panel.startlist_page.lineup.duplicate(true))
		startlist_mode = race_mode
	_configure_peloton()
	if choice == 7:
		time_trial_start_type = "flying" if setup_panel.time_trial_start.selected == 1 else "standing"
		time_trial_reference_kind = ["last", "recent", "alltime", "none"][setup_panel.time_trial_reference.selected]
		time_trial_reference = time_trial_records.references(int(_race_length()), -1.0, time_trial_start_type).get(time_trial_reference_kind, {})
		_prepare_pursuit({}, 0.0)
	elif choice in [1, 2]:
		_prepare_pursuit(replay, options.configured_cp())
		if choice == 2:
			team_race.prepare(self, replay, options.configured_cp())
			team_race.ours.configure_factors(options.configured_factors())
	else:
		_tt_prepare_event()
	replay_setup = {"riders": rider_identities.duplicate(true), "forms": rider_forms.duplicate(), "replay": replay.duplicate(true), "cp": options.configured_cp() if options != null else 0.0, "team_factors": team_race.ours.position_factors.duplicate()}
	for key in ["race_mode", "race_laps", "rider_count", "ai_difficulty", "demo_launch_watts", "time_trial_start_type", "time_trial_reference_kind", "time_trial_reference", "team_size", "team_resistance_mode", "pursuit_opponent_percent", "pursuit_opponent_country", "pursuit_opponent_config"]:
		replay_setup[key] = get(key)
	trainer_control.arm()
	zero_stable = 0.0
	_set_menu_visible(false)
	broadcast_intro.start()

# Godot user:// is writable in exported Windows and Linux games.
# Full real trainer records, including the original measurement times.
func _save_recording(reason: String) -> void:
	if recording_saved:
		return
	if ride_records.is_empty():
		recording_message = "Geen KICKR-metingen opgenomen; controleer LIVE-verbinding en start wedstrijd."
		print(recording_message)
		return
	var folder: String = OS.get_user_data_dir().path_join("recordings")
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		recording_message = "FOUT: opnamemap niet beschikbaar (%d)" % error
		push_warning(recording_message)
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var filename: String = "kickr_ride_%s_%s_%d.csv" % [stamp, reason, Time.get_ticks_msec()]
	var path: String = folder.path_join(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		recording_message = "FOUT: opname niet opgeslagen (%d)" % FileAccess.get_open_error()
		push_warning(recording_message)
		return
	file.store_csv_line(PackedStringArray(["time_s", "distance_m", "power_w", "trainer_speed_kmh", "game_speed_kmh", "cadence_rpm", "lane", "draft_pct", "heart_rate_bpm"]))
	for entry in ride_records:
		file.store_csv_line(PackedStringArray([
			"%.3f" % float(entry["time_s"]), "%.3f" % float(entry["distance_m"]),
			"%.1f" % float(entry["power_w"]), "%.2f" % float(entry["trainer_speed_kmh"]),
			"%.2f" % float(entry["game_speed_kmh"]), "%.1f" % float(entry["cadence_rpm"]),
			str(int(entry["lane"])), "%.2f" % float(entry["draft_pct"]),
			str(entry["heart_rate_bpm"]) if entry.get("heart_rate_bpm") != null else ""
		]))
	file.close()
	recording_saved = true
	recording_active = false
	recording_folder = folder
	recording_message = "KICKR-opname opgeslagen: %s (%d metingen)" % [filename, ride_records.size()]
	print(recording_message, " in ", path)

# GPS-free indoor cycling export. Strava accepts TCX files with real workout samples.
# The virtual track is represented by recorded distance, NOT fabricated ocean GPS.
func _export_strava_tcx() -> void:
	if ride_records.size() < 2:
		recording_message = "Strava-export: geen KICKR-data beschikbaar (demo wordt niet geexporteerd)."
		push_warning(recording_message)
		if finish_overlay != null and finish_overlay.visible:
			_refresh_fullscreen_results()
		return
	if strava_export_path != "":
		recording_message = "Strava TCX: " + strava_export_path
		if finish_overlay != null and finish_overlay.visible:
			_refresh_fullscreen_results()
		return
	var folder: String = OS.get_user_data_dir().path_join("recordings")
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		recording_message = "Strava-export: map kon niet gemaakt worden (%d)" % err
		push_warning(recording_message)
		return
	var epoch: int = ride_start_unix
	if epoch <= 0:
		epoch = int(Time.get_unix_time_from_system() - float(ride_records[-1]["time_s"]))
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = folder.path_join("velodrome_250_strava_%s.tcx" % stamp)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		recording_message = "Strava-export mislukt (%d)" % FileAccess.get_open_error()
		push_warning(recording_message)
		return
	var start_time: String = Time.get_datetime_string_from_unix_time(epoch) + "Z"
	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line('<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">')
	file.store_line('  <Activities><Activity Sport="Biking">')
	file.store_line('    <Id>%s</Id>' % start_time)
	var initial_distance: float = float(ride_records[0]["distance_m"])
	var total_time: float = maxf(0.0, float(ride_records[-1]["time_s"]) - float(ride_records[0]["time_s"]))
	var total_distance: float = maxf(0.0, float(ride_records[-1]["distance_m"]) - initial_distance)
	file.store_line('    <Lap StartTime="%s">' % start_time)
	file.store_line('      <TotalTimeSeconds>%.3f</TotalTimeSeconds>' % total_time)
	file.store_line('      <DistanceMeters>%.3f</DistanceMeters>' % total_distance)
	file.store_line('      <Calories>0</Calories><Intensity>Active</Intensity><TriggerMethod>Manual</TriggerMethod>')
	file.store_line('      <Track>')
	for entry in ride_records:
		var seconds: float = float(entry["time_s"]) - float(ride_records[0]["time_s"])
		var time_iso: String = Time.get_datetime_string_from_unix_time(epoch + int(seconds)) + "Z"
		var metres: float = maxf(0.0, float(entry["distance_m"]) - initial_distance)
		var rpm: float = float(entry["cadence_rpm"])
		var power: int = maxi(0, roundi(float(entry["power_w"])))
		var speed_ms: float = maxf(0.0, float(entry["game_speed_kmh"]) / 3.6)
		file.store_line('        <Trackpoint><Time>%s</Time><DistanceMeters>%.3f</DistanceMeters>' % [time_iso, metres])
		var heart_rate: int = preload("res://fit_export.gd").heart_rate_value(entry.get("heart_rate_bpm"))
		if heart_rate != 255:
			file.store_line('          <HeartRateBpm><Value>%d</Value></HeartRateBpm>' % heart_rate)
		if rpm >= 0.0:
			file.store_line('          <Cadence>%d</Cadence>' % clampi(roundi(rpm), 0, 254))
		file.store_line('          <Extensions><ns3:TPX><ns3:Speed>%.3f</ns3:Speed><ns3:Watts>%d</ns3:Watts></ns3:TPX></Extensions>' % [speed_ms, power])
		file.store_line('        </Trackpoint>')
	file.store_line('      </Track></Lap>')
	file.store_line('    <Notes>Velodrome 250 - virtuele indoorbaan, zonder GPS. Vermogen/cadans gemeten via Wahoo KICKR.</Notes>')
	file.store_line('  </Activity></Activities></TrainingCenterDatabase>')
	file.close()
	strava_export_path = path
	recording_message = "Strava TCX opgeslagen: " + path
	print(recording_message)
	if finish_overlay != null and finish_overlay.visible:
		_refresh_fullscreen_results()

# Test-only telemetry from the game simulation. No physical trainer data is implied.
func _capture_demo_fit_sample() -> void:
	_capture_player_demo_fit_sample(false)

func _capture_player_demo_fit_sample(force: bool = false) -> void:
	if trainer_seen or not _riding() or finish_times[0] >= 0.0:
		return
	if not force and not demo_fit_records.is_empty() and _training_seconds() - float(demo_fit_records[-1]["time_s"]) < DEMO_FIT_SAMPLE_INTERVAL and distances[0] < _race_length():
		return
	# Estimate cadence for UI/export testing only, based on simulated speed.
	var simulated_cadence: float = clampf(speeds[0] * 6.0, 0.0, 130.0)
	demo_fit_records.append({"time_s": _training_seconds(), "distance_m": _training_distance(), "power_w": watts, "game_speed_kmh": speeds[0] * 3.6, "cadence_rpm": simulated_cadence})

func _confirm_demo_fit_export(with_gps: bool) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "TESTEXPORT - gesimuleerde rit"
	dialog.dialog_text = "WAARSCHUWING: dit bestand bevat GESIMULEERDE wattages, cadans en snelheid.\nEr is geen echte KICKR-rit gemeten.\n\nAlleen gebruiken om de FIT-export te testen; niet publiceren als echte sportprestatie."
	dialog.ok_button_text = "Demo-FIT opslaan"
	dialog.cancel_button_text = "Annuleren"
	add_child(dialog)
	dialog.confirmed.connect(func(): _export_strava_fit(with_gps, true))
	dialog.popup_centered(Vector2i(580, 220))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

# Export FIT v1.0. Does not require Strava credentials, Python, or an online connection.
# The GPS coordinates are fictional; FIT indoor is the default/recommended export.
func _export_strava_fit(with_gps: bool, demo_confirmed: bool = false) -> void:
	var is_demo: bool = ride_records.size() < 2
	if is_demo and not demo_confirmed:
		_confirm_demo_fit_export(with_gps)
		return
	var export_records: Array[Dictionary] = demo_fit_records if is_demo else ride_records
	if export_records.size() < 2:
		recording_message = "FIT-export: minstens 2 metingen nodig. Rijd eerst een demorace."
		push_warning(recording_message)
		_refresh_fullscreen_results()
		return
	var old_path: String = fit_gps_export_path if with_gps else fit_export_path
	if old_path != "":
		recording_message = "FIT reeds opgeslagen: " + old_path
		_refresh_fullscreen_results()
		return
	var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if folder.is_empty():
		folder = OS.get_user_data_dir().path_join("recordings")
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		recording_message = "FIT-export: doelmap niet beschikbaar (%d)" % err
		push_warning(recording_message)
		return
	var epoch: int = ride_start_unix
	if epoch <= 0:
		epoch = int(Time.get_unix_time_from_system() - float(export_records[-1]["time_s"]))
	var payload: PackedByteArray = preload("res://fit_export.gd").build(export_records, epoch, with_gps)
	if payload.is_empty():
		recording_message = "FIT-export: onvoldoende gegevens"
		push_warning(recording_message)
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var suffix: String = ("DEMO_virtual_gps" if with_gps else "DEMO_indoor") if is_demo else ("virtual_gps" if with_gps else "indoor")
	var path: String = folder.path_join("velodrome_250_%s_%s.fit" % [suffix, stamp])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		recording_message = "FIT-export: bestand kon niet gemaakt worden (%d)" % FileAccess.get_open_error()
		push_warning(recording_message)
		return
	file.store_buffer(payload)
	file.close()
	if with_gps:
		fit_gps_export_path = path
	else:
		fit_export_path = path
	recording_message = ("LET OP: GESIMULEERDE TESTRIT - " if is_demo else "") + "FIT opgeslagen (%s): %s" % [suffix, path]
	print(recording_message)
	_refresh_fullscreen_results()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_look_back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if what == NOTIFICATION_WM_CLOSE_REQUEST and setup_panel != null and setup_panel.ftp_page != null:
			setup_panel.ftp_page.shutdown()
		trainer_control.close()
		_save_recording("exit")

func _show_results() -> void:
	var first_show: bool = not results_shown
	results_shown = true
	if result_panel == null:
		return
	result_panel.show()
	var rank := 1
	for i in range(1, rider_count):
		if finish_times[i] >= 0.0 and _race_better(i, 0):
			rank += 1
	var ordered: Array[int] = []
	for n in range(rider_count): ordered.append(n)
	ordered.sort_custom(func(a, b): return _race_better(a, b))
	var avg_speed: float = _race_length() / maxf(0.1, finish_times[0]) * 3.6
	var avg_power: float = player_power_integral / maxf(0.1, finish_times[0])
	var winner_gap_text := "+0.00 s" if rank == 1 else "--"
	if rank > 1 and not ordered.is_empty():
		var champion: int = ordered[0]
		if race_mode == 0 and scratch_rules.credits[champion] != scratch_rules.credits[0]:
			winner_gap_text = "%d ronde(n) achter" % (scratch_rules.credits[champion] - scratch_rules.credits[0])
		elif finish_times[champion] >= 0.0:
			winner_gap_text = "+%.2f s" % (finish_times[0] - finish_times[champion])
	result_title.text = "SPRINT VOLTOOID - PLAATS %d/%d" % [rank, rider_count]
	var table := "Eindtijd: %.2f s\nGem. snelheid: %.1f km/u    Piek snelheid: %.1f km/u\nGem. vermogen: %.0f W    Piekvermogen: %.0f W\nVerschil met winnaar: %s\n\nKLASSEMENT (live tot iedereen finisht)\n" % [finish_times[0], avg_speed, player_speed_peak_kmh, avg_power, player_peak_watts, winner_gap_text]
	for pos in range(ordered.size()):
		var idx: int = ordered[pos]
		if finish_times[idx] >= 0.0:
			table += "%d. %-15s %.2f s\n" % [pos + 1, _rider_name(idx), finish_times[idx]]
		else:
			var gap_m: float = distances[idx] - distances[0]
			table += "%d. %-15s nog bezig (%+.0f m)\n" % [pos + 1, _rider_name(idx), gap_m]
	table += "\nRONDETIJDEN (s)\n"
	for idx in range(rider_count):
		table += "%s: " % _rider_name(idx)
		if lap_times[idx].is_empty():
			table += "--"
		else:
			for k in range(lap_times[idx].size()):
				table += "%d:%.2f  " % [k + 1, float(lap_times[idx][k])]
		table += "\n"
	result_body.text = table
	if first_show:
		result_graph.call("set_title", "JOUW VERMOGEN OVER %d m" % int(_race_length()))
		result_graph.call("set_samples", player_samples, _race_length(), maxf(900.0, player_peak_watts * 1.05))

func _lean_debug_text() -> String:
	var on_bend: bool = _curve_factor(distances[0]) > 0.001
	return "BANK DEBUG: %s | offset %.1f m | lean %.1f deg" % ["BOCHT" if on_bend else "RECHT", _track_s(distances[0]), rad_to_deg(visual_rolls[0])]

func _ai_diagnostics_text() -> String:
	var uses_wprime: bool = race_mode in [0, 1, 2]
	var text: String = "\nAI: %d%% | CP / W-prime model X\n" % int(ai_difficulty) if uses_wprime else "\nAI: %d%% (80%% = beta.10)\nAI resterende inspanning (TT) / anaeroob\n" % int(ai_difficulty)
	for j in range(1, rider_count):
		# The reserve and its maximum must come from the same model, including
		# the rider's form and configured W-prime factor. Legacy capacities are
		# smaller and can otherwise turn a valid reserve into more than 100%.
		var reserve: float = x_ai.wprime[j] / maxf(1.0, x_ai.wmax[j]) if uses_wprime else (tt_effort_remaining if _profile(j) == 1 else ai_energy_j[j] / maxf(1.0, AI_CAPACITY_J[_profile(j)] * _form(j)))
		var energy_pct: int = roundi(100.0 * clampf(reserve, 0.0, 1.0))
		# Shared-model watts already include difficulty; display them once.
		var displayed_power: float = ai_power_w[j] if uses_wprime or _profile(j) == 1 else ai_power_w[j] * ai_difficulty / 80.0
		text += "%s: %d%%  %.0f W\n" % [_rider_name(j), energy_pct, displayed_power]
	return text

func _update_hud() -> void:
	if setup_panel != null and setup_panel.visible:
		setup_panel.update_bridge_status(trainer_seen, connected and trainer_ready, bridge_bind_error != OK)
		return
	var status := "KICKR LIVE" if connected else ("KICKR WACHT OP DATA" if trainer_seen else "DEMO (startpreset %.0f W)" % demo_launch_watts)
	if not connected and _power_hold_active():
		status = "KICKR SIGNAAL WEG - %.0f W vastgehouden (%d s)" % [last_good_watts, ceili(DROPOUT_HOLD_SECONDS - (_now_s() - dropout_since))]
	var stage := "SPRINT!"
	if finished:
		stage = "FINISH!"
	elif start_state == "SETUP":
		stage = "KIES AI-STERKTE EN DRUK START"
	elif start_state == "WAIT_STOP":
		stage = "WACHT OP STILSTAND" if _start_requires_standstill() else "KLAAR VOOR VERTREK"
	elif start_state == "COUNTDOWN":
		stage = "START OVER %d" % maxi(1, ceili(countdown))
	elif trainer_seen and not connected and _power_hold_active():
		stage = "SIGNAAL WEG - DOORRIJDEN OP %.0f W" % last_good_watts
	elif trainer_seen and not connected:
		stage = "PAUZE - GEEN KICKR DATA"
	elif not trainer_seen and boost_left > 0.0:
		stage = "1500 W BOOST! %.1f s" % boost_left
	elif not trainer_seen and recovery_left > 0.0:
		stage = "BOOST AFBOUW %.1f s" % recovery_left
	hud.text = "VELODROME 250  |  %s\n%s    Ronde %d/%d    Tijd: %.1f s\n%.0f W    %.1f km/u    Cadans: %s\nNog: %.0f m    Rijlijn: %d/%d\nSlipstream: %d%% minder luchtweerstand" % [status, stage, mini(race_laps, int(distances[0] / LAP) + 1), race_laps, clock, watts, speeds[0] * 3.6, "--" if cadence < 0 else str(roundi(cadence)), _race_length() - distances[0], player_lane + 1, LANES.size(), roundi(100.0 * _draft_drag_reduction(0))]
	if lap_notice != "" and clock < lap_notice_until:
		hud.text += "\n" + lap_notice
	var order: Array[int] = []
	for n in range(rider_count): order.append(n)
	order.sort_custom(func(a, b): return _race_better(a, b))
	var rows := "SCRATCH-KLASSEMENT (t.o.v. jou)\n" if race_mode == 0 else "RANGLIJST (t.o.v. jou)\n"
	for i in range(order.size()):
		var racer: int = order[i]
		var gap: float = distances[racer] - distances[0]
		var gap_text: String = "JIJ" if racer == 0 else ("%.0f m voor" % gap if gap >= 0.0 else "%.0f m achter" % -gap)
		if race_mode == 0 and racer != 0 and scratch_rules.credits[racer] != scratch_rules.credits[0]:
			gap_text = "%+d ronde(n)" % (scratch_rules.credits[racer] - scratch_rules.credits[0])
		var finished_text: String = " | %.2f s" % finish_times[racer] if finish_times[racer] >= 0.0 else ""
		rows += "%d. %s  %s%s\n" % [i + 1, _rider_name(racer), gap_text, finished_text]
	rows += "\nLAATSTE RONDE\n"
	for j in range(rider_count):
		var n: int = lap_times[j].size()
		rows += "%s: %s\n" % [_rider_name(j), ("%d: %.2f s" % [n, float(lap_times[j][n - 1])]) if n > 0 else "--"]
	rows += _ai_diagnostics_text()
	rankings.text = rows
	minimap.set_progress(distances)
	# camera changes do not alter race state
	if arena != null:
		if race_mode == 4:
			arena.get("board").text = "ACHTERVOLGING\n%s: %.0f m\n%s: %.0f m" % [_rider_name(0), distances[0], _rider_name(1), distances[1]]
		else:
			arena.call("set_ranking", distances)
	# The original result panel is intentionally hidden during the finish replay.
	# All results move to the dedicated full-screen page after 10 seconds.
	if finished:
		var rank := 1
		for i in range(1, rider_count):
			if finish_times[i] >= 0.0 and _race_better(i, 0):
				rank += 1
		note.text = "FINISH: plaats %d/%d | %.2f s | %s | R = opnieuw" % [rank, rider_count, finish_times[0], recording_message if recording_message != "" else "demo: geen echte opname"]
	elif start_state == "SETUP":
		note.text = "Kies de spelmodus, AI-sterkte, deelnemers en rondes."
	elif start_state == "WAIT_STOP":
		if not _start_requires_standstill():
			note.text = "Je mag blijven trappen; wacht op geldige trainergegevens." if trainer_seen else "Klaar voor de aanloop."
		elif trainer_seen and not connected:
			note.text = "KICKR: wacht op verse Bluetooth-data."
		elif trainer_seen and trainer_speed_kmh < 0.0:
			note.text = "KICKR: snelheid ontbreekt; start geblokkeerd."
		elif trainer_seen:
			note.text = "Stop met trappen: KICKR moet 0 W en 0 km/u melden. (%.1f km/u)" % trainer_speed_kmh
		else:
			note.text = "Demo: 0 W / 0 km/u. Startvermogen: %.0f W (pijlen)." % demo_launch_watts
	elif start_state == "COUNTDOWN":
		note.text = "Blijf rustig trappen; de aanloop begint na de aftelling." if not _start_requires_standstill() else ("Blijf stil staan tot START!" if trainer_seen else "Start uit stilstand; vanaf GO %.0f W. Pijlen wijzigen preset." % demo_launch_watts)
	else:
		note.text = "KICKR-opname: %d metingen | P = bewaren" % ride_records.size() if recording_active else (recording_message if recording_message != "" else ("SPATIE: eenmalige arcade-boost!" if not boost_used and not trainer_seen else "Kies tactisch je rijlijn. Sprint naar de finish! (P = KICKR-opname bewaren)"))

	if start_state == "NEUTRAL":
		hud.text = "GENEUTRALISEERDE RONDE | %.0f W | %.1f km/u\n%s" % [watts, speeds[0] * 3.6, neutral_start.notice(self)]
		note.text = "De wedstrijdtijd en rondentelling beginnen bij de vliegende start."
	if start_state == "RUN_UP":
		hud.text = "AANLOOPRONDE | %.0f W | %.1f km/u\n%s" % [watts, speeds[0] * 3.6, flying_start.notice(self)]
		note.text = "Versnel voor de vliegende start. De klok begint bij GO!"
	_update_compact_hud(order)

static func _gear_from_packet(packet: Dictionary) -> String:
	if packet.has("gear"):
		var value: Variant = _bridge_optional_integer(packet["gear"], 1, 12)
		return str(value) if value != null else "—"
	# Preserve legacy display-only gear labels when no canonical gear is present.
	var label: Variant = packet.get("gear_label")
	if label is String:
		var trimmed: String = label.strip_edges()
		return trimmed.left(16) if not trimmed.is_empty() else "—"
	return "—"

func _hud_leader_gap(order: Array[int]) -> String:
	if order.size() < 2:
		return "Aan kop"
	var reference: int = order[1] if order[0] == 0 else order[0]
	var gap: float = distances[0] - distances[reference]
	var output: String = "%.0f m voor" % gap if gap > 0.5 else ("%.0f m achter" % -gap if gap < -0.5 else ("Aan kop" if order[0] == 0 else "0 m achter"))
	# Distances already include travelled laps; never add lap credits a second time.
	if race_mode == 0 and scratch_rules.credits[0] != scratch_rules.credits[reference]:
		output += " · %+d ronde" % (scratch_rules.credits[0] - scratch_rules.credits[reference])
	return output

func _update_compact_hud(order: Array[int]) -> void:
	if race_mode == 5:
		team_race.hud(self)
		return
	if race_overlay == null:
		return
	if race_mode in [0,1]: peloton_info = peloton_state.sample(distances, _lap_credits(), finish_times)
	var race_positions: Array[float] = _race_positions()
	if race_mode in [0, 1]: order = _physical_order(race_positions)
	var physical_positions: Array[float] = []
	var names: Array[String] = []
	var gaps: Array[String] = []
	var colours: Array[Color] = []
	var palette := [Color("ffdc46"), Color("54d39b"), Color("52b5fa"), Color("ff7676")]
	for id in range(rider_count):
		physical_positions.append(_rider_distance(id, distances[id]))
		names.append(_rider_name(id))
		var delta: float = race_positions[id] - race_positions[0]
		var gap_text: String = "JIJ" if id == 0 else "%+d m" % roundi(delta)

		gaps.append(gap_text)
		var colour: Color = palette[id % palette.size()]
		if id < rider_kits.size():
			colour = Color.from_string(str(rider_kits[id].get("jersey_color", "")), colour)
		colours.append(colour)
	var notice := ""
	if start_state == "WAIT_STOP":
		notice = "Stop met trappen om de aftelling te starten." if trainer_seen else "Klaar voor de start · demo"
		if not _start_requires_standstill(): notice = "Je mag blijven trappen · klaar voor de aanloop"
		if trainer_seen and (not connected or trainer_speed_kmh < 0.0):
			notice = "Wachten op geldige trainergegevens…"
	elif start_state == "COUNTDOWN":
		notice = ("Blijf stilstaan · start over %d" if _start_requires_standstill() else "Je mag blijven trappen · vertrek over %d") % maxi(1, ceili(countdown))
	elif trainer_seen and not connected and not finished:
		notice = "Trainerverbinding onderbroken · vermogen tijdelijk vastgehouden" if _power_hold_active() else "Wedstrijd gepauzeerd · wacht op de trainerverbinding"
	elif finished:
		notice = "Finish · %.2f s" % finish_times[0]
	if _now_s() < name_view_notice_until: notice = "V | Rennersnamen: " + ["Auto", "Aan", "Uit"][rider_name_mode]
	if clock < race_event_until: notice = race_event_message
	if start_state == "NEUTRAL" and (not trainer_seen or connected or _power_hold_active()): notice = neutral_start.notice(self)
	if start_state == "RUN_UP" and (not trainer_seen or connected or _power_hold_active()): notice = flying_start.notice(self)
	var shown_seconds: float = finish_times[0] if finish_times[0] >= 0.0 else clock
	var markers: Array[float] = [_rider_distance(0, 0.0)]
	if race_mode == 4:
		markers.append(_rider_distance(1, 0.0))
	minimap.set("start_lines", markers)
	var pursuit_lap_pair: Array[float] = [-1.0, -1.0]
	var pursuit_delta := 0.0
	var pursuit_live_gap: Variant = null
	var pursuit_stats_pair: Array = [{}, {}]
	if race_mode == 4:
		# First arrival selects the checkpoint; the other time stays empty.
		var latest: int = maxi(pursuit_half_crossings[0].size(), pursuit_half_crossings[1].size())
		if latest > 0:
			for i in range(2):
				if pursuit_half_crossings[i].size() == latest:
					var prior: float = float(pursuit_half_crossings[i][latest - 2]) if latest > 1 else 0.0
					pursuit_lap_pair[i] = float(pursuit_half_crossings[i][latest - 1]) - prior
					if pursuit_half_stats[i].size() >= latest:
						pursuit_stats_pair[i] = pursuit_half_stats[i][latest - 1]
			var first: int = 0 if pursuit_half_crossings[0].size() == latest else 1
			var first_time: float = float(pursuit_half_crossings[first][latest - 1])
			if pursuit_half_crossings[0].size() == latest and pursuit_half_crossings[1].size() == latest:
				pursuit_live_gap = float(pursuit_half_crossings[1][latest - 1]) - float(pursuit_half_crossings[0][latest - 1])
			else:
				pursuit_live_gap = maxf(0.0, clock - first_time) * (1.0 if first == 0 else -1.0)
			pursuit_delta = -float(pursuit_live_gap)

	race_overlay.update_race({"run_up": start_state == "RUN_UP", "solo_start_type": time_trial_start_type, "neutralised": start_state == "NEUTRAL", "solo_time_trial": race_mode == 7, "solo_crossings": pursuit_half_crossings[0], "solo_reference": time_trial_reference, "solo_reference_kind": time_trial_reference_kind, "solo_distance_m": _race_length(), "solo_remaining_m": maxf(0.0, _race_length() - distances[0]), "elimination": race_mode == 2, "points_race": race_mode == 1, "race_positions": race_positions if race_mode in [0,1] else [], "peloton": peloton_info, "peloton_gap": PelotonState.gap_text(race_positions[0], peloton_info) if race_mode in [0,1] else "", "points_order": _points_order() if race_mode == 1 else [], "point_scores": points_rules.points if race_mode == 1 else [],"pursuit_live_gap": pursuit_live_gap, "pursuit_stats": pursuit_stats_pair, "pursuit": race_mode == 4, "team_half_crossings": pursuit_half_crossings[0], "opponent_half_crossings": pursuit_half_crossings[1], "pursuit_laps": pursuit_lap_pair, "pursuit_split_delta": pursuit_delta, "pursuit_opponent": "AI" if pursuit_replay.is_empty() else str(pursuit_replay.get("name", "")), "draft_enabled": race_mode not in [4, 5, 7], "speed_kmh": speeds[0] * 3.6, "draft_reduction": _draft_drag_reduction(0), "draft_max": SCRATCH_DRAFT_MAX_DRAG_REDUCTION if race_mode in [0, 1] else DRAFT_MAX_DRAG_REDUCTION, "watts": watts, "gear": trainer_gear if connected else "—", "pc_control": not trainer_seen, "pc_energy_fraction": _pc_energy_fraction(), "pc_delivered_watts": pc_delivered_watts, "pc_power_limit_watts": pc_power_limit_watts, "heart_rate_bpm": trainer_heart_rate_bpm, "lap": mini(race_laps, int(distances[0] / LAP) + 1), "laps": race_laps, "seconds": shown_seconds, "position": order.find(0) + 1, "count": elimination_rules.remaining_count() if race_mode == 2 else rider_count, "leader_gap": PelotonState.gap_text(race_positions[0], peloton_info) if race_mode in [0,1] else (_hud_elimination_gap() if race_mode == 2 else _hud_leader_gap(order)), "order": order, "distances": physical_positions, "names": names, "gaps": gaps, "colours": colours, "notice": notice})

func _result_cell(value: String, tint: Color, bg: Color, width: float, right: bool = false, header: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 51 if not header else 43)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_content_margin_all(7)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	finish_table.add_child(panel)
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 20 if not header else 16)
	label.custom_minimum_size.x = width - 14
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = value
	label.add_theme_color_override("font_color", tint)
	panel.add_child(label)

func _refresh_fullscreen_results() -> void:
	if race_mode == 1:
		preload("res://points_presentation.gd").results(self)
		return
	if race_mode == 5:
		team_race.results(self)
		return
	if finish_results == null or finish_table == null:
		return
	var ordered: Array[int] = []
	for n in range(rider_count): ordered.append(n)
	ordered.sort_custom(func(a: int, b: int) -> bool: return _race_better(a, b))
	var player_place: int = ordered.find(0) + 1
	finish_heading.text = "TIJDRIT · %d m" % int(_race_length()) if race_mode == 7 else "ACHTERVOLGING · %d km" % int(_race_length() / 1000.0) if race_mode == 4 else ("Afvalling · Uitslag" if race_mode == 2 else "Scratch · Uitslag")
	if finish_subtitle != null:
		finish_subtitle.text = ("VLIEGENDE START · 125 M TUSSENTIJDEN" if time_trial_start_type == "flying" else "STAANDE START · 125 M TUSSENTIJDEN") if race_mode == 7 else "JOUW TIJD EN TEGENSTANDER" if race_mode == 4 else "OFFICIELE WEDSTRIJDRESULTATEN"
	if pursuit_save_box != null:
		pursuit_save_box.visible = race_mode == 4 and finish_times[0] >= 0.0
	finish_badge.text = "#%d / %d" % [player_place, rider_count]
	var complete: bool = _all_riders_finished()
	var status: String = "Alle renners gefinisht" if complete else "Nog renners onderweg - uitslag wordt automatisch aangevuld"
	var summary: String = "JOUW TIJD   %.2f s    •    GEM. VERMOGEN   %.0f W    •    PIEK   %.0f W\n%s" % [finish_times[0], player_power_integral / maxf(0.1, finish_times[0]), player_peak_watts, status]
	if race_mode == 0 and not scratch_rules.events.is_empty():
		var gains := 0
		for event in scratch_rules.events:
			if event.get("kind", "") == "gain":
				gains += 1
		summary += "\nRondewinsten: %d" % gains
	if strava_export_path != "":
		summary += "\nTCX opgeslagen in recordings-map"
	if fit_export_path != "":
		summary += "\nFIT indoor opgeslagen in Downloads"
	if fit_gps_export_path != "":
		summary += "\nFIT GPS opgeslagen in Downloads"
	if recording_message != "":
		summary += "\n" + recording_message
	finish_results.text = summary
	for child in finish_table.get_children():
		finish_table.remove_child(child)
		child.queue_free()
	var white := MenuSkin.INK
	var gold := MenuSkin.INK
	var header_bg := MenuSkin.PALE
	_result_cell("PL.", gold, header_bg, 54, false, true)
	_result_cell("RENNER", gold, header_bg, 205, false, true)
	_result_cell("EINDTIJD", gold, header_bg, 120, true, true)
	_result_cell("VERSCHIL", gold, header_bg, 110, true, true)
	_result_cell("RONDETIJDEN", gold, header_bg, 300, false, true)
	var leader_time: float = -1.0
	for index in ordered:
		if finish_times[index] >= 0.0:
			leader_time = finish_times[index]
			break
	var rider_colors: Array[Color] = [MenuSkin.INK, MenuSkin.INK, MenuSkin.INK, MenuSkin.INK]
	for rank in range(ordered.size()):
		var rider: int = ordered[rank]
		var row_bg: Color = MenuSkin.GOLD if rank == 0 else (MenuSkin.PAPER if rank % 2 == 0 else MenuSkin.IVORY)
		var display_time: String = "%.2f s" % finish_times[rider] if finish_times[rider] >= 0.0 else "Onderweg"
		if race_mode == 0 and scratch_rules.credits[rider] != 0:
			display_time += "  (%+d ronde)" % scratch_rules.credits[rider]
		var gap: String = "+%.2f s" % (finish_times[rider] - leader_time) if finish_times[rider] >= 0.0 and leader_time >= 0.0 else "--"
		if race_mode == 0 and not ordered.is_empty():
			var leader_credit: int = scratch_rules.credits[ordered[0]]
			if scratch_rules.credits[rider] != leader_credit:
				gap = "%d ronde(n)" % (leader_credit - scratch_rules.credits[rider])
		if rank == 0:
			gap = "SOLO" if race_mode == 7 else "WINNAAR"
		var laps_display := ""
		for lap in range(lap_times[rider].size()):
			if lap > 0:
				laps_display += "  |  "
			laps_display += "%d: %.2f" % [lap + 1, float(lap_times[rider][lap])]
		if laps_display == "":
			laps_display = "--"
		_result_cell("%d" % (rank + 1), gold if rank == 0 else white, row_bg, 54)
		_result_cell(_rider_name(rider), rider_colors[_profile(rider)], row_bg, 205)
		_result_cell(display_time, white, row_bg, 120, true)
		_result_cell(gap, gold if rank == 0 else white, row_bg, 110, true)
		_result_cell(laps_display, white, row_bg, 300)

func _rider_distance(rider: int, progress: float) -> float:
	if race_mode == 5:
		return progress + PURSUIT_START_M + float(rider / team_size) * LAP * 0.5
	return progress + PURSUIT_START_M + float(rider) * LAP * 0.5 if race_mode == 4 else (progress + PURSUIT_START_M if race_mode == 7 else progress)

func _prepare_pursuit(replay: Dictionary, cp: float) -> void:
	performance_context.clear()
	performance_id = Crypto.new().generate_random_bytes(12).hex_encode()
	performance_recorded = false
	pursuit_half_crossings = [[], []]
	pursuit_half_stats = [[], []]
	pursuit_energy.assign([0.0, 0.0])
	pursuit_crossing_energy.assign([0.0, 0.0])
	pursuit_replay = replay.duplicate(true)
	pursuit_trace.clear()
	pursuit_trace.append({"t": 0.0, "d": 0.0, "p": 0.0, "lane": LANES[0]})
	pursuit_saved_id = ""
	baseline_speed = 0.0
	boost_left = 0.0
	recovery_left = 0.0
	pursuit_pacer = PursuitPacer.new()
	if pursuit_replay.is_empty() and race_mode != 7:
		if not pursuit_opponent_config.is_empty():
			pursuit_pacer.wprime_j = float(pursuit_opponent_config.get("w_prime_j", 20000.0))
			pursuit_pacer.max_power_w = float(pursuit_opponent_config.get("max_power_w", 800.0))
		pursuit_pacer.difficulty_percent = pursuit_opponent_percent
		pursuit_pacer.prepare(self, _race_length(), cp, _rider_distance(1, 0.0), LANES[0])
		rider_names[1] = String(pursuit_opponent_config.get("name", "AI-tegenstander"))
	elif not pursuit_replay.is_empty():
		rider_names[1] = "Rit: " + String(pursuit_replay["name"]).left(24)
	if bikes.size() > 1 and bikes[1].get_child_count() > 1:
		bikes[1].get_child(1).text = _rider_name(1)
	if pursuit_save_box != null:
		pursuit_save_box.hide()
		pursuit_save_name.text = ""
		pursuit_save_button.disabled = false
		pursuit_save_status.text = "Bewaar deze rit om er later tegen te rijden."

func _pursuit_move_lanes(dt: float) -> Array[float]:
	var heights: Array[float] = [0.0, 0.0]
	var position: float = _rider_distance(0, distances[0])
	var previous: float = _at(position, lane_offsets[0]).y
	lane_offsets[0] = move_toward(lane_offsets[0], LANES[player_lane], LANE_CHANGE_MPS * dt)
	heights[0] = _at(position, lane_offsets[0]).y - previous
	# The opponent is always on the lowest line, including saved-ride playback.
	if race_mode == 4:
		lane_offsets[1] = LANES[0]
		ai_lane_targets[1] = LANES[0]
	return heights

func _record_pursuit_sample(seconds: float, distance: float, force: bool = false) -> void:
	if not force and seconds - float(pursuit_trace[-1]["t"]) < 0.2:
		return
	var sample := {"t": seconds, "d": distance, "p": maxf(0.0, watts), "lane": lane_offsets[0]}
	if seconds > float(pursuit_trace[-1]["t"]) + 0.000001:
		pursuit_trace.append(sample)

func _register_pursuit_half_crossings(rider: int, previous: float, step: float, dt: float, power: float) -> void:
	if step <= 0.0:
		pursuit_energy[rider] += power * dt
		return
	var next: int = pursuit_half_crossings[rider].size() + 1
	while next <= race_laps * 2 and float(next) * LAP * 0.5 <= previous + step + 0.000001:
		var line_distance: float = float(next) * LAP * 0.5
		var crossing: float
		if rider == 1 and not pursuit_replay.is_empty():
			crossing = PursuitRecords.time_at_distance(pursuit_replay, line_distance)
		else:
			crossing = clock - dt + dt * clampf((line_distance - previous) / step, 0.0, 1.0)
		var prior: float = float(pursuit_half_crossings[rider][-1]) if not pursuit_half_crossings[rider].is_empty() else 0.0
		var elapsed: float = maxf(0.000001, crossing - prior)
		var energy_at_line: float = pursuit_energy[rider] + power * clampf(crossing - (clock - dt), 0.0, dt)
		var segment_energy: float = energy_at_line - pursuit_crossing_energy[rider]
		if rider == 1 and not pursuit_replay.is_empty():
			segment_energy = _pursuit_replay_energy(prior, crossing)
		pursuit_crossing_energy[rider] = energy_at_line
		pursuit_half_stats[rider].append({"kmh": LAP * 0.5 / elapsed * 3.6, "watts": segment_energy / elapsed})
		pursuit_half_crossings[rider].append(crossing)
		next += 1
	var active_dt: float = dt
	if previous + step >= _race_length():
		active_dt *= clampf((_race_length() - previous) / step, 0.0, 1.0)
	pursuit_energy[rider] += power * active_dt

func _pursuit_replay_energy(start: float, end: float) -> float:
	# Integrate the saved piecewise-linear wattage, including partial samples.
	var energy := 0.0
	var samples: Array = pursuit_replay["samples"]
	for j in range(1, samples.size()):
		var a: Dictionary = samples[j - 1]
		var z: Dictionary = samples[j]
		var left: float = maxf(start, float(a["t"]))
		var right: float = minf(end, float(z["t"]))
		if right <= left:
			continue
		var span: float = float(z["t"]) - float(a["t"])
		var pa: float = lerpf(float(a["p"]), float(z["p"]), (left - float(a["t"])) / span)
		var pb: float = lerpf(float(a["p"]), float(z["p"]), (right - float(a["t"])) / span)
		energy += (pa + pb) * 0.5 * (right - left)
		if right >= end:
			break
	return energy

func _update_pursuit(dt: float) -> void:
	if dt <= 0.0:
		return
	boost_left = 0.0
	recovery_left = 0.0
	var previous_lanes: Array[float] = lane_offsets.duplicate()
	var lateral_height: Array[float] = _pursuit_move_lanes(dt)
	draft_strengths.fill(0.0)
	draft_leaders.fill(-1)
	var player_actual_power: float = _pc_power(dt)
	var new_finisher := false
	for i in range(1 if race_mode == 7 else 2):
		if finish_times[i] >= 0.0:
			continue
		var previous: float = distances[i]
		var power: float = player_actual_power if i == 0 else 0.0
		var step: float
		var end_time: float = clock
		if i == 1 and not pursuit_replay.is_empty():
			var sample: Dictionary = PursuitRecords.at_time(pursuit_replay, clock)
			step = maxf(0.0, float(sample["d"]) - previous)
			speeds[i] = float(sample["speed"]) * _path_metric(_rider_distance(i, float(sample["d"])), LANES[0])
			power = sample["p"]
			while lap_times[i].size() < race_laps and float(lap_times[i].size() + 1) * LAP <= float(sample["d"]) + 0.00001:
				var crossing: float = PursuitRecords.time_at_distance(pursuit_replay, float(lap_times[i].size() + 1) * LAP)
				lap_times[i].append(crossing - last_lap_crossing[i])
				last_lap_crossing[i] = crossing
			if clock >= float(pursuit_replay["time_s"]):
				end_time = float(pursuit_replay["time_s"])
		else:
			if i == 1:
				power = pursuit_pacer.power(dt)
			var result: Dictionary = PursuitPacer.advance(self, previous, speeds[i], power, dt, lane_offsets[i], _rider_distance(i, 0.0), lateral_height[i], absf(lane_offsets[i] - previous_lanes[i]))
			speeds[i] = result["speed"]
			step = result["step"]
			_register_lap_crossings(i, previous, step, dt)
			if previous + step >= _race_length():
				end_time = clock - dt + dt * (_race_length() - previous) / maxf(step, 0.000001)
		if i > 0: ai_power_w[i] = power
		_register_pursuit_half_crossings(i, previous, step, dt, power)
		distances[i] = minf(_race_length(), previous + step)
		var crossed: bool = distances[i] >= _race_length() - 0.000001
		if crossed:
			distances[i] = _race_length()
		if i == 0:
			baseline_speed = speeds[i]
			player_power_integral += power * (maxf(0.0, end_time - (clock - dt)) if crossed else dt)
			player_peak_watts = maxf(player_peak_watts, power)
			player_speed_peak_kmh = maxf(player_speed_peak_kmh, speeds[i] * 3.6)
			if player_samples.is_empty() or distances[i] - player_samples[-1].x >= 2.5 or crossed:
				player_samples.append(Vector2(distances[i], power))
			_record_pursuit_sample(end_time if crossed else clock, distances[i], crossed)
			if not trainer_seen:
				_capture_demo_fit_sample()
		else:
			ai_power_w[i] = power
			ai_energy_j[i] = pursuit_pacer.reserve_j
			tt_effort_remaining = pursuit_pacer.reserve_j / PursuitPacer.WPRIME_J
		if crossed:
			finish_times[i] = end_time
			coast_distances[i] = _race_length()
			coast_speeds[i] = speeds[i]
			new_finisher = true
	if new_finisher:
		_take_finish_photo(_winner_index())
	if finish_times[0] >= 0.0 and not finished:
		if race_mode == 7:
			time_trial_records.add(int(_race_length()), finish_times[0], pursuit_half_crossings[0], time_trial_start_type)
		else:
			_register_performance()
		finished = true
		running = false
		finish_elapsed = 0.0
		_save_recording("finish")

func _save_pursuit_ride() -> void:
	if race_mode not in [4, 5] or finish_times[0] < 0.0 or not pursuit_saved_id.is_empty():
		return
	var metadata := performance_context.duplicate(true)
	metadata["performance_id"] = performance_context.get("id", "")
	var result: Dictionary = (team_library if race_mode == 5 else pursuit_library).save(pursuit_save_name.text, int(_race_length()), finish_times[0], pursuit_trace, metadata)
	if result.has("error"):
		pursuit_save_status.text = result["error"]
		return
	pursuit_saved_id = result["id"]
	pursuit_save_status.text = "Opgeslagen: %s · beschikbaar bij deze afstand als tegenstander." % result["name"]
	pursuit_save_button.disabled = true
	if setup_panel != null:
		setup_panel.get("team_options" if race_mode == 5 else "pursuit_options").refresh_rides()

func _style_finish_button(button: Button, fill: Color, ink: Color, outline: Color = Color.TRANSPARENT) -> void:
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(11)
	style.set_content_margin_all(9)
	style.border_color = outline
	style.set_border_width_all(2 if outline.a > 0.0 else 0)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.18)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)

func _on_strava_status(message: String) -> void:
	recording_message = message
	if finish_overlay != null and finish_overlay.visible:
		_refresh_fullscreen_results()

func _on_strava_activity_created(activity_id: String) -> void:
	strava_activity_url = "https://www.strava.com/activities/" + activity_id
	var done := ConfirmationDialog.new()
	done.title = "Strava-upload geslaagd"
	done.dialog_text = "Je rit is gepubliceerd als virtuele activiteit.\n\n" + strava_desired_title + "\n\n" + ("Screenshot opgeslagen in Downloads; voeg die handmatig toe op Strava.\n\n" if not strava_screenshot_path.is_empty() else "") + "Open de activiteit in Strava?"
	done.ok_button_text = "Open in Strava"
	done.cancel_button_text = "Sluiten"
	add_child(done)
	done.confirmed.connect(func(): OS.shell_open(strava_activity_url))
	done.confirmed.connect(done.queue_free)
	done.canceled.connect(done.queue_free)
	done.popup_centered(Vector2i(650, 290))

func _strava_activity_title() -> String:
	for mode in preload("res://race_menu.gd").MODES:
		if int(mode["race_id"]) == race_mode:
			return "Velodrome - " + String(mode["title"])
	return "Velodrome"

func _strava_activity_description() -> String:
	if race_mode == 7:
		var lines: PackedStringArray = []
		if time_trial_start_type == "flying": lines.append("Vliegende start · 1 aanloopronde")
		lines.append("Tijd: %.3f s" % finish_times[0] if finish_times[0] >= 0.0 else "Tijdrit nog niet voltooid.")
		if not lap_times[0].is_empty():
			lines.append("Rondetijden (250 m):")
			for lap in range(lap_times[0].size()):
				lines.append("Ronde %d: %.3f s" % [lap + 1, float(lap_times[0][lap])])
		return "\n".join(lines)
	if race_mode == 5:
		if team_race.times[0] < 0.0 or team_race.times[1] < 0.0:
			return "Uitslag nog niet definitief."
		return "Uitslag: %d/2" % (2 if team_race.better(1, 0) else 1)
	if not _all_riders_finished():
		return "Uitslag nog niet definitief."
	var order: Array[int] = []
	for rider in range(rider_count): order.append(rider)
	order.sort_custom(func(a: int, b: int) -> bool: return _race_better(a, b))
	var description := "Uitslag: %d/%d" % [order.find(0) + 1, rider_count]
	if race_mode == 1:
		description += ", %d punten" % points_rules.points[0]
	return description

func _export_to_strava() -> void:
	strava_desired_title = _strava_activity_title()
	strava_desired_description = _strava_activity_description()
	# Use a plain Window rather than ConfirmationDialog internals: Godot 4 has no get_vbox().
	var dialog := Window.new()
	dialog.title = "Export naar Strava"
	dialog.size = Vector2i(730, 510)
	dialog.min_size = Vector2i(660, 450)
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	dialog.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var instruction := Label.new()
	instruction.text = "Kies een activiteitstitel. Een optionele uitslagscreenshot wordt opgeslagen in Downloads en kan handmatig op Strava worden toegevoegd."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)
	var title_label := Label.new()
	title_label.text = "Naam van de Strava-activiteit"
	content.add_child(title_label)
	var title_input := LineEdit.new()
	title_input.text = strava_desired_title
	content.add_child(title_input)
	var description_label := Label.new()
	description_label.text = "Beschrijving"
	content.add_child(description_label)
	var description_preview := RichTextLabel.new()
	description_preview.text = strava_desired_description
	description_preview.custom_minimum_size.y = 115
	description_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description_preview)
	var picture_check := CheckBox.new()
	picture_check.text = "Sla uitslagenscherm op als PNG in Downloads"
	picture_check.button_pressed = strava_save_screenshot
	content.add_child(picture_check)
	if ride_records.size() < 2:
		var demo_label := Label.new()
		demo_label.text = "LET OP: DEMO met GESIMULEERDE waarden. Alleen gebruiken als privetest."
		demo_label.add_theme_color_override("font_color", Color("ffb448"))
		demo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(demo_label)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(space)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)
	var cancel_button := Button.new()
	cancel_button.text = "Annuleren"
	cancel_button.custom_minimum_size = Vector2(125, 38)
	buttons.add_child(cancel_button)
	var upload_button := Button.new()
	upload_button.text = "Upload rit"
	upload_button.custom_minimum_size = Vector2(145, 38)
	buttons.add_child(upload_button)
	cancel_button.pressed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	upload_button.pressed.connect(func():
		strava_desired_title = title_input.text.strip_edges()
		if strava_desired_title.is_empty():
			strava_desired_title = _strava_activity_title()
		strava_save_screenshot = picture_check.button_pressed
		dialog.hide()
		_start_strava_upload_with_capture()
		dialog.queue_free()
	)
	dialog.popup_centered()

func _start_strava_upload_with_capture() -> void:
	strava_screenshot_path = ""
	if strava_save_screenshot:
		# Save the results view before opening any other popups.
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
			var shot_name: String = "Velodrome_250_uitslag_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
			var screenshot_path: String = downloads.path_join(shot_name)
			if image.save_png(screenshot_path) == OK:
				strava_screenshot_path = screenshot_path
	_start_strava_upload()

func _player_activity_samples() -> Array[Dictionary]:
	# Never use pursuit_trace: in team pursuit that is the leader's replay data.
	# ride_records and demo_fit_records contain only rider 0's measurements.
	return ride_records if ride_records.size() >= 2 else demo_fit_records

func _start_strava_upload() -> void:
	# Strava needs FIT bytes, not a permanent copy in Windows Downloads.
	# Only the explicit EXPORT .FIT button writes to Downloads.
	var is_demo: bool = ride_records.size() < 2
	var samples: Array[Dictionary] = _player_activity_samples()
	if samples.size() < 2:
		_on_strava_status("Strava: onvoldoende ritmetingen om te uploaden.")
		return
	var epoch: int = ride_start_unix
	if epoch <= 0:
		epoch = int(Time.get_unix_time_from_system() - float(samples[-1]["time_s"]))
	var payload: PackedByteArray = preload("res://fit_export.gd").build(samples, epoch, true)
	if payload.is_empty():
		_on_strava_status("Strava: FIT-opbouw mislukt.")
		return
	var temp_path := "user://strava_upload_temp.fit"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_on_strava_status("Strava: tijdelijk FIT-bestand kon niet worden gemaakt.")
		return
	file.store_buffer(payload)
	file.close()
	strava_client.call("begin_export", ProjectSettings.globalize_path(temp_path), strava_desired_title, strava_desired_description)

func _register_performance() -> void:
	if race_mode not in [4, 5] or performance_recorded or finish_times[0] < 0.0:
		return
	var proof := {"version": PursuitRecords.VERSION, "physics": PursuitRecords.PHYSICS, "name": "Voltooide prestatie", "time_s": finish_times[0], "distance_m": int(_race_length()), "samples": pursuit_trace}
	if not PursuitRecords.valid(proof): return
	if performance_context.is_empty():
		if performance_id.is_empty(): performance_id = Crypto.new().generate_random_bytes(12).hex_encode()
		var player: String = player_display_name.strip_edges().left(64)
		performance_context = {"id": performance_id, "mode": race_mode, "distance_m": int(_race_length()), "team_size": team_size if race_mode == 5 else 0, "seconds": finish_times[0], "player_name": player if not player.is_empty() else "Speler", "finished_at": Time.get_unix_time_from_system(), "finished_local": Time.get_datetime_string_from_system(false, true), "legacy": false}
	performance_recorded = performance_records.add(performance_context)
	if not performance_recorded and pursuit_save_status != null:
		pursuit_save_status.text = performance_records.last_error


func _lap_credits() -> Array[int]:
	return points_rules.credits if race_mode == 1 else scratch_rules.credits

func _race_positions() -> Array[float]:
	return PelotonState.race_positions(distances, _lap_credits()) if race_mode in [0,1] else distances.duplicate()

func _physical_order(positions: Array[float]) -> Array[int]:
	var order: Array[int] = []
	for i in range(positions.size()): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return a < b if positions[a] == positions[b] else positions[a] > positions[b])
	return order

func _points_order() -> Array[int]:
	var order: Array[int] = []
	for i in range(rider_count): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return points_rules.better(a,b,distances))
	return order

func _update_bunch_presentation() -> void:
	# Scratch/points/elimination start with a neutral lap. Show the full rider
	# card there too, instead of falling back to a name-only Label3D.
	var active: bool = race_mode in [0, 1, 2] and start_state in ["NEUTRAL", "RACING"]
	if active: peloton_info = peloton_state.sample(distances, _lap_credits(), finish_times)
	if peloton_markers != null: peloton_markers.update_bunch(self, peloton_info, active)
	for i in range(bikes.size()):
		for child in bikes[i].get_children():
			if child is Label3D: child.visible = not active and _rider_label_visible(i)
	for i in range(rider_energy_badges.size()):
		var reserve: float = (pc_energy_model.wprime[1] / maxf(1.0, pc_energy_model.wmax[1]) if pc_energy_model.initialized and not trainer_seen else -1.0) if i == 0 else (x_ai.wprime[i]/maxf(1.,x_ai.wmax[i]) if x_ai.initialized else -1.0)
		var power: float = (watts if trainer_seen else pc_delivered_watts) if i == 0 else ai_power_w[i]
		rider_energy_badges[i].show_rider(power, reserve, bikes[i].global_position, active and finish_times[i] < 0.0 and _rider_label_visible(i), points_rules.points[i] if race_mode == 1 else 0, race_mode == 1, _compact_rider_name(_rider_name(i)))

func _announce_race_event(message: String, player_event: bool = true) -> void:
	if not player_event and clock < race_event_until: return
	race_event_message = message
	race_event_until = clock+(10.0 if player_event else 5.0)
	if not player_event or DisplayServer.get_name() == "headless": return
	if race_event_sound == null:
		race_event_sound = AudioStreamPlayer.new()
		add_child(race_event_sound)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var samples := PackedByteArray()
		samples.resize(11025*2)
		for i in range(11025):
			var t: float = float(i)/22050.0
			samples.encode_s16(i*2, int(12000.0*sin(TAU*880.0*t)*exp(-7.0*t)))
		stream.data = samples
		race_event_sound.stream = stream
	race_event_sound.play()


static func _compact_rider_name(full_name: String) -> String:
	var name := full_name.strip_edges()
	var split_at := name.find(" ")
	if split_at <= 0:
		return name
	var surname := name.substr(split_at + 1).strip_edges()
	if surname.is_empty():
		return name
	return "%s. %s" % [name.substr(0, 1).to_upper(), surname]

func _cycle_rider_names() -> void:
	rider_name_mode = (rider_name_mode + 1) % 3
	name_view_notice_until = _now_s() + 3.0
	_update_bunch_presentation()

func _rider_label_visible(index: int) -> bool:
	# The player already has name/power in the HUD, in every V mode.
	if index == 0 or rider_name_mode == 2: return false
	if broadcast_intro != null and (broadcast_intro.active or broadcast_intro.holding_chase): return false
	if rider_name_mode == 1: return true
	var radius: float = 10.0 if crowded_labels.get(index, false) else 8.0
	var neighbours := 0
	for other in range(bikes.size()):
		if other == index or finish_times[other] >= 0.0: continue
		if bikes[index].position.distance_squared_to(bikes[other].position) < radius * radius:
			neighbours += 1
	crowded_labels[index] = neighbours >= 2
	# World-space proximity includes lapped riders in the same physical bunch.
	return not crowded_labels[index] and (camera == null or camera.position.distance_to(bikes[index].position) < 40.0)

func available_pursuit_riders() -> Array[Dictionary]:
	_load_rider_config()
	var ids: Array[int] = []
	# All fifteen AI slots supported by the largest race, plus personal extra slots.
	for i in range(1, 16): ids.append(i)
	if rider_config_ready:
		for section in rider_config.get_sections():
			if section.begins_with("rider_") and section.substr(6).is_valid_int():
				var id := int(section.substr(6))
				if id > 0 and id not in ids: ids.append(id)
	ids.sort()
	var result: Array[Dictionary] = []
	for id in ids:
		var entry := _configured_rider(id, 1 + ((id - 1) % 3))
		result.append(entry)
	return result

func _record_ai_performances() -> void:
	if race_mode in [2, 5]: return # Elimination exits and team results are not individual distance records.
	if race_mode == 4 and not pursuit_replay.is_empty(): return
	for i in range(1, mini(rider_count, rider_identities.size())):
		var power: float = ai_power_w[i] if i < ai_power_w.size() else 0.0
		ai_observed_peak[i] = maxf(ai_observed_peak[i], power)
		if finish_times[i] >= 0.0 and not ai_recorded[i]:
			ai_recorded[i] = true
			var identity: Dictionary = rider_identities[i]
			var parameters := {"cp_w":pursuit_pacer.cp_w if race_mode == 4 else float(identity.get("cp_w",0.0)), "max_power_w":float(identity.get("max_power_w",0.0)), "w_prime_j":float(identity.get("w_prime_j",0.0))}
			ai_personal_records.record(String(identity.get("id", "")), race_mode, roundi(_race_length()), ai_difficulty if race_mode in [0,1] else pursuit_opponent_percent, finish_times[i], ai_observed_peak[i], rider_forms[i], parameters)

func _update_elimination_jury(dt: float) -> void:
	var rear: Array[float] = []
	for i in range(rider_count): rear.append(distances[i] - REAR_TRAILING_EDGE_M)
	var event: Dictionary = elimination_rules.sample(rear, clock - dt, dt)
	if event.is_empty(): return
	var loser: int = int(event.get("eliminated_id", -1))
	if loser < 0:
		elimination_notice.text = "FOTOFINISH · JURYBESLISSING"
		elimination_notice_until = clock + 4.0
		return
	finish_times[loser] = clock
	coast_distances[loser] = distances[loser]
	coast_speeds[loser] = speeds[loser]
	elimination_exit[loser] = {"stage": 0, "start_d": coast_distances[loser], "position": Vector3.ZERO, "target": _elimination_box_target(loser), "heading": Vector3.FORWARD}
	elimination_notice.text = "AFGEVALLEN · %s" % _rider_name(loser).to_upper()
	elimination_notice_until = clock + 4.0
	_take_elimination_photo(loser, float(event.get("line_m", 0.0)))
	if loser == 0 and not finished:
		finished = true
		finish_elapsed = 0.0
		_save_recording("elimination")

func _take_elimination_photo(rider: int, line_m: float) -> void:
	if finish_photo_viewport == null: return
	var spot: Vector3 = _at(line_m - 3.4, FINISH_PHOTO_INFIELD_OFFSET)
	spot.y = 1.5
	finish_photo_camera.global_position = spot
	finish_photo_camera.look_at(_at(line_m + 0.6, lane_offsets[rider]) + Vector3.UP * 0.65, Vector3.UP)
	finish_photo_caption.text = "AFVALLING · ACHTERWIEL · %s" % _rider_name(rider).to_upper()
	finish_photo_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not finish_photo_capture_pending:
		finish_photo_capture_pending = true
		RenderingServer.frame_post_draw.connect(_grab_finish_photo, CONNECT_ONE_SHOT)

func _elimination_box_target(rider: int) -> Vector3:
	# The six cabins belong to countries, not individual riders.
	# Without a matching cabin, ride PAST the complete box row and stop on
	# the grey access zone. Never substitute an unrelated country's cabin.
	var row: Node = arena.find_child("Rennersboxen", true, false) if arena != null else null
	var roster: Dictionary = RaceCountries.roster(self)
	var countries: Array = roster.get("start_list", [])
	var country: String = String(countries[rider]) if rider < countries.size() else ""
	var box_index := -1
	if row != null:
		var assigned: Array = row.get("assigned_countries")
		if assigned.has(country):
			box_index = assigned.find(country)
	var slot := 0
	for key in elimination_exit:
		var other_target: Vector3 = elimination_exit[key].get("target", Vector3.ZERO)
		if box_index < 0:
			# The box row spans z=-25..25. All unassigned riders stop BEYOND
			# its northern end, with independent spaces on the grey zone.
			if other_target.z >= 29.0:
				slot += 1
		elif absf(other_target.z - (-25.0 + 10.0 * float(box_index))) < 3.0:
			slot += 1
	if box_index < 0:
		return Vector3(-14.1, 0.15, 30.0 + 2.0 * float(slot))
	return Vector3(-14.1 - 0.45 * float(slot % 2), 0.15, -25.0 + 10.0 * float(box_index) + 0.85 * float(slot / 2))

func _update_eliminated_exit(rider: int, dt: float) -> void:
	var route: Dictionary = elimination_exit[rider]
	var stage: int = int(route["stage"])
	if stage == 3:
		coast_speeds[rider] = 0.0
		return
	if stage == 0:
		var travelled: float = coast_distances[rider] - float(route["start_d"])
		# Stay clear of the still-racing bunch before descending toward the apron.
		if travelled > 25.0:
			lane_offsets[rider] = move_toward(lane_offsets[rider], LANES[0], LANE_CHANGE_MPS * dt)
		# Keep rolling until the gate halfway along the opposite straight.
		var target_coast_speed: float = 5.0 if travelled > 62.0 else (8.0 if travelled > 28.0 else 13.0)
		var braking: float = 2.2 if travelled > 62.0 else 1.1
		coast_speeds[rider] = move_toward(coast_speeds[rider], target_coast_speed, braking * dt)
		coast_distances[rider] += coast_speeds[rider] * dt / _path_metric(_rider_distance(rider, coast_distances[rider]), lane_offsets[rider])
		if travelled >= 75.0 and absf(fposmod(coast_distances[rider], LAP) - 90.8) <= 0.4:
			route["stage"] = 1
			route["position"] = _at(_rider_distance(rider, coast_distances[rider]) - FRONT_WHEEL_TIP_M, lane_offsets[rider])
			route["heading"] = _direction(_rider_distance(rider, coast_distances[rider]), lane_offsets[rider])
	else:
		# The gate at z=0 is a real gap in the inner boarding. Once inside,
		# travel along the infield access corridor to the appropriate country cabin.
		var current: Vector3 = route["position"]
		var destination: Vector3 = Vector3(-14.1, 0.15, 0.0) if stage == 1 else Vector3(route["target"])
		var vector: Vector3 = destination - current
		vector.y = 0.0
		var speed: float = minf(3.1, maxf(0.0, vector.length() * 1.5))
		coast_speeds[rider] = speed
		if vector.length() > 0.01:
			route["heading"] = vector.normalized()
			current = current.move_toward(destination, speed * dt)
			current.y = 0.15
			route["position"] = current
		if current.distance_to(destination) < 0.12:
			if stage == 1: route["stage"] = 2
			else:
				route["stage"] = 3
				coast_speeds[rider] = 0.0
	elimination_exit[rider] = route

func _clear_elimination_feedback() -> void:
	elimination_notice_until = -1.0
	if elimination_notice != null:
		elimination_notice.text = ""
		elimination_notice.hide()

func _hud_elimination_gap() -> String:
	if finish_times[0] >= 0.0: return "Afgevallen" if elimination_rules.eliminated.has(0) else "Finish"
	var opponents: Array[int] = []
	for i in range(1, rider_count):
		if finish_times[i] < 0.0: opponents.append(i)
	if opponents.is_empty(): return "—"
	opponents.sort_custom(func(a: int, b: int) -> bool: return distances[a] < distances[b])
	# When the player is last, show the negative gap to the next active rider.
	# Eliminated/coasting riders never become the reference.
	return "%+.1f m" % (distances[0] - distances[opponents[0]])

func available_startlist_riders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Array[String] = []
	for entry in available_pursuit_riders():
		if String(entry.id) not in seen:
			result.append(entry);seen.append(String(entry.id))
	# Keep reserve choices even for a sixteen-rider race. Personal extra slots are preserved.
	for slot in range(16, 64):
		if result.size() >= 24: break
		var entry := _configured_rider(slot,1+((slot-1)%3))
		if String(entry.id) not in seen:
			result.append(entry);seen.append(String(entry.id))
	for entry in result:
		if not entry.jersey.has("country_kit"): entry.jersey["country_kit"] = entry.country
	return result
