extends SceneTree
## Integration checks; pass -- --capture for GPU visual review images.
const Flags := preload("res://national_flags.gd")
const ArenaFlags := preload("res://arena_flags.gd")
const Passport := preload("res://rider_passport.gd")
const Catalog := preload("res://rider_catalog.gd")
const OUTPUT := "res://verification/national_flags/"
var failures := 0
var capture := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func snapshot(label: String) -> void:
	if not capture: return
	for i in 6: await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK, "Save " + label)

func emblems(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Passport.Emblem and not child.country.is_empty(): found.append(child)
		found.append_array(emblems(child))
	return found

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture: DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1600, 1000)
	check(Flags.TEXTURES.size() == 25, "Exactly 25 shared flag textures")
	check(Flags.texture("unknown") == null, "Unknown country must not use Australia")
	var hashes := {}
	for country in ArenaFlags.Countries:
		var texture: Texture2D = Flags.texture(country)
		check(texture != null and texture.get_width() >= 960, "Original medium PNG: " + country)
		var digest := texture.get_image().get_data().hex_encode().sha256_text()
		check(not hashes.has(digest), "Every country's flag is distinct: " + country)
		hashes[digest] = true
	var game := preload("res://tests/arena_roof_test_game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var arena: Node3D = game.arena
	var group: Node3D = arena.get_node("NationalFlags")
	check(group.get_child_count() == 100, "25 flags, 25 suspension rails and 50 roof hangers")
	var positions: Array[Vector3] = []
	for country in ArenaFlags.Countries:
		var flag: MeshInstance3D = group.get_node(country)
		var s: float = flag.get_meta("track_s")
		check(flag.material_override.albedo_texture == Flags.texture(country), "Shared menu/stadium texture: " + country)
		check(flag.basis.z.dot(-arena._outward(s)) > 0.999, "Faces infield: " + country)
		check(flag.basis.determinant() > 0.999, "Non-mirrored flag: " + country)
		var quad: QuadMesh = flag.mesh
		var rim: Vector3 = arena._point(s, arena.STAND_RIM)
		check(absf(flag.position.y + quad.size.y * 0.5 - rim.y - ArenaFlags.TOP) < 0.001, "Follows bank-dependent roof height")
		check(flag.position.distance_to(arena._stadium_point(s, ArenaFlags.OFFSET, ArenaFlags.TOP - quad.size.y * 0.5)) < 0.001, "Behind last crowd row")
		check(ArenaFlags.OFFSET - quad.size.x * 0.5 > 29.61, "Whole flag clears upper seating footprint")
		check(absf(quad.size.x / quad.size.y - float(Flags.texture(country).get_width()) / Flags.texture(country).get_height()) < 0.001, "Preserves national ratio")
		for other in positions: check(flag.position.distance_to(other) > 4.0, "Flags do not overlap")
		positions.append(flag.position)
	# Exercise the actual team-pursuit carousel for every national opponent.
	var menu = game.setup_panel
	menu.select_mode(2)
	var flow = menu.pursuit_flow
	flow.next_step()
	check(flow.candidates.size() == 25, "25 selectable national teams")
	for i in flow.candidates.size():
		flow.current = i
		flow._draw_card()
		await process_frame
		var country := String(flow.candidates[i].country)
		var icons := emblems(flow.current_card)
		check(icons.size() == 1 and icons[0].country == country and Flags.texture(country) != null, "Team selection flag: " + country)
		check(flow.current_card.get_global_rect().end.y <= 1000, "Team card fits viewport")
		if country in ["china", "australia", "switzerland"]: await snapshot("team_" + country)
	# Full and compact passports for every country, including the 14 additions.
	menu.hide()
	for country in ArenaFlags.Countries:
		for compact in [false, true]:
			var card := Passport.new()
			card.entry = Catalog.entry(ConfigFile.new(), 1, 1)
			card.entry.country = country
			card.entry.jersey.country = country
			card.entry.name = Passport.country_name(country)
			card.compact = compact
			card.position = Vector2(600, 220)
			root.add_child(card)
			await process_frame
			var icons := emblems(card)
			check(icons.size() == 1 and icons[0].country == country, "Passport flag: " + country)
			if country == "japan" and not compact: await snapshot("passport_japan")
			card.free()
	if capture:
		game._set_race_hud_visible(false)
		for view in [
			["stadium_overview", Vector3(0, 9, 0), Vector3(40, 15, 0), 95.0],
			["stadium_curve", Vector3(0, 8, 15), Vector3(0, 16, 65), 95.0],
			["stadium_straight", Vector3(0, 8, -8), Vector3(-48, 14, 0), 95.0]]:
			game.camera.position = view[1]
			game.camera.look_at(view[2])
			game.camera.fov = view[3]
			await snapshot(view[0])
		# All 25 rendered menu emblems in a single review sheet.
		var sheet := PanelContainer.new()
		sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(sheet)
		var grid := GridContainer.new()
		grid.columns = 5
		sheet.add_child(grid)
		for country in ArenaFlags.Countries:
			var tile := VBoxContainer.new()
			tile.custom_minimum_size = Vector2(310, 190)
			grid.add_child(tile)
			var icon := Passport.Emblem.new()
			icon.country = country
			icon.custom_minimum_size = Vector2(230, 140)
			tile.add_child(icon)
			var label := Label.new()
			label.text = Passport.country_name(country)
			tile.add_child(label)
		await snapshot("all_25_flags")
		sheet.free()
	print("NATIONAL FLAGS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures, " countries=25 passports=50 teams=25 stadium=25")
	game.free()
	quit(1 if failures else 0)
