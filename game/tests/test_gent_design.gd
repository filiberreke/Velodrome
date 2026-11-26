extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var default_game=preload("res://main.gd").new()
	var shared_track=preload("res://venues/venue_track.gd").new(default_game.venue)
	for i in 500:
		for lane in [0.0,1.18,7.18]:
			check(shared_track.at(float(i)*.5,lane).distance_to(default_game._at(float(i)*.5,lane))<.0001,"Design track matches production coordinate transform")
	default_game.free()
	var v=preload("res://venues/gent.tres")
	check(v.validation_errors().is_empty(),"Gent profile validates")
	check(absf(v.lap_length_m*6-1000)<1e-9,"Exactly six laps per kilometre")
	var track=preload("res://venues/venue_track.gd").new(v)
	var max_bank:=0.0
	for i in 1000:
		var s:float=v.lap_length_m*float(i)/1000
		check(track.at(s,1.1).distance_to(track.at(s+v.lap_length_m,1.1))<.0001,"Closed Gent lap")
		check(absf(track.at(s,v.apron_width_m).distance_to(track.at(s,v.track_outer_offset_m))-7.0)<.0001,"Seven metre banked surface")
		max_bank=maxf(max_bank,rad_to_deg(track.bank(s)))
	check(absf(max_bank-52)<.0001,"52 degree turns")
	var scene=preload("res://venues/gent/gent_preview.gd").new();scene.show_riders=false
	root.add_child(scene);scene.set_process(false);await process_frame
	check(scene.arena.infield.cabins.size()==12,"Twelve own sober cabins")
	for cabin in scene.arena.infield.cabins:
		check(cabin.position.x<0 and track.at(0,0).x>0,"Cabins are opposite the finish, on the right of the photo view")
		check(cabin.has_node("LowCabinBack") and cabin.has_node("RestBench") and cabin.has_node("BikeRackBeam"),"Open service bay contains cot and raised bike rack")
		check(cabin.get_node("LowCabinBack").mesh.size.y<1,"Low open bays replace tall cells")
	check_photo_layout(scene,track)
	check_infield_coverage(scene.arena.infield,900)
	var simple_field=preload("res://venues/gent/gent_infield.gd").new();root.add_child(simple_field)
	simple_field.build(scene,v,track,scene.arena.crowd,true,.72)
	check_infield_coverage(simple_field,350)
	check(simple_field.spectator_count<scene.arena.infield.spectator_count,"Simple mode reduces public geometry")
	print("GENT_INFIELD_COUNTS standard=%d simple=%d"%[scene.arena.infield.spectator_count,simple_field.spectator_count])
	simple_field.free()
	check(scene.arena.official.official_clips.size()==4,"Shared official carries all four animations")
	check(absf(scene.arena.official.official_lap_m-v.lap_length_m)<.0001,"Official uses Gent lap length")
	check(scene.arena.suite.voices.size()==2,"Both original presenters retained")
	check(scene.arena.has_node("GentFlatCeiling"),"Flat hall ceiling")
	check(not scene.arena.has_node("InfinityScreen") and scene.find_child("Rennersboxen",true,false)==null,"No automatic Vélodrome decor import")
	check(scene.arena.seat_count>2000 and scene.arena.spectator_count>1000,"Own Gent terraces and crowd")
	check(scene.arena.get_node("GentWhiteLogoRedOuterBoarding").get_meta("brand_panels")==28,"White Vélodrome logo on red repeats around the outer boarding")
	check(scene.arena.infield.get_node("GentWhiteLogoRedInfieldBoarding").get_meta("brand_panels")==24,"White Vélodrome logo on red repeats around the infield")
	check(scene.arena.find_children("GentWhiteLogoRedTrackPanel*","MeshInstance3D",false,false).size()==5,"Red Vélodrome panels on the track replace the reference sponsor locations")
	for locale in ["nl","en"]:
		TranslationServer.set_locale(locale)
		for key in ["GENT_ZONE_PRESS","GENT_ZONE_MEDICAL","GENT_ZONE_MIXED","GENT_ZONE_JURY","GENT_ZONE_TECHNICAL"]:check(tr(key)!=key,"Zone sign translated: "+locale+" "+key)
	for i in 4:
		scene.set_view(i)
		check(scene.camera.position.y<16.0 and scene.camera.position.y>0,"Camera inside the hall")
	scene.free();await process_frame
	print("GENT_DESIGN_OK" if failures==0 else "GENT_DESIGN_FAILED %d"%failures)
	quit(0 if failures==0 else 1)

func check_infield_coverage(field,min_count:int)->void:
	check(field.public_positions.size()>min_count,"Infield is populated across its usable oval")
	for p in field.public_positions:
		check(field._public_floor_free(Vector2(p.x,p.z)),"Crowd leaves counters, technical area and crossings clear")
	var occupied_regions:=[0,0,0]
	for p in field.public_positions:
		if p.z>23.0:occupied_regions[0]+=1
		if absf(p.x)<2.5 and absf(p.z)<15:occupied_regions[1]+=1
		if p.x>5.25 and p.z>10.0:occupied_regions[2]+=1
	for count in occupied_regions:check(count>12,"Far bend, public centre and finish-side corner are populated")
	for x in range(-10,11,2):
		for z in range(-30,31,2):
			var probe:=Vector2(x,z)
			if not field._public_floor_free(probe):continue
			var nearest:=INF
			for p in field.public_positions:nearest=minf(nearest,probe.distance_to(Vector2(p.x,p.z)))
			check(nearest<2.1,"No broad unused patch remains on public floor")

func check_photo_layout(scene,track)->void:
	var field=scene.arena.infield
	var finish:Vector3=track.at(0.0,0.0)
	check(absf(field.jury_zone.position.z-finish.z)<.01 and field.jury_zone.position.x>0,"Jury is beside the actual finish line")
	check(field.jury_zone.has_node("FinishBell") and field.jury_zone.has_node("LapDisplayCantilever"),"Jury has a bell and cantilevered lap counter")
	var display:Vector3=field.lap_display.global_position
	check(absf(display.x-finish.x)<.8 and absf(display.z-finish.z)<1.0 and display.y>2.7,"Small lap display hangs at the inner track edge by the finish")
	check(field.press_zones.size()==2,"Two press areas in the near bend")
	check(field.medical_zone.position.z< -27 and absf(field.medical_zone.position.x)<.1,"Medical post is centred in the near bend")
	check(field.press_zones[0].position.x*field.press_zones[1].position.x<0,"Press areas flank the central mixed zone")
	check(field.mixed_zone.position.z>field.medical_zone.position.z and absf(field.mixed_zone.position.x)<.1,"Mixed zone runs between press areas and medical post")
	check(field.interview_backdrop.has_node("Sponsorachtergrond") and field.interview_backdrop.has_node("SponsorachtergrondAchterkant"),"Mixed zone reuses both faces of the existing Vélodrome backdrop")
	check(field.interview_backdrop.get_node("Sponsorachtergrond").material_override.get_shader_parameter("blue_logo").resource_path=="res://assets/boarding/velodrome-boarding.png","Shared backdrop uses original Vélodrome artwork")
	check(field.find_child("GentInfieldBar",true,false)==null and field.find_child("GentCabinRiders*",true,false)==null,"Central islands and ambiguous seated figures removed")
	for bounds in field.restricted_footprints:
		for p in field.public_positions:check(not bounds.has_point(Vector2(p.x,p.z)),"Public stays outside all working zones")
	scene.set_view(0)
	var screen_finish:Vector2=scene.camera.unproject_position(finish)
	var screen_team:Vector2=scene.camera.unproject_position(Vector3(-8.35,0,finish.z))
	check(screen_finish.x<screen_team.x,"Photo camera puts finish on LEFT and team services on RIGHT")
	check(screen_finish.x<root.get_visible_rect().size.x*.4,"Finish remains on the left side of the overview")
	check(scene.camera.position.z< -35,"Photo camera looks from the same near bend")
