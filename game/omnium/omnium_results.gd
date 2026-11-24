extends RefCounted
static func clock(seconds: float) -> String:
	var milliseconds := roundi(maxf(0.0, seconds) * 1000.0)
	return "%d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]

static func scratch_time(rider: int, order: Array[int], times: Array[float], credits: Array[int]) -> String:
	if times[rider] < 0.0: return String(TranslationServer.translate("RESULT_STILL_RACING"))
	if order.is_empty(): return "—"
	var winner: int = order[0]
	if rider == winner: return clock(times[rider])
	var lap_gap: int = credits[winner] - credits[rider]
	if lap_gap != 0: return String(TranslationServer.translate("OMNIUM_D_LAP_S")) % [lap_gap, "" if absi(lap_gap) == 1 else "n"]
	if times[winner] < 0.0: return "Voorlopig"
	return "+" + clock(times[rider] - times[winner])
