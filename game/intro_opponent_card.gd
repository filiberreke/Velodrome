extends PanelContainer
## Replaceable broadcast card. Portraits are rendered from the selected riders.
const Countries := preload("res://rennersboxen/race_countries.gd")
const COUNTRY_LABELS := {"belgium":"België", "netherlands":"Nederland", "france":"Frankrijk", "italy":"Italië", "germany":"Duitsland", "great_britain":"Groot-Brittannië", "denmark":"Denemarken", "australia":"Australië", "new_zealand":"Nieuw-Zeeland", "portugal":"Portugal", "united_states":"Verenigde Staten"}
const PORTRAIT_FIRST_LAYER := 15
var game: Node3D
var profile: Dictionary = {}
var portraits: Array[SubViewport] = []
var portrait_cameras: Array[Camera3D] = []
var portrait_riders: Array[int] = []
var saved_layers: Array[Dictionary] = []
var stack: VBoxContainer
var portraits_ready := false

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091b30f0")
	style.border_color = Color("5bd8ed")
	style.border_width_left = 4
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(350, 0)
	stack = VBoxContainer.new()
	stack.custom_minimum_size.x = 310
	stack.add_theme_constant_override("separation", 10)
	add_child(stack)
	hide()

func _process(_delta: float) -> void:
	if not visible: return
	# Autowrapped labels settle after container sorting; fit the final content
	# instead of retaining the temporary height from the first layout pass.
	size = Vector2(350, get_combined_minimum_size().y)
	position = Vector2(28, maxf(70, (get_viewport_rect().size.y - size.y) * 0.5))

func _label(value: String, font_size: int, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(label)

func prepare() -> void:
	clear()
	var team: bool = game.race_mode == 5
	var first: int = game.team_size if team else 1
	var count: int = game.team_size if team else 1
	var country := Countries.configured_country(game, first)
	var country_name: String = COUNTRY_LABELS.get(country, "Land onbekend")
	var replay: Dictionary = game.team_race.replay if team else game.pursuit_replay
	var title: String = country_name + " · ploeg" if team else String(game.pursuit_opponent_config.get("name", game.rider_names[first]))
	if not replay.is_empty(): title = String(replay.get("name", "Vorige prestatie"))
	profile = {"name": title, "country": country, "riders": []}
	_label("DE TEGENSTANDER", 14, Color("69dff4"))
	_label(title, 25)
	_label(country_name + (" · %d renners" % count if team else " · achtervolging"), 17, Color("bfcede"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	for index in range(first, first + count):
		var portrait_layer := 1 << (PORTRAIT_FIRST_LAYER + index - first)
		profile.riders.append(game.rider_names[index])
		var viewport := SubViewport.new()
		viewport.size = Vector2i(160, 184)
		viewport.transparent_bg = true
		viewport.world_3d = game.get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		portraits.append(viewport)
		var camera := Camera3D.new()
		camera.cull_mask = portrait_layer
		camera.fov = 30.0
		viewport.add_child(camera)
		camera.current = true
		portrait_cameras.append(camera)
		portrait_riders.append(index)
		var visual: Node3D = game.bikes[index].get_child(0)
		for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
			saved_layers.append({"node": mesh, "layers": mesh.layers})
			mesh.layers |= portrait_layer
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(70, 82)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = viewport.get_texture()
		row.add_child(picture)
	if replay.is_empty():
		var pacer = game.team_race.pacer if team else game.pursuit_pacer
		profile["cp_w"] = pacer.cp_w
		profile["reserve_j"] = pacer.WPRIME_J
		profile["target_w"] = pacer.target_w
		_label("Kopvermogen" if team else "Capaciteiten", 15, Color("69dff4"))
		_label("CP  %d W     Reserve  %.1f kJ" % [pacer.cp_w, pacer.WPRIME_J / 1000.0], 18)
		_label("Wedstrijdvermogen  %d W" % pacer.target_w, 17, Color("bfcede"))
	else:
		profile["time_s"] = replay.get("time_s", 0.0)
		_label("Vorige prestatie  %.2f s" % float(profile.time_s), 18)
		_label("%d m · opgenomen rit" % int(replay.get("distance_m", 0)), 17, Color("bfcede"))
	_label(" · ".join(profile.riders), 13, Color("bfcede"))
	size = Vector2(350, 0)

func update_portraits() -> void:
	if portraits_ready: return
	portraits_ready = true
	for i in range(portrait_cameras.size()):
		var index := portrait_riders[i]
		var rider: Node3D = game.bikes[index]
		var s: float = game._rider_distance(index, game.distances[index])
		var forward: Vector3 = game._direction(s, game.lane_offsets[index])
		var focus := rider.global_position + Vector3.UP * 1.0 + forward * 0.35
		portrait_cameras[i].global_position = focus + forward * 1.85 + forward.cross(Vector3.UP) * 0.65 + Vector3.UP * 0.28
		portrait_cameras[i].look_at(focus)
		portraits[i].render_target_update_mode = SubViewport.UPDATE_ONCE

func clear() -> void:
	hide()
	for saved in saved_layers:
		if is_instance_valid(saved.node): saved.node.layers = saved.layers
	saved_layers.clear()
	for viewport in portraits:
		remove_child(viewport)
		viewport.queue_free()
	portraits.clear()
	portrait_cameras.clear()
	portrait_riders.clear()
	portraits_ready = false
	if stack != null:
		for child in stack.get_children():
			stack.remove_child(child)
			child.queue_free()
