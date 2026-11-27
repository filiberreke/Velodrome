extends RefCounted

static func build(activity: Dictionary) -> Dictionary:
	var title: String = "Velodrome - " + str(activity.get("title","Dernytraining")) + (" (PC-proefrit)" if activity.get("demo",false) else "")
	if not String(activity.get("omnium_id", "")).is_empty():
		title = String(TranslationServer.translate("STRAVA_VE_LODROME_OMNIUM_WARM_UP_RIDE"))
	var description: String = String(TranslationServer.translate("STRAVA_DERNY_TRAINING_AVERAGE_STARTING_SPEED_D_KM_H_HIGHEST_COMPLETED_STEP_D_")) % [int(activity.get("start_speed_kmh",30)),int(activity.get("completed_kmh",0)),float(activity.get("assisted_seconds",0))]
	if activity.get("kind","derny") != "derny" and activity.get("kind","") != "ftp_test":
		description = String(TranslationServer.translate("STRAVA_S_S_STARTED_AT_A_VIRTUAL_ROLLING_SPEED_OF_0F_KM_H_VIRTUAL_SPEED_AND_DI")) % [activity.get("title","Pistetraining"),activity.get("reason",""),activity.get("initial_speed_kmh",30)]
		if activity.get("kind") == "flying_start": description += String(TranslationServer.translate("STRAVA_PASSAGE_2F_KM_H_PEAK_0F_W")) % [activity.get("entry_speed_kmh",0),activity.get("peak_power_w",0)]
		elif activity.get("kind") == "free_ride": description += String(TranslationServer.translate("STRAVA_FREE_RIDING_2F_KM_D_COMPLETED_LAPS")) % [float(activity.get("distance_m",0))/1000,activity.get("laps",[]).size()]
		else: description += String(TranslationServer.translate("STRAVA_PELOTON_0F_KM_H_1F_M_GAINED")) % [activity.get("peloton_kmh",30),activity.get("gained_m",0)]
	if activity.get("kind","") == "ftp_test":
		description = String(TranslationServer.translate("STRAVA_FTP_TEST_S_ESTIMATED_FTP_0F_W_VIRTUAL_SPEED_AND_DISTANCE_POWER_HEART_R")) % [activity.get("reason",""),float(activity.get("ftp_w",0.0))]
	if activity.get("demo",false): description = String(TranslationServer.translate("STRAVA_SIMULATED_PC_TEST_RIDE")) + description
	return {"title":title, "description":description}
