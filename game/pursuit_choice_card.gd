extends PanelContainer
## Team and saved-performance cards share the visual language of the rider passport.
const Passport := preload("res://rider_passport.gd")
const Records := preload("res://pursuit_records.gd")
var data: Dictionary = {}
var is_team := false
var replay := false
var team_size := 3
var strength := 100.0

class PowerChart extends Control:
	var samples: Array = []
	func _draw() -> void:
		for i in range(1,4): draw_line(Vector2(0,size.y*i/4.0),Vector2(size.x,size.y*i/4.0),Color("29435d"),1)
		if samples.size()<2:return
		var duration := float(samples[-1].t)
		var peak := 1.0
		for sample in samples: peak=maxf(peak,float(sample.p))
		var points := PackedVector2Array()
		var stride := maxi(1,samples.size()/80)
		for i in range(0,samples.size(),stride):
			points.append(Vector2(float(samples[i].t)/maxf(.001,duration)*size.x,size.y-float(samples[i].p)/peak*(size.y-8)-4))
		points.append(Vector2(size.x,size.y-float(samples[-1].p)/peak*(size.y-8)-4))
		if points.size()>1:draw_polyline(points,Color("ffc266"),2,true)

func label(value: String,font_size: int=18,color: Color=Color.WHITE)->Label:
	var node:=Label.new();node.text=value
	node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
	node.autowrap_mode=TextServer.AUTOWRAP_OFF
	return node

func _ready()->void:
	custom_minimum_size=Vector2(470,392)
	var style:=StyleBoxFlat.new();style.bg_color=Color("14263b");style.border_color=Color("b38a4b")if replay else Color("397e9d")
	style.set_border_width_all(2);style.set_corner_radius_all(18)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,20)
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	column.add_child(label("EIGEN PLOEGPRESTATIE"if replay and is_team else("EIGEN PRESTATIE"if replay else"NATIONALE PLOEG"),15,Color("ffc266")if replay else Color("64dfd3")))
	var title:=label(String(data.get("name","")),26);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.custom_minimum_size.x=400;title.max_lines_visible=2;column.add_child(title)
	if replay:
		var date:=String(data.get("finished_local",data.get("created_local","")))
		if date.is_empty()and float(data.get("created_at",0))>0:date=Time.get_datetime_string_from_unix_time(int(data.created_at)).replace("T"," ")+" UTC"
		column.add_child(label(date if not date.is_empty()else"Datum onbekend",16,Color("b9cadc")))
		var chart:=PowerChart.new();chart.samples=data.get("samples",[]);chart.custom_minimum_size.y=64;column.add_child(chart)
		_stat(column,"record","Gereden tijd",_duration(float(data.time_s)))
		_stat(column,"peak","Gemiddeld vermogen","%d W"%roundi(Records.average_power(data)))
		_stat(column,"cp","Afstand","%d m"%int(data.distance_m))
		column.add_child(label("Doeltijd bij %d%%: %s"%[roundi(strength),_duration(float(data.time_s)*100.0/strength)],16,Color("ffc266")))
	else:
		var country:=String(data.get("country","belgium"))
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);column.add_child(row)
		var flag:=Passport.Emblem.new();flag.country=country;flag.custom_minimum_size=Vector2(44,28);row.add_child(flag)
		row.add_child(label(Passport.country_name(country),19,Color("bdcfdf")))
		var riders:=HBoxContainer.new();riders.alignment=BoxContainer.ALIGNMENT_CENTER;riders.add_theme_constant_override("separation",4);column.add_child(riders)
		for i in team_size:
			var portrait=preload("res://player_appearance_preview.gd").new();portrait.custom_minimum_size=Vector2(92,110);riders.add_child(portrait)
			portrait.show_identity({"profile":1,"morphs":{},"jersey":{"country_kit":country}})
			portrait.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		_stat(column,"cp","Ploeg","%d renners"%team_size)
		_stat(column,"peak","CP op kop","%d W"%roundi(float(data.get("cp_w",250.0))))
		_stat(column,"reserve","W′-reserve","%d J"%roundi(float(data.get("w_prime_j",20000.0))))

static func _duration(seconds:float)->String:
	var minutes:=int(seconds)/60
	return "%d:%05.2f"%[minutes,fmod(seconds,60.0)]

func _stat(parent:Control,kind:String,title:String,value:String)->void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);parent.add_child(row)
	var icon:=Passport.Emblem.new();icon.kind=kind;icon.tint=Color("ffc266")if replay else Color("64dfd3");icon.custom_minimum_size=Vector2(26,26);row.add_child(icon)
	var caption:=label(title,17,Color("b4c9dc"));caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption);row.add_child(label(value,20))
