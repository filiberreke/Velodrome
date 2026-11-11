extends Control
## The timing bar is available only inside the valid training exchange position.
var state: Dictionary = {}
var caption: Label
var hint: Label
var feedback_label: Label
var show_slider := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -320; offset_right = 320
	offset_top = 190; offset_bottom = 390
	caption = Label.new(); caption.position = Vector2(20,10)
	caption.add_theme_font_size_override("font_size",22); add_child(caption)
	hint = Label.new(); hint.position = Vector2(20,112); hint.size = Vector2(600,100)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",18); add_child(hint)
	feedback_label = Label.new(); feedback_label.position = Vector2(20,190); feedback_label.size = Vector2(600,60)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size",19); add_child(feedback_label)

func update_state(value: Dictionary) -> void:
	state = value; visible = not value.is_empty()
	if not visible: return
	var active: bool = state.active
	var waiting: bool = not state.get("partner_present",true)
	var approaching: bool = not active or state.phase == "APPROACH"
	var positioned: bool = state.get("position_valid",true)
	var pace_ok: bool = state.get("speed_valid",true)
	show_slider = active and positioned and (pace_ok or state.phase != "APPROACH") and state.phase in ["APPROACH","GRAB","SLING"] and not waiting
	caption.text = "MADISON · %s · %s" % ["Advanced" if state.advanced else "Easy",state.get("progress","")]
	hint.position.y = 112 if show_slider else 55
	var role: String = state.get("role","")
	if waiting:
		hint.text = state.message + " · ← → sturen"
	elif approaching:
		hint.text = role + "\n" + str(state.get("instruction","Volg de gele lijn"))
		if not positioned:
			hint.text += "\nAflossen niet mogelijk wegens slechte positionering\n" + str(state.get("position_reason",""))
		elif not pace_ok: hint.text += "\nAflossen niet mogelijk wegens je snelheid\n" + str(state.get("speed_reason",""))
		else: hint.text += "\nA: grijpen" if state.can_grab else "\nWacht tot je ploegmaat binnen handbereik is"
	elif state.phase in ["GRAB","SLING"]:
		hint.text = role + "\n" + ("A loslaten: score %d/100" % roundi(state.get("score",0.0)) if state.advanced else "Automatische slinger · momentum maximaal 70%")
	else: hint.text = role + "\n" + state.message
	feedback_label.text = state.get("feedback","")
	feedback_label.position.y = 190 if show_slider else 190 if approaching and (not positioned or not pace_ok) and not waiting else 115
	var height: float = 200 if show_slider else 200 if approaching and (not positioned or not pace_ok) and not waiting else 120
	if not feedback_label.text.is_empty(): height = feedback_label.position.y+60
	offset_bottom = offset_top+height
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	draw_style_box(preload("res://menu_theme.gd").panel(),Rect2(Vector2.ZERO,size))
	if not show_slider: return
	var bar := Rect2(20,57,size.x-40,36)
	draw_rect(bar,Color("c6cbd0"))
	# The controller supplies the exact accepted interval, including its late edge.
	if state.get("grab_window_valid",false):
		var start: float = state.grab_left
		var finish: float = state.grab_right
		draw_rect(Rect2(bar.position+Vector2(bar.size.x*start,0),Vector2(bar.size.x*(finish-start),bar.size.y)),Color("8dc799"))
	var centre: float = bar.position.x+bar.size.x*float(state.approach_t)
	var width: float = maxf(4.0,bar.size.x*0.35*float(state.efficiency))
	var left: float = clampf(centre-width*0.5,bar.position.x,bar.end.x-width)
	draw_rect(Rect2(left,bar.position.y,width,bar.size.y),Color("256da5"))
	draw_line(Vector2(centre,51),Vector2(centre,99),Color("152b43"),3.0)
