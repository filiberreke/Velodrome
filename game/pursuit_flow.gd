extends VBoxContainer
## Two explicit steps. Legacy option controls remain a hidden race configuration model.
const MenuStyle:=preload("res://menu_theme.gd")
const Paths:=preload("res://config_paths.gd")
var menu
var options
var team:=false
var step:=1
var kind:=0
var current:=0
var candidates:Array[Dictionary]=[]
var preferences_path:="user://config/opponent_selection.cfg"
var preferences:=ConfigFile.new()
var distance_page:VBoxContainer
var opponent_page:VBoxContainer
var distance_buttons:Array[Button]=[]
var size_buttons:Array[Button]=[]
var advanced:VBoxContainer
var advanced_toggle:CheckButton
var advanced_rows:Array[Control]=[]
var factor_controls:Array[SpinBox]=[]
var resistance:OptionButton
var card_holder:CenterContainer
var current_card:Control
var left_arrow:Button
var right_arrow:Button
var counter:Label
var summary_label:Label
var ai_tab:Button
var replay_tab:Button
var strength_slider:HSlider
var strength_input:SpinBox
var strength_hint:Label
var demo_row:HBoxContainer
var demo_input:SpinBox
var previous_button:Button
var proceed_button:Button
var status:Label
var syncing:=false

func text(value:String,size:int=20,color:Color=MenuStyle.INK)->Label:
	var node:=Label.new();node.text=value;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",color)
	return node

func button(value:String,width:float=200)->Button:
	var node:=Button.new();node.text=value;node.custom_minimum_size=Vector2(width,50);node.add_theme_font_size_override("font_size",21)
	var selected:=StyleBoxFlat.new();selected.bg_color=MenuStyle.BLUE;selected.border_color=MenuStyle.BLUE;selected.set_border_width_all(2);selected.set_corner_radius_all(8)
	node.add_theme_stylebox_override("pressed",selected);node.add_theme_color_override("font_pressed_color",Color.WHITE)
	return node

func center_row(parent:Control)->HBoxContainer:
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",18);parent.add_child(row);return row

func _ready()->void:
	theme=MenuStyle.create()
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	distance_page=VBoxContainer.new();distance_page.add_theme_constant_override("separation",20);distance_page.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(distance_page)
	distance_page.add_child(text("Welke afstand wil je rijden?",28))
	var distance_row:=center_row(distance_page)
	for value in [1000,4000]:
		var choice:=button("1 km\n4 ronden"if value==1000 else"4 km\n16 ronden",350)
		choice.custom_minimum_size.y=140;choice.toggle_mode=true;distance_row.add_child(choice);distance_buttons.append(choice)
		choice.pressed.connect(func():select_distance(value))
	var squad_row:=center_row(distance_page);squad_row.name="SquadSize"
	for value in [3,4]:
		var choice:=button("%d renners"%value,240);choice.toggle_mode=true;squad_row.add_child(choice);size_buttons.append(choice)
		choice.pressed.connect(func():select_size(value))
	advanced_toggle=CheckButton.new();advanced_toggle.text="Ploeginstellingen";advanced_toggle.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;distance_page.add_child(advanced_toggle)
	advanced=VBoxContainer.new();advanced.add_theme_constant_override("separation",8);distance_page.add_child(advanced);advanced.hide()
	advanced_toggle.toggled.connect(func(value):advanced.visible=value and team)
	var line:=center_row(advanced);line.add_child(text("Weerstand",18));resistance=OptionButton.new();resistance.add_item("Manueel",0);resistance.add_item("ERG",1);line.add_child(resistance)
	resistance.item_selected.connect(func(index):if options!=null:options.resistance_choice.select(index);options.resistance_choice.item_selected.emit(index))
	for rank in range(3):
		var row:=center_row(advanced);row.add_child(text("%de positie · vermogen in het wiel"%(rank+2),18));var input:=SpinBox.new();input.min_value=10;input.max_value=100;input.step=5;input.suffix="%";input.custom_minimum_size=Vector2(130,38);row.add_child(input)
		advanced_rows.append(row);factor_controls.append(input)
		input.value_changed.connect(func(value):if team and options!=null:options.factor_inputs[rank].value=value)
	opponent_page=VBoxContainer.new();opponent_page.add_theme_constant_override("separation",6);opponent_page.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(opponent_page)
	summary_label=text("",18,MenuStyle.MUTED);opponent_page.add_child(summary_label)
	var tabs:=center_row(opponent_page);ai_tab=button("AI-renners",260);replay_tab=button("Eigen prestaties",260);ai_tab.toggle_mode=true;replay_tab.toggle_mode=true;tabs.add_child(ai_tab);tabs.add_child(replay_tab)
	ai_tab.pressed.connect(func():select_kind(0));replay_tab.pressed.connect(func():select_kind(1))
	var carousel:=center_row(opponent_page);carousel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	left_arrow=button("‹",70);left_arrow.custom_minimum_size.y=90;left_arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER;carousel.add_child(left_arrow);left_arrow.pressed.connect(func():cycle(-1))
	card_holder=CenterContainer.new();card_holder.custom_minimum_size=Vector2(500,390);carousel.add_child(card_holder)
	right_arrow=button("›",70);right_arrow.custom_minimum_size.y=90;right_arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER;carousel.add_child(right_arrow);right_arrow.pressed.connect(func():cycle(1))
	counter=text("",17,MenuStyle.MUTED);opponent_page.add_child(counter)
	var strength_row:=center_row(opponent_page);strength_row.add_child(text("Sterkte tegenstander",20))
	strength_slider=HSlider.new();strength_slider.min_value=30;strength_slider.max_value=150;strength_slider.step=5;strength_slider.custom_minimum_size=Vector2(320,36);strength_row.add_child(strength_slider)
	strength_input=SpinBox.new();strength_input.min_value=30;strength_input.max_value=150;strength_input.step=5;strength_input.suffix="%";strength_input.custom_minimum_size=Vector2(115,40);strength_row.add_child(strength_input)
	strength_slider.value_changed.connect(_strength_changed);strength_input.value_changed.connect(_strength_changed)
	strength_hint=text("",16,MenuStyle.MUTED);opponent_page.add_child(strength_hint)
	demo_row=center_row(distance_page);demo_row.add_child(text("Demo-startvermogen",16));demo_input=SpinBox.new();demo_input.min_value=0;demo_input.max_value=900;demo_input.step=25;demo_input.suffix="W";demo_input.custom_minimum_size=Vector2(130,36);demo_row.add_child(demo_input)
	demo_input.value_changed.connect(func(value):if menu!=null:menu.demo_power_input.value=value)
	status=text("",17,MenuStyle.INK);add_child(status)
	var navigation:=center_row(self);previous_button=button("← Spelvormen",250);proceed_button=button("Kies tegenstander →",350);navigation.add_child(previous_button);navigation.add_child(proceed_button)
	proceed_button.add_theme_stylebox_override("normal",menu.panel_style(MenuStyle.BLUE));proceed_button.add_theme_color_override("font_color",Color.WHITE)
	MenuStyle.primary(proceed_button)
	previous_button.pressed.connect(back);proceed_button.pressed.connect(next_step)
	hide()

func section()->String:
	return "team_%d"%options.team_size()if team else"individual"

func begin(is_team:bool)->void:
	team=is_team;options=menu.team_options if team else menu.pursuit_options
	preferences.clear();preferences.load(preferences_path)
	step=1;kind=0;current=0;advanced_toggle.button_pressed=false
	distance_page.get_node("SquadSize").visible=team;advanced_toggle.visible=team;advanced.hide()
	ai_tab.text="AI-ploegen"if team else"AI-renners"
	var distance:=int(preferences.get_value("team"if team else"individual","distance",options.distance_m()))
	if distance not in [1000,4000]:distance=1000
	select_distance(distance)
	if team:
		select_size(clampi(int(preferences.get_value("team","size",options.team_size())),3,4))
	show();_show_step()

func select_distance(distance:int)->void:
	if options==null:return
	options.distance_choice.select(0 if distance==1000 else 1);options.refresh_rides()
	for i in distance_buttons.size():distance_buttons[i].button_pressed=(i==0)==(distance==1000)

func select_size(value:int)->void:
	options.teammates.select(value-3);options.teammates.item_selected.emit(value-3)
	for i in size_buttons.size():size_buttons[i].button_pressed=i==value-3
	resistance.select(options.resistance_choice.selected)
	for i in factor_controls.size():
		factor_controls[i].value=options.factor_inputs[i].value;advanced_rows[i].visible=i<value-1

func next_step()->void:
	if step==1:
		step=2;menu.page=4
		kind=int(preferences.get_value(section(),"kind",0));kind=clampi(kind,0,1)
		_load_candidates(true)
		if candidates.is_empty()and kind==1:kind=0;_load_candidates(true)
		_show_step();return
	if not can_start():return
	_save();menu.start_requested.emit()

func back()->void:
	if step==2:step=1;menu.page=2;_show_step()
	else:menu.show_choices()

func _show_step()->void:
	distance_page.visible=step==1;opponent_page.visible=step==2
	previous_button.text="← Wedstrijd"if step==2 else"← Spelvormen"
	proceed_button.text="Start wedstrijd →"if step==2 else"Kies tegenstander →"
	menu.page_title.text="Kies je tegenstander"if step==2 else"Kies je wedstrijd"
	menu.page_title.add_theme_font_size_override("font_size",36)
	menu.breadcrumb.text="02  Instellingen     /     Tegenstander"
	if step==2:summary_label.text="%s  ·  %d km%s"%["Ploegenachtervolging"if team else"Achtervolging",options.distance_m()/1000,"  ·  %d renners"%options.team_size()if team else""]
	update_bridge();proceed_button.grab_focus.call_deferred()

func select_kind(value:int)->void:
	kind=value;_load_candidates(true);_save()

func _load_candidates(restore:bool)->void:
	options.refresh_rides()
	candidates=options.ai_entries if kind==0 else options.rides
	current=0
	if restore:
		var saved:=String(preferences.get_value(section(),"ai_id"if kind==0 else"ride_id",""))
		for i in candidates.size():
			if _id(candidates[i])==saved:current=i;break
	var percentage:=float(preferences.get_value(section(),"ai_percent"if kind==0 else"replay_percent",80.0 if kind==0 else 100.0))
	syncing=true;strength_slider.value=percentage;strength_input.value=percentage;syncing=false
	_sync_selection();_draw_card()

func _id(entry:Dictionary)->String:
	return String(entry.get("id",entry.get("country","")))

func cycle(direction:int)->void:
	if candidates.is_empty():return
	current=posmod(current+direction,candidates.size());_sync_selection();_draw_card();_save()

func _sync_selection()->void:
	options.opponent_choice.select(kind)
	if not candidates.is_empty():
		if kind==0:options.ai_choice.select(current);options._ai_selected()
		else:options.ride_choice.select(current)
	options.opponent_percent=strength_input.value
	options.refresh_state()

func _draw_card()->void:
	if is_instance_valid(current_card):card_holder.remove_child(current_card);current_card.queue_free()
	current_card=null
	ai_tab.button_pressed=kind==0;replay_tab.button_pressed=kind==1
	left_arrow.disabled=candidates.size()<2;right_arrow.disabled=candidates.size()<2
	if candidates.is_empty():
		var empty:=text("Nog geen eigen prestaties voor deze wedstrijd.\nRijd en bewaar eerst een rit, of kies een AI-tegenstander.",22);empty.custom_minimum_size=Vector2(480,320);empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;card_holder.add_child(empty);current_card=empty
		counter.text="Geen prestaties beschikbaar"
	else:
		var entry:Dictionary=candidates[current]
		if not team and kind==0:
			var card=preload("res://rider_passport.gd").new();card.entry=entry;card.interactive=false;card.custom_minimum_size.x=470;card_holder.add_child(card);current_card=card
		else:
			var card=preload("res://pursuit_choice_card.gd").new();card.replay=kind==1;card.is_team=team;card.team_size=options.team_size()if team else 1;card.strength=strength_input.value
			card.data=entry.duplicate(true)
			if kind==0:card.data["name"]="Team "+String(entry.name);card.data["cp_w"]=options.configured_cp()
			card_holder.add_child(card);current_card=card
		counter.text="%d / %d"%[current+1,candidates.size()]
	strength_hint.text="80% = basisniveau van het AI-profiel"if kind==0 else"100% = exacte eigen prestatie · hoger percentage = sneller tempo"
	update_bridge()

func _strength_changed(value:float)->void:
	if syncing:return
	syncing=true;strength_slider.value=value;strength_input.value=value;syncing=false
	if options==null:return
	options.opponent_percent=value
	if kind==1:_draw_card()
	_save()

func can_start()->bool:
	return step==2 and not candidates.is_empty()and options.can_start()and not menu.bridge_unavailable

func update_bridge()->void:
	if options==null:return
	demo_row.visible=not menu.bridge_seen and not menu.bridge_unavailable
	demo_input.value=menu.demo_power_input.value
	proceed_button.disabled=menu.bridge_unavailable or(step==2 and not can_start())
	status.text="Bridge niet beschikbaar: sluit andere spelinstanties."if menu.bridge_unavailable else("Kies een tegenstander om te starten."if step==2 and candidates.is_empty()else"")
	status.visible=not status.text.is_empty()

func _save()->void:
	if options==null:return
	preferences.set_value("team"if team else"individual","distance",options.distance_m())
	if team:preferences.set_value("team","size",options.team_size())
	preferences.set_value(section(),"kind",kind)
	preferences.set_value(section(),"ai_percent"if kind==0 else"replay_percent",strength_input.value)
	if not candidates.is_empty():preferences.set_value(section(),"ai_id"if kind==0 else"ride_id",_id(candidates[current]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preferences_path.get_base_dir()))
	preferences.save(preferences_path)

func bridge_action(value:String)->void:
	if value=="B":back();return
	if step==2:
		if value in ["LEFT","RIGHT"]:cycle(-1 if value=="LEFT"else 1)
		elif value in ["UP","DOWN"]:strength_input.value+=5 if value=="UP"else -5
		elif value=="A":next_step()
		return
	var actions:={"LEFT":"ui_left","RIGHT":"ui_right","UP":"ui_up","DOWN":"ui_down","A":"ui_accept"}
	if not actions.has(value):return
	for pressed in [true,false]:
		var event:=InputEventAction.new();event.action=actions[value];event.pressed=pressed;get_viewport().push_input(event)
