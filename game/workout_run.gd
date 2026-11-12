extends RefCounted
const Library := preload("res://workout_library.gd")
var blocks: Array[Dictionary] = []
var phase := "IDLE"
var reason := ""
var elapsed := 0.0
var ftp_w := 200
var name := ""
func load_workout(item: Dictionary) -> bool:
	blocks.clear()
	name = str(item.get("name","Workout"))
	for source in item.get("blocks",[]):
		if source.kind == "IntervalsT":
			for i in range(int(source.repeat)):
				blocks.append({"kind":"SteadyState","duration":float(source.on_duration),"power_low":float(source.on_power),"power_high":float(source.on_power),"events":[]})
				blocks.append({"kind":"Recovery","duration":float(source.off_duration),"power_low":float(source.off_power),"power_high":float(source.off_power),"events":[]})
		else: blocks.append(source.duplicate(true))
	if blocks.is_empty() or duration() > 86400: return false
	for block in blocks:
		if float(block.duration) <= 0 or float(block.get("power_low",0)) < 0 or float(block.get("power_high",0)) < 0: return false
	phase = "IDLE"; elapsed = 0; reason = ""
	return true
func duration() -> float: return Library.total_seconds(blocks)
func running() -> bool: return phase in ["CONNECTING","ERG","FREE"]
func start(_now: float) -> void: elapsed = 0; phase = "CONNECTING"; reason = ""
func stop(message: String) -> void:
	if running(): phase = "RESULT"; reason = message
func sample(_now: float,_watts: float,_cadence: float = -1) -> void: pass
func current() -> Dictionary:
	var remaining := elapsed
	for i in range(blocks.size()):
		if remaining < float(blocks[i].duration): return {"block":blocks[i],"index":i,"seconds":remaining}
		remaining -= float(blocks[i].duration)
	return {}
func target(_now: float) -> int:
	var part := current()
	if part.is_empty() or part.block.kind == "FreeRide": return 0
	var block: Dictionary = part.block
	var power := float(block.power_low)
	if block.kind in ["Warmup","Cooldown","Ramp"]: power = lerpf(power,float(block.power_high),float(part.seconds)/float(block.duration))
	return roundi(power*ftp_w)
func advance(dt: float) -> void:
	if not running(): return
	elapsed = minf(duration(),elapsed+maxf(0,dt))
	if elapsed >= duration(): stop("Workout voltooid")
func instruction() -> String:
	var part := current()
	if part.is_empty(): return ""
	var result := ""
	for event in part.block.get("events",[]):
		if float(event.time) <= float(part.seconds): result = str(event.message)
	return result
