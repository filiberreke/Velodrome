extends Node3D
# Integrated Blender rig + skinned meshes. Contains both bicycle and cyclist.
const RIDER_SCENE: PackedScene = preload("res://assets/riders/velodrome_rider.glb")
const PURSUIT_SCENE: PackedScene = preload("res://assets/riders/velodrome_pursuit.glb")
const SKINSUIT_COVERAGE: Shader = preload("res://skinsuit_coverage.gdshader")
const BASE_CADENCE: float = 60.0
const BLEND_SECONDS: float = 0.25
const POSES: Array[String] = ["cruise", "sprint_seated", "sprint_standing", "victory"]
const VICTORY_POSE := 3
const VICTORY_SECONDS := 6.0
# beta.16.16: printable areas on the skinsuit. Any PNG works; transparent pixels = no print.
const DECAL_SLOTS: Array[String] = ["back", "chest", "thigh_L", "thigh_R"]
const DECAL_DIR := "res://assets/riders/decals/"
# Opt-in per instance, independent of profile or rider index.
@export var country_kit: String = ""
@export_file("*.png") var skinsuit_png: String = ""
@export_file("*.png") var helmet_png: String = ""
@export var visor: String = ""
const KIT_DIR := "res://assets/riders/national_kits/"
var _default_materials: Array[Material] = []
# Index order: player, drafter, sprinter, attacker.
const SHAPE_KEYS: Array[String] = ["ShoulderWidth", "TorsoMass", "HipWidth", "ThighMass", "CalfMass", "ArmMass"]
const RIDER_SHAPES: Array = [
	[0.00, 0.00, 0.00, 0.00, 0.00, 0.00],
	[-0.24, -0.18, -0.15, -0.20, -0.18, -0.12],
	[0.75, 0.60, 0.23, 0.90, 0.75, 0.57],
	[-0.52, -0.48, -0.38, -0.48, -0.45, -0.38],
]


signal madison_parameters_changed(parameters: Dictionary)
var madison_state: Dictionary = {}

func set_madison_state(parameters: Dictionary, rider: int) -> void:
	if parameters.is_empty() or not parameters.get("active", false):
		if not madison_state.is_empty():
			madison_state.clear()
			madison_parameters_changed.emit({})
		return
	madison_state = parameters.duplicate(true)
	madison_state["role"] = "giver" if rider == int(parameters.giver) else "receiver"
	madison_state["hand"] = "right" if madison_state.role == "giver" else "left"
	madison_parameters_changed.emit(madison_state)

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
## Only attached for the two Madison participants.
var exchange_overlay: Node = null

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
	_apply_default_decals(int(get_meta("appearance_profile", rider_index)))
	body_mesh = rig_scene.find_child("Rider", true, false) as MeshInstance3D
	if body_mesh != null:
		for surface in range(body_mesh.mesh.get_surface_count()):
			_default_materials.append(body_mesh.get_surface_override_material(surface))
	var config: Dictionary = get_meta("jersey_config", {})
	var png_path := String(get_meta("skinsuit_png", config.get("skinsuit_png", skinsuit_png))).strip_edges()
	if not png_path.is_empty():
		set_skinsuit_png(png_path)
	else:
		set_country_kit(String(get_meta("country_kit", config.get("country_kit", country_kit))))

	set_helmet_png(String(get_meta("helmet_png", config.get("helmet_png", helmet_png))))
	set_visor(String(get_meta("visor", config.get("visor", visor))))

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
			body.set_blend_shape_value(shape_index, clampf(float((get_meta("body_shapes", {}) as Dictionary).get(shape_name, RIDER_SHAPES[index][profile_key])), -1.0, 1.0))
	# Independent material overrides on every instance. Neither mutate shared
	# GLB materials nor tint skin, chain, tires, visor or other bike parts.
	var palettes: Array[Dictionary] = [
		{"suit": Color("eac736"), "accent": Color("fff2a9"), "helmet": Color("eac736"), "helmet2": Color("fff3bd"), "panel": Color("252934"), "glove": Color("292c36"), "shoe": Color("eeeeee")},
		{"suit": Color("35ad77"), "accent": Color("ccf4dc"), "helmet": Color("219b68"), "helmet2": Color("b0eacd"), "panel": Color("26392d"), "glove": Color("23312a"), "shoe": Color("f1f1eb")},
		{"suit": Color("268cd3"), "accent": Color("8cd5ff"), "helmet": Color("187ec2"), "helmet2": Color("adddff"), "panel": Color("172a4b"), "glove": Color("18263e"), "shoe": Color("f3f4f6")},
		{"suit": Color("df504b"), "accent": Color("ffc9a1"), "helmet": Color("d7433d"), "helmet2": Color("ffac8a"), "panel": Color("382629"), "glove": Color("30252a"), "shoe": Color("eeeeee")},
	]
	var appearance_index := clampi(int(get_meta("appearance_profile", index)), 0, 3)
	_apply_palette_to_mesh(body, palettes[appearance_index])
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

## Empty restores this rider's original palette and decals. Unknown IDs do nothing.
## Call before ready or at runtime; the same atlas fits both exported rigs.
func set_country_kit(country: String) -> bool:
	var key := country.strip_edges().to_lower()
	if not key.is_empty() and (not key.is_valid_identifier() or not ResourceLoader.exists(KIT_DIR + key + "/skinsuit.png")):
		push_warning("Velodrome rider: onbekende outfit: " + country)
		return false
	if body_mesh == null:
		country_kit = key
		return true
	if _default_materials.size() != body_mesh.mesh.get_surface_count():
		return false
	# Load and validate before changing any instance overrides.
	var texture: Texture2D = null
	if not key.is_empty():
		texture = load(KIT_DIR + key + "/skinsuit.png") as Texture2D
		if texture == null:
			return false
	_apply_skinsuit_texture(texture)
	country_kit = key
	skinsuit_png = ""
	return true

## Optional atlas path per rider. Empty or invalid paths restore original colors.
## Relative paths are relative to res://; user:// and absolute PNG paths also work.
func set_skinsuit_png(png_path: String) -> bool:
	var file := png_path.strip_edges().replace("\\", "/")
	if body_mesh == null:
		skinsuit_png = file
		return true
	var texture: Texture2D = _load_png(file)
	_apply_skinsuit_texture(texture)
	country_kit = ""
	skinsuit_png = file if texture != null else ""
	if texture == null and not file.is_empty():
		push_warning("Velodrome rider: skinsuit_png niet geladen; standaardkleuren: " + file)
		return false
	return true

func _apply_skinsuit_texture(texture: Texture2D) -> void:
	if body_mesh == null or _default_materials.size() != body_mesh.mesh.get_surface_count():
		return
	for surface in range(body_mesh.mesh.get_surface_count()):
		var src := body_mesh.mesh.surface_get_material(surface)
		if src != null and (src.resource_name.ends_with("_kit") or src.resource_name.begins_with("decal_")):
			body_mesh.set_surface_override_material(surface, _default_materials[surface])
	if texture == null:
		return
	var image := texture.get_image()
	if image != null and image.is_compressed():
		image.decompress()
	var has_coverage := image != null and image.detect_alpha() != Image.ALPHA_NONE
	var skin := Color(0.96, 0.72, 0.56)
	for surface in range(body_mesh.mesh.get_surface_count()):
		var source := body_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if source != null and source.resource_name == "skin":
			skin = source.albedo_color
			break
	for surface in range(body_mesh.mesh.get_surface_count()):
		var src := body_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if src == null or not src.resource_name.to_lower().ends_with("_kit"):
			continue
		if has_coverage:
			var covered := ShaderMaterial.new()
			covered.shader = SKINSUIT_COVERAGE
			covered.resource_name = src.resource_name
			covered.set_shader_parameter("skinsuit_atlas", texture)
			covered.set_shader_parameter("skin_color", skin)
			covered.set_shader_parameter("fabric_roughness", src.roughness)
			body_mesh.set_surface_override_material(surface, covered)
			continue
		var material := src.duplicate() as StandardMaterial3D
		material.albedo_color = Color.WHITE
		material.albedo_texture = texture
		material.texture_repeat = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		body_mesh.set_surface_override_material(surface, material)
	for slot in DECAL_SLOTS:
		set_decal(slot, null)

func _load_png(png_path: String) -> Texture2D:
	var file := png_path.strip_edges().replace("\\", "/")
	if file.is_empty() or file.get_extension().to_lower() != "png":
		return null
	if not file.is_absolute_path():
		file = "res://" + file.trim_prefix("./")
	if file.begins_with("res://") and ResourceLoader.exists(file):
		return load(file) as Texture2D
	if FileAccess.file_exists(file):
		var image := Image.new()
		if image.load(file) == OK and not image.is_empty():
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)
	return null

## Independent PNG for the opaque helmet shell and center stripe only.
func set_helmet_png(png_path: String) -> bool:
	var file := png_path.strip_edges()
	if body_mesh == null:
		helmet_png = file
		return true
	var texture := _load_png(file)
	for surface in range(body_mesh.mesh.get_surface_count()):
		var src := body_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if src == null or src.resource_name not in ["helmet", "helmet2"]:
			continue
		body_mesh.set_surface_override_material(surface, _default_materials[surface])
		if texture != null:
			var material := src.duplicate() as StandardMaterial3D
			material.albedo_color = Color.WHITE
			material.albedo_texture = texture
			material.texture_repeat = false
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			body_mesh.set_surface_override_material(surface, material)
	helmet_png = file if texture != null else ""
	if texture == null and not file.is_empty():
		push_warning("Velodrome rider: helmet_png niet geladen; standaardkleuren: " + file)
		return false
	return true

## Two explicit options; omitted/empty keeps the original imported visor.
func set_visor(style: String) -> bool:
	var key := style.strip_edges().to_lower()
	var valid := key in ["", "donker", "doorzichtig"]
	if body_mesh == null:
		visor = key if valid else ""
		return valid
	for surface in range(body_mesh.mesh.get_surface_count()):
		var src := body_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if src == null or src.resource_name != "visor":
			continue
		body_mesh.set_surface_override_material(surface, _default_materials[surface])
		if valid and not key.is_empty():
			var material := src.duplicate() as StandardMaterial3D
			material.albedo_color = Color(0.035, 0.045, 0.065, 0.88) if key == "donker" else Color(0.92, 0.97, 1.0, 0.16)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			body_mesh.set_surface_override_material(surface, material)
	visor = key if valid else ""
	if not valid:
		push_warning("Velodrome rider: visor moet donker of doorzichtig zijn: " + style)
	return valid

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
	if exchange_overlay != null and is_instance_valid(exchange_overlay):
		exchange_overlay.call("drive", cadence_phase, resolved_poses[current_pose])
		standing_amount = move_toward(standing_amount, 1.0 if standing_active else 0.0, delta * 4.0)
		return
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
