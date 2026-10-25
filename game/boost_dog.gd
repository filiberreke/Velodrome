extends Node3D
# Visual-only canicross dog for the demo arcade boost (beta.16.15: realistic labradoodle).
# Model + gallop animation: assets/dog/boost_dog.glb (source: assets/source_blender/crowd/build_dog.py).
# Position, timing and leash stay driven by the main game, exactly as before:
# main.gd calls set_boost_visual(active, dt, dog_pos, riding_direction, handlebar_world, bank_lean).
const DOG_SCENE: PackedScene = preload("res://assets/dog/boost_dog.glb")
var gallop := &""               # resolved from the GLB (Godot may strip the "_loop" suffix)
const LEASH_COLOUR := "c9f227"          # neon-yellow lead, like the real one
var dog_visual: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var ring_bone := -1
var leash: MeshInstance3D
var leash_mesh: CylinderMesh
var run_time := 0.0

func _material(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.6
	return m

func _find(root: Node, cls: String) -> Node:
	if root.is_class(cls):
		return root
	for c in root.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null

func _ready() -> void:
	name = "BoostCanicrossDog"
	dog_visual = DOG_SCENE.instantiate()
	dog_visual.name = "Labradoodle"
	add_child(dog_visual)
	anim = _find(dog_visual, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(dog_visual, "Skeleton3D") as Skeleton3D
	if skeleton != null:
		ring_bone = skeleton.find_bone("harness_ring")
	if anim != null:
		for a in anim.get_animation_list():
			var clip: Animation = anim.get_animation(a)
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
			if String(a).contains("gallop") or gallop == &"":
				gallop = a
	# The curly coat carries its colour in vertex colours.
	for mi in dog_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh == null:
			continue
		for i in range(mesh.get_surface_count()):
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.resource_name.begins_with("fur"):
				var dup: StandardMaterial3D = m.duplicate()
				dup.vertex_color_use_as_albedo = true
				dup.vertex_color_is_srgb = true
				dup.albedo_color = Color.WHITE
				dup.roughness = 0.95
				(mi as MeshInstance3D).set_surface_override_material(i, dup)
	leash_mesh = CylinderMesh.new()
	leash_mesh.top_radius = 0.011
	leash_mesh.bottom_radius = 0.011
	leash_mesh.height = 1.0
	leash_mesh.radial_segments = 8
	leash = MeshInstance3D.new()
	leash.mesh = leash_mesh
	leash.material_override = _material(LEASH_COLOUR)
	leash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leash.name = "CanicrossTowLine"
	add_child(leash)
	visible = false

func _harness_point() -> Vector3:
	# Leash ring on the harness, following the galloping back (dog-local space).
	if skeleton != null and ring_bone >= 0:
		var world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(ring_bone).origin
		return to_local(world)
	return Vector3(0.0, 0.76, 0.10)

func set_boost_visual(active: bool, dt: float, dog_pos: Vector3, riding_direction: Vector3, handlebar_world: Vector3, bank_lean: float) -> void:
	visible = active
	if anim != null:
		if active and not anim.is_playing() and gallop != &"":
			anim.play(gallop)
		elif not active and anim.is_playing():
			anim.stop()
	if not active:
		return
	run_time += dt * 15.0
	global_position = dog_pos
	rotation.y = atan2(riding_direction.x, riding_direction.z)
	# Matching the cyclist's smooth corner lean keeps all four paws aligned
	# visually with the banking, without affecting boost/race physics.
	rotation.z = lerp_angle(rotation.z, bank_lean * 0.8, clampf(dt * 8.0, 0.0, 1.0))
	# Gallop, bounce, ears and tail come from the baked animation (one stride = 0.4 s).
	# Endpoints in dog-local space, from the harness ring to the bicycle handlebar.
	var head_point := _harness_point()
	var bike_point := to_local(handlebar_world)
	var line := bike_point - head_point
	var dist := line.length()
	if dist > 0.02:
		leash.position = (bike_point + head_point) * 0.5
		leash_mesh.height = dist
		leash.basis = Basis(Quaternion(Vector3.UP, line.normalized()))
