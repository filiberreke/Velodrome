extends PanelContainer
const MenuStyle := preload("res://menu_theme.gd")
## One reusable quartet card for the roster and the pursuit broadcast.
signal selected(entry: Dictionary)
signal records_requested(entry: Dictionary)
const Catalog := preload("res://rider_catalog.gd")
const Appearance := preload("res://player_appearance.gd")
var entry: Dictionary = {}
var interactive := true
var compact := false
var accent := Color("53d4d1")

class Emblem extends Control:
	var kind := ""
	var country := ""
	var tint := Color.WHITE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO,size)
		if not country.is_empty():
			var bands: Array = []
			match country:
				"italy": bands = [Color("15965b"),Color.WHITE,Color("dc3c4c")]
				"france": bands = [Color("2258b3"),Color.WHITE,Color("e33d4d")]
				"belgium": bands = [Color("15191e"),Color("ffe34a"),Color("ed3b4f")]
				"netherlands": bands = [Color("d6424c"),Color.WHITE,Color("244f9e")]
				"germany": bands = [Color("15191e"),Color("dc3546"),Color("ffd045")]
			if not bands.is_empty():
				for i in 3:
					var vertical := country in ["italy","france","belgium"]
					draw_rect(Rect2(Vector2(size.x*i/3.0,0) if vertical else Vector2(0,size.y*i/3.0),Vector2(size.x/3.0,size.y) if vertical else Vector2(size.x,size.y/3.0)),bands[i])
			elif country == "denmark":
				draw_rect(r,Color("d52a43"));draw_rect(Rect2(0,size.y*.43,size.x,size.y*.14),Color.WHITE);draw_rect(Rect2(size.x*.30,0,size.x*.10,size.y),Color.WHITE)
			elif country == "portugal":
				draw_rect(r,Color("df3543"));draw_rect(Rect2(0,0,size.x*.4,size.y),Color("07834e"));draw_circle(Vector2(size.x*.4,size.y*.5),size.y*.20,Color("ffdb5b"))
			elif country == "united_states":
				draw_rect(r,Color.WHITE)
				for i in 7: draw_rect(Rect2(0,size.y*i*2/13.0,size.x,size.y/13.0),Color("d14152"))
				draw_rect(Rect2(0,0,size.x*.45,size.y*.54),Color("294c89"))
				for x in 3:
					for y in 3: draw_circle(Vector2(size.x*(.08+x*.13),size.y*(.1+y*.16)),.8,Color.WHITE)
			else:
				draw_rect(r,Color("152b67") if country != "new_zealand" else Color("142b5a"))
				# Union flag canton, also used by Australia and New Zealand.
				var full := country == "great_britain"
				var w := size.x if full else size.x*.5
				var h := size.y if full else size.y*.5
				draw_line(Vector2.ZERO,Vector2(w,h),Color.WHITE,3)
				draw_line(Vector2(w,0),Vector2(0,h),Color.WHITE,3)
				draw_rect(Rect2(0,h*.36,w,h*.28),Color.WHITE);draw_rect(Rect2(w*.39,0,w*.22,h),Color.WHITE)
				draw_rect(Rect2(0,h*.43,w,h*.14),Color("df3e51"));draw_rect(Rect2(w*.45,0,w*.10,h),Color("df3e51"))
				if not full:
					for at in [Vector2(.76,.3),Vector2(.64,.6),Vector2(.82,.78),Vector2(.91,.49)]: draw_circle(at*size,1.7,Color("ed5362") if country == "new_zealand" else Color.WHITE)
			draw_rect(r,Color(1,1,1,.30),false,1)
			return
		var c := size*.5
		match kind:
			"cp":
				draw_arc(c,8,.45,TAU+.1,30,tint,2,true)
				draw_line(c,c+Vector2(5,-5),tint,2,true)
				draw_line(c+Vector2(-4,-12),c+Vector2(4,-12),tint,2,true)
			"peak":
				draw_colored_polygon(PackedVector2Array([c+Vector2(1,-12),c+Vector2(-8,1),c+Vector2(-1,1),c+Vector2(-4,12),c+Vector2(9,-3),c+Vector2(2,-3)]),tint)
			"reserve":
				draw_rect(Rect2(c-Vector2(8,9),Vector2(16,19)),tint,false,2)
				draw_rect(Rect2(c+Vector2(-3,-12),Vector2(6,3)),tint)
				for i in 3: draw_rect(Rect2(c+Vector2(-5,3-i*5),Vector2(10,3)),tint)
			"record":
				draw_arc(c+Vector2(0,-3),7,0,PI,20,tint,2,true)
				draw_line(c+Vector2(-7,-3),c+Vector2(-7,-9),tint,2,true);draw_line(c+Vector2(7,-3),c+Vector2(7,-9),tint,2,true)
				draw_line(c+Vector2(-7,-9),c+Vector2(7,-9),tint,2,true)
				draw_line(c,c+Vector2(0,8),tint,2,true);draw_line(c+Vector2(-6,9),c+Vector2(6,9),tint,2,true)

static func country_name(id: String) -> String:
	return "België" if id == "belgium" else String(Appearance.COUNTRY_NAMES.get(id,id.capitalize()))

func text(value: String, font_size: int, color: Color = MenuStyle.INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

func _ready() -> void:
	theme = MenuStyle.create()
	accent = MenuStyle.BLUE
	if compact:
		_build_compact()
		return
	custom_minimum_size = Vector2(340, 412 if interactive else 370)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skin := StyleBoxFlat.new()
	skin.bg_color = MenuStyle.PAPER
	skin.border_color = accent.darkened(.35)
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(18)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: skin.set_content_margin(side,18)
	add_theme_stylebox_override("panel",skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var badge := text(Catalog.TYPES[int(entry.profile)].to_upper(),15,accent)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(badge)
	top.add_child(text("#%02d" % int(entry.jersey.get("number",entry.slot)),16,MenuStyle.MUTED))
	var name_label := text(entry.name,26)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var country_row := HBoxContainer.new()
	country_row.add_theme_constant_override("separation",10)
	column.add_child(country_row)
	var flag := Emblem.new()
	flag.country = entry.country
	flag.custom_minimum_size = Vector2(38,24)
	country_row.add_child(flag)
	country_row.add_child(text(country_name(entry.country),17,MenuStyle.MUTED))
	var line := HSeparator.new()
	line.modulate = accent.darkened(.5)
	column.add_child(line)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	column.add_child(body)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(104,172)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	body.add_child(portrait)
	var picture := Image.new()
	if not String(entry.portrait_path).is_empty() and picture.load(entry.portrait_path) == OK: portrait.texture = ImageTexture.create_from_image(picture)
	if portrait.texture == null:
		var preview = preload("res://player_appearance_preview.gd").new()
		portrait.add_child(preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.show_identity(entry)
		preview.camera.size = 1.55
		preview.camera.position = Vector3(0,1.35,3.5)
		preview.camera.look_at(Vector3(0,1.1,0))
		preview.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if String(entry.portrait_url).begins_with("https://"): _request_photo(entry.portrait_url,portrait,preview)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation",12)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stats)
	_meter(stats,"cp","CP",float(entry.cp_w),350,"W")
	_meter(stats,"peak","Sprintvermogen",float(entry.max_power_w),1800,"W")
	_meter(stats,"reserve","W′-reserve",float(entry.w_prime_j),40000,"J")
	var record_row := HBoxContainer.new()
	column.add_child(record_row)
	var trophy := Emblem.new()
	trophy.kind = "record";trophy.tint = accent;trophy.custom_minimum_size = Vector2(26,26)
	record_row.add_child(trophy)
	var record_s := best_1000m()
	record_row.add_child(text("1 km  ·  %d s" % roundi(record_s) if record_s > 0 else "1 km  ·  Nog geen record",16,MenuStyle.MUTED))
	if interactive:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation",8)
		column.add_child(actions)
		var choose := Button.new()
		choose.text = "Selecteer"
		choose.custom_minimum_size.y = 42
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button_skin := StyleBoxFlat.new();button_skin.bg_color = accent;button_skin.set_corner_radius_all(8)
		choose.add_theme_stylebox_override("normal",button_skin)
		MenuStyle.primary(choose)
		choose.pressed.connect(func():selected.emit(entry))
		actions.add_child(choose)
		var records := Button.new();records.text = "Profiel & records";records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		records.pressed.connect(func():records_requested.emit(entry))
		actions.add_child(records)

func _meter(parent: Control, kind: String, caption: String, value: float, maximum: float, unit: String) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation",5)
	parent.add_child(block)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",6);block.add_child(row)
	var icon := Emblem.new();icon.kind = kind;icon.tint = accent;icon.custom_minimum_size = Vector2(25,25);row.add_child(icon)
	var title := text(caption,14,MenuStyle.MUTED);title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(title)
	row.add_child(text("%d %s" % [roundi(value),unit],16))
	var meter := ProgressBar.new();meter.show_percentage = false;meter.max_value = maximum;meter.value = value;meter.custom_minimum_size.y = 7
	var back := StyleBoxFlat.new();back.bg_color = MenuStyle.PALE;back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new();fill.bg_color = accent;fill.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("background",back);meter.add_theme_stylebox_override("fill",fill);block.add_child(meter)

func _build_compact() -> void:
	custom_minimum_size = Vector2(280, 216)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", MenuStyle.panel(MenuStyle.PAPER, MenuStyle.LINE, 12, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(text(Catalog.TYPES[int(entry.profile)], 14, MenuStyle.BLUE))
	var name_label := text(String(entry.name), 20)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.tooltip_text = String(entry.name)
	column.add_child(name_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(66, 86)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	body.add_child(portrait)
	var picture := Image.new()
	if not String(entry.portrait_path).is_empty() and picture.load(entry.portrait_path) == OK:
		portrait.texture = ImageTexture.create_from_image(picture)
	if portrait.texture == null:
		var preview = preload("res://player_appearance_preview.gd").new()
		portrait.add_child(preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.show_identity(entry)
		preview.camera.size = 1.55
		preview.camera.position = Vector3(0, 1.35, 3.5)
		preview.camera.look_at(Vector3(0, 1.1, 0))
		preview.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if String(entry.portrait_url).begins_with("https://"): _request_photo(entry.portrait_url, portrait, preview)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("separation", 4)
	body.add_child(stats)
	stats.add_child(text(country_name(entry.country), 14, MenuStyle.MUTED))
	for item in [["CP", entry.cp_w, "W"], ["Sprint", entry.max_power_w, "W"], ["W′", entry.w_prime_j, "J"]]:
		var row := HBoxContainer.new()
		stats.add_child(row)
		var caption := text(String(item[0]), 14, MenuStyle.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		row.add_child(text("%d %s" % [roundi(float(item[1])), item[2]], 16))
	var change := Button.new()
	change.text = "Wissel renner"
	change.custom_minimum_size.y = 36
	change.add_theme_font_size_override("font_size", 16)
	change.pressed.connect(func() -> void: selected.emit(entry))
	column.add_child(change)

func best_1000m() -> float:
	var best := float(entry.records.get("record_1000m_s",0.0))
	var saved := preload("res://rider_records.gd").new().personal(entry.id)
	for key in saved:
		var record: Dictionary = saved[key]
		if int(record.get("mode",-1)) != 4 or int(record.get("distance_m",0)) != 1000 or roundi(record.get("ai_percent",0.0)) != 80: continue
		var parameters: Dictionary = record.get("parameters",{})
		if not is_equal_approx(float(parameters.get("cp_w",0.0)),float(entry.cp_w)): continue
		if not is_equal_approx(float(parameters.get("max_power_w",0.0)),float(entry.max_power_w)): continue
		if not is_equal_approx(float(parameters.get("w_prime_j",0.0)),float(entry.w_prime_j)): continue
		if best <= 0 or float(record.time_s) < best: best = float(record.time_s)
	return best

func _request_photo(url: String, portrait: TextureRect, fallback: Control) -> void:
	var request := HTTPRequest.new();request.body_size_limit = 4*1024*1024;request.timeout = 8;add_child(request)
	request.request_completed.connect(func(result,code,_headers,body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var picture := Image.new();var error := picture.load_png_from_buffer(body)
			if error != OK: error = picture.load_jpg_from_buffer(body)
			if error != OK: error = picture.load_webp_from_buffer(body)
			if error == OK: portrait.texture = ImageTexture.create_from_image(picture);fallback.hide()
		request.queue_free())
	if request.request(url) != OK: request.queue_free()
