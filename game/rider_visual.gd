extends Node3D
# Integrated Blender rig + skinned meshes. Contains both bicycle and cyclist.
const RIDER_SCENE: PackedScene = preload("res://assets/riders/velodrome_rider.glb")
const PURSUIT_SCENE: PackedScene = preload("res://assets/riders/velodrome_pursuit.glb")
const BASE_CADENCE: float = 60.0
const BLEND_SECONDS: float = 0.25
const POSES: Array[String] = ["cruise", "sprint_seated", "sprint_standing", "victory"]
const VICTORY_POSE := 3
const VICTORY_SECONDS := 6.0
# beta.16.16: printable areas on the skinsuit. Any PNG works; transparent pixels = no print.
const DECAL_SLOTS: Array[String] = ["back", "chest", "thigh_L", "thigh_R"]
const DECAL_DIR := "res://assets/riders/decals/"
# Temporary Belgian national-kit preview: rider index 0 only. Set false to disable.
const BELGIUM_KIT_PREVIEW := true
const BELGIUM_KIT_DIR := "res://assets/riders/national_kits/belgium/"
# Index order: player, drafter, sprinter, attacker.
const SHAPE_KEYS: Array[String] = ["ShoulderWidth", "TorsoMass", "HipWidth", "ThighMass", "CalfMass", "ArmMass"]
const RIDER_SHAPES: Array = [
	[0.00, 0.00, 0.00, 0.00, 0.00, 0.00],
	[-0.24, -0.18, -0.15, -0.20, -0.18, -0.12],
	[0.75, 0.60, 0.23, 0.90, 0.75, 0.57],
	[-0.52, -0.48, -0.38, -0.48, -0.45, -0.38],
]


var rig_scene: Node3D
var animator: AnimationPlayer
var resolved_poses: Array[StringName] = []
var current_pose: int = -1
var standing_active: bool = false
var standing_amount: float = 0.0
var cadence_phase: float = 0.0
var stopped: bool = false
var victory_started: bool = false
var victory_left: float = 0.0
var body_mesh: MeshInstance3D

func _ready() -> void:
	rig_scene = (PURSUIT_SCENE if bool(get_meta("pursuit_mode", false)) else RIDER_SCENE).instantiate()
	rig_scene.name = "BlenderRiderAndBike"
	add_child(rig_scene)
	animator = _find_animation_player(rig_scene)
	if animator == null:
		push_error("Velodrome rider: geen AnimationPlayer gevonden in GLB")
		return
	# Godot may namespace glTF animation names as 'Library/clip'.
	# Resolve the actual imported names, rather than assuming bare clip names.
	var imported: PackedStringArray = animator.get_animation_list()
	print("Velodrome rider - geimporteerde animaties: ", imported)
	for pose_name in POSES:
		var found: StringName = _resolve_animation(pose_name, imported)
		if found == &"":
			push_error("Velodrome rider: clip ontbreekt: " + pose_name + "; beschikbaar: " + str(imported))
			return
		resolved_poses.append(found)
		var clip: Animation = animator.get_animation(found)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR
	# Drive the imported clip explicitly from cadence phase.
	# This avoids pause/play state races and ensures the bones update each frame.
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_play_pose(0)
	# A MANUAL AnimationPlayer must be advanced explicitly: seek() alone
	# may move the playhead without evaluating all animated skeleton tracks.
	animator.advance(0.0)
	var rider_index: int = int(get_meta("rider_index", 0))
	_apply_rider_profile(rider_index)
	_apply_default_decals(rider_index)
	if BELGIUM_KIT_PREVIEW and rider_index == 0:
		_apply_belgium_kit_preview()

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _resolve_animation(requested: String, imported: PackedStringArray) -> StringName:
	# Support Blender exports both with and without the _loop suffix,
	# including names prefixed by an AnimationLibrary in Godot.
	var candidates: Array[String] = [requested + "_loop", requested]
	for candidate in candidates:
		for label in imported:
			if label == candidate:
				return StringName(label)
		for label in imported:
			if label.ends_with("/" + candidate) or label.ends_with("|" + candidate) or label.ends_with(":" + candidate):
				return StringName(label)
	return &""

func _apply_rider_profile(index: int) -> void:
	index = clampi(index, 0, 3)
	var body: MeshInstance3D = rig_scene.find_child("Rider", true, false) as MeshInstance3D
	if body == null or body.mesh == null:
		push_warning("Velodrome rider: Rider mesh niet gevonden; geen profiel")
		return
	# Morph the body mesh alone: keep the existing rig, pedals and hands aligned.
	for shape_index in range(body.mesh.get_blend_shape_count()):
		var shape_name: String = String(body.mesh.get_blend_shape_name(shape_index))
		var profile_key: int = SHAPE_KEYS.find(shape_name)
		if profile_key >= 0:
			body.set_blend_shape_value(shape_index, float(RIDER_SHAPES[index][profile_key]))
	# Independent material overrides on every instance. Neither mutate shared
	# GLB materials nor tint skin, chain, tires, visor or other bike parts.
	var palettes: Array[Dictionary] = [
		{"suit": Color("eac736"), "accent": Color("fff2a9"), "helmet": Color("eac736"), "helmet2": Color("fff3bd"), "panel": Color("252934"), "glove": Color("292c36"), "shoe": Color("eeeeee")},
		{"suit": Color("35ad77"), "accent": Color("ccf4dc"), "helmet": Color("219b68"), "helmet2": Color("b0eacd"), "panel": Color("26392d"), "glove": Color("23312a"), "shoe": Color("f1f1eb")},
		{"suit": Color("268cd3"), "accent": Color("8cd5ff"), "helmet": Color("187ec2"), "helmet2": Color("adddff"), "panel": Color("172a4b"), "glove": Color("18263e"), "shoe": Color("f3f4f6")},
		{"suit": Color("df504b"), "accent": Color("ffc9a1"), "helmet": Color("d7433d"), "helmet2": Color("ffac8a"), "panel": Color("382629"), "glove": Color("30252a"), "shoe": Color("eeeeee")},
	]
	_apply_palette_to_mesh(body, palettes[index])
	print("Velodrome rider: profiel ", index, " morphs ", RIDER_SHAPES[index])

func _apply_palette_to_mesh(mesh_node: MeshInstance3D, palette: Dictionary) -> void:
	if mesh_node.mesh == null:
		return
	for surface_index in range(mesh_node.mesh.get_surface_count()):
		var material: Material = mesh_node.mesh.surface_get_material(surface_index)
		if not material is StandardMaterial3D:
			continue
		var src: StandardMaterial3D = material as StandardMaterial3D
		var material_name: String = src.resource_name.to_lower()
		# Some glTF importers append suffixes; require a material name prefix.
		var category: String = ""
		for k in palette.keys():
			if material_name == String(k) or material_name.begins_with(String(k) + ".") or material_name.begins_with(String(k) + "_"):
				category = String(k)
				break
		if category.is_empty():
			continue
		var colored: StandardMaterial3D = src.duplicate() as StandardMaterial3D
		colored.albedo_color = palette[category]
		mesh_node.set_surface_override_material(surface_index, colored)

# Preview only: keep normal rider shapes, change suit colors and decals on this instance.
# The 2D decals cover the central chest and back, not sleeves or side panels.
func _apply_belgium_kit_preview() -> void:
	if body_mesh == null:
		body_mesh = rig_scene.find_child("Rider", true, false) as MeshInstance3D
	if body_mesh == null:
		return
	_apply_palette_to_mesh(body_mesh, {
		"suit": Color("a9d9f4"),
		"accent": Color("a9d9f4"),
		"panel": Color("181a1e"),
	})
	var chest_path := BELGIUM_KIT_DIR + "chest.png"
	var back_path := BELGIUM_KIT_DIR + "back.png"
	if ResourceLoader.exists(chest_path):
		set_decal("chest", load(chest_path))
	if ResourceLoader.exists(back_path):
		set_decal("back", load(back_path))
	# No commercial thigh decal on the national-kit preview.
	set_decal("thighs", null)

# ---------------------------------------------------------------- decals (logo / number)
func _apply_default_decals(index: int) -> void:
	# Defaults: race number on the back (1..4), logo on chest and thighs.
	# Replace the PNGs in assets/riders/decals/ or call set_decal() at runtime.
	var number_path := DECAL_DIR + "decal_back_%d.png" % (clampi(index, 0, 3) + 1)
	if ResourceLoader.exists(number_path):
		set_decal("back", load(number_path))
	if ResourceLoader.exists(DECAL_DIR + "decal_chest.png"):
		set_decal("chest", load(DECAL_DIR + "decal_chest.png"))
	if ResourceLoader.exists(DECAL_DIR + "decal_thigh.png"):
		set_decal("thighs", load(DECAL_DIR + "decal_thigh.png"))

## slot: "back", "chest", "thigh_L", "thigh_R" or "thighs" (both). texture = null removes the print.
## The image is stretched over the print area (back 25x25 cm, chest 24x12 cm, thighs 22x8.5 cm).
func set_decal(slot: String, texture: Texture2D) -> void:
	if slot == "thighs":
		set_decal("thigh_L", texture)
		set_decal("thigh_R", texture)
		return
	if body_mesh == null:
		body_mesh = rig_scene.find_child("Rider", true, false) as MeshInstance3D
	if body_mesh == null or body_mesh.mesh == null:
		return
	for surface_index in range(body_mesh.mesh.get_surface_count()):
		var src: Material = body_mesh.mesh.surface_get_material(surface_index)
		if src == null or not src.resource_name.to_lower().begins_with("decal_" + slot.to_lower()):
			continue
		var m := StandardMaterial3D.new()
		m.resource_name = src.resource_name
		m.roughness = 0.6
		m.texture_repeat = false
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		if texture == null:
			m.albedo_color = Color(1, 1, 1, 0)
		else:
			m.albedo_texture = texture
		body_mesh.set_surface_override_material(surface_index, m)

## Winner's salute: both arms up for VICTORY_SECONDS after crossing the line (keeps pedalling).
func set_victory(active: bool) -> void:
	if active and not victory_started:
		victory_started = true
		victory_left = VICTORY_SECONDS
	elif not active:
		victory_started = false
		victory_left = 0.0

func _play_pose(index: int) -> void:
	if animator == null or resolved_poses.size() != POSES.size():
		return
	if index == current_pose:
		return
	var clip_name: StringName = resolved_poses[index]
	# Use instant, phase-accurate clip switching; manual crossfades need
	# additional evaluation and could leave the old pose in place.
	animator.play(clip_name, 0.0, 1.0)
	current_pose = index
	_apply_phase()
	animator.advance(0.0)
	print("Velodrome rider: actieve animatie ", clip_name)

func _apply_phase() -> void:
	if animator == null or resolved_poses.size() != POSES.size() or current_pose < 0:
		return
	var clip: Animation = animator.get_animation(resolved_poses[current_pose])
	if clip == null:
		return
	var time_pos: float = (cadence_phase / TAU) * clip.length
	animator.seek(time_pos, true)
	# Refresh Skeleton3D/skin transforms at the requested crank phase.
	animator.advance(0.0)

func pedal(delta: float, cadence_rpm: float, power_w: float = 0.0) -> void:
	if animator == null or resolved_poses.size() != POSES.size():
		return
	stopped = false
	# Above 800 W stand up; remain standing down to 700 W.
	if standing_active:
		if power_w < 700.0:
			standing_active = false
	elif power_w > 800.0:
		standing_active = true
	var target: int = 2 if standing_active else (1 if power_w > 300.0 else 0)
	if bool(get_meta("pursuit_mode", false)):
		standing_active = false
		target = 0
	if victory_left > 0.0 and not bool(get_meta("pursuit_mode", false)):
		victory_left = maxf(0.0, victory_left - delta)
		standing_active = false
		target = VICTORY_POSE
	if target != current_pose:
		_play_pose(target)
	var cadence_value: float = maxf(0.0, cadence_rpm)
	cadence_phase = fposmod(cadence_phase + cadence_value * TAU / 60.0 * delta, TAU)
	# Evaluate animated bones each physics frame in MANUAL mode.
	animator.advance(delta * cadence_value / BASE_CADENCE)
	# Keep crank angle phase continuous across animation switches.
	_apply_phase()
	standing_amount = move_toward(standing_amount, 1.0 if standing_active else 0.0, delta * 4.0)

func get_pov_sway() -> float:
	return sin(cadence_phase) * standing_amount if not stopped else 0.0

func finish_pose(_winner: bool) -> void:
	if stopped:
		return
	stopped = true
	standing_active = false
	standing_amount = 0.0
	_apply_phase()

func resume_riding() -> void:
	stopped = false
	_apply_phase()
