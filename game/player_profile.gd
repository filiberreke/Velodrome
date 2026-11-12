extends RefCounted
const DEFAULT_FTP := 200
var path := "user://config/rider_profile.cfg"
func ftp() -> int:
	var cfg := ConfigFile.new()
	if path == "user://config/rider_profile.cfg": preload("res://config_paths.gd").load_user(cfg,"rider_profile.cfg")
	else: cfg.load(path)
	var value: Variant = cfg.get_value("rider","ftp_w",DEFAULT_FTP)
	if not (value is float or value is int) or not is_finite(float(value)): return DEFAULT_FTP
	return clampi(roundi(value),20,1000)
func set_ftp(watts: float, source: String = "manual") -> Error:
	if not is_finite(watts) or watts < 20 or watts > 1000: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	if path == "user://config/rider_profile.cfg": preload("res://config_paths.gd").load_user(cfg,"rider_profile.cfg")
	else: cfg.load(path)
	cfg.set_value("rider","ftp_w",roundi(watts))
	cfg.set_value("rider","ftp_source",source)
	cfg.set_value("rider","ftp_updated_at",Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return cfg.save(path)
