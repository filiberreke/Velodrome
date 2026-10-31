extends RefCounted
## Five presentation states. FINAL LAP is a brief RACE-state stadium moment.
## Event cursors never consume or mutate the game's jury/event arrays.
signal stadium_cue(kind: String, payload: Dictionary)
const INTRO := "INTRO"
const RACE := "RACE"
const SPRINT := "SPRINT"
const LAP_GAIN := "LAP_GAIN"
const FINISH := "FINISH"
var state := INTRO
var moment := ""
var age := 0.0
var remaining := 0.0
var active := {}
var pending: Array[Dictionary] = []
var seen := {}
var event_cursor := 0
var last_clock := -1.0
var last_mode := -1
var last_phase := "SETUP"
var final_announced := false
var frame := {}

func reset() -> void:
	state = INTRO; moment = ""; age = 0.0; remaining = 0.0
	active.clear(); pending.clear(); seen.clear(); event_cursor = 0
	final_announced = false

func leader_progress() -> float:
	var positions: Array = frame.get("positions", [])
	return maxf(0.0, float(positions.max())) if not positions.is_empty() else 0.0

func laps_left() -> int:
	return maxi(0, int(frame.get("laps", 0)) - floori(leader_progress() / float(frame.get("lap_length", 250.0))))

func _enqueue(kind: String, display_state: String, priority: int, seconds: float, payload := {}) -> void:
	var item := {"kind": kind, "state": display_state, "priority": priority, "duration": seconds, "payload": payload.duplicate(true)}
	# Bound backlog; simultaneous lap awards are coalesced into one spectacle.
	if kind == "lap_gain":
		for existing in pending:
			if existing.kind == kind:
				existing.payload.riders.append_array(payload.riders)
				return
	if pending.size() < 8: pending.append(item)

func _activate(item: Dictionary) -> void:
	active = item
	state = item.state; moment = item.kind; remaining = item.duration; age = 0.0
	stadium_cue.emit(moment, item.payload.duplicate(true))

func update(data: Dictionary, delta: float) -> void:
	var clock: float = data.clock
	var phase: String = data.phase
	if int(data.mode) != last_mode or clock < last_clock - 0.01 or (phase == "SETUP" and last_phase != "SETUP") or (phase == "INTRO" and last_phase != "INTRO"):
		reset()
	last_mode = data.mode; last_clock = clock; last_phase = phase
	frame = data
	age += maxf(0.0, delta)
	if phase != "RACING":
		if state != INTRO: age = 0.0
		state = INTRO; moment = ""; active.clear(); pending.clear(); remaining = 0.0
		return
	var finished_any: bool = int(data.winner) >= 0
	if finished_any:
		if state != FINISH:
			pending.clear()
			_activate({"kind": "finish", "state": FINISH, "priority": 100, "duration": 0.0, "payload": {"winner": data.winner, "provisional": not bool(data.all_finished)}})
		if bool(data.all_finished) and not bool(active.payload.get("confirmed", false)):
			active.payload.confirmed = true
			age = 0.0
			stadium_cue.emit("winner_confirmed", {"winner": data.winner})
		return
	if state == FINISH: reset()
	var events: Array = data.get("events", [])
	if events.size() < event_cursor: event_cursor = 0
	for i in range(event_cursor, events.size()):
		var event: Dictionary = events[i]
		var gained: bool = int(event.get("delta", 1 if event.get("kind", "") == "gain" else -1)) > 0
		if gained: _enqueue("lap_gain", LAP_GAIN, 80, 5.0, {"riders": [int(event.rider)], "points": int(event.get("points", 0))})
	event_cursor = events.size()
	if int(data.mode) == 1:
		var next: int = data.get("next_sprint", -1)
		var sprint_distance: float = next * float(data.lap_length) - leader_progress()
		var warning := "warning:%d" % next
		if next > 0 and next < int(data.laps) and sprint_distance > 0 and sprint_distance <= 125.0 and not seen.has(warning):
			seen[warning] = true
			_enqueue("sprint", SPRINT, 70, 3.5, {"lap": next})
		for sprint in data.get("sprints", []):
			var key := "result:%d" % int(sprint.lap)
			if not sprint.order.is_empty() and not seen.has(key) and int(sprint.lap) < int(data.laps):
				seen[key] = true
				_enqueue("sprint_result", SPRINT, 70, 6.0, {"lap": sprint.lap})
	if laps_left() == 1 and not final_announced:
		final_announced = true
		_enqueue("final_lap", RACE, 60, 4.5)
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if not pending.is_empty():
		pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) > int(b.priority))
		if remaining <= 0.0 or int(pending[0].priority) > int(active.get("priority", 0)):
			_activate(pending.pop_front())
	if remaining <= 0.0:
		if state != RACE or not moment.is_empty(): age = 0.0
		state = RACE; moment = ""; active.clear()

static func clock_text(seconds: float) -> String:
	if seconds < 0.0: return "—"
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]

func rider_name(id: int) -> String:
	var names: Array = frame.get("names", [])
	return str(names[id]) if id >= 0 and id < names.size() else "—"

func classification(limit := 3, offset := 0) -> Array[String]:
	var rows: Array[String] = []
	var order: Array = frame.get("order", [])
	for rank in range(offset, mini(offset + limit, order.size())):
		var id: int = order[rank]
		var suffix := ""
		if int(frame.mode) == 1:
			var points: Array = frame.get("points", [])
			if id < points.size(): suffix = "   %d PT" % int(points[id])
		elif state == FINISH:
			var finishes: Array = frame.finishes
			if id < finishes.size(): suffix = "   " + (clock_text(finishes[id]) if finishes[id] >= 0.0 else "ONDERWEG")
		rows.append("%d   %s%s" % [rank + 1, rider_name(id), suffix])
	return rows

func view() -> Dictionary:
	var title: String = str(frame.get("discipline", "VELODROME"))
	var headline := ""
	var footer := ""
	var rows: Array[String] = []
	var badge := "RACE CENTRE"
	var page := 0
	if state == INTRO:
		headline = title
		footer = "%s KM   •   %d RONDEN" % ["%.2f" % (float(frame.get("length", 0)) / 1000.0), int(frame.get("laps", 0))]
		badge = "WELCOME TO VELODROME"
	elif state == FINISH:
		headline = rider_name(int(frame.winner))
		badge = "WINNAAR" if bool(frame.all_finished) else "FINISH • VOORLOPIG"
		var count: int = frame.order.size()
		if bool(frame.all_finished) and age >= 9.0: page = int((age - 9.0) / 6.0) % maxi(1, ceili(float(count) / 3.0))
		rows = classification(3, page * 3)
		footer = "DEFINITIEVE UITSLAG" if bool(frame.all_finished) else "UITSLAG WORDT AANGEVULD"
		if bool(frame.all_finished) and count > 3: footer += "   •   %d–%d / %d" % [page * 3 + 1, mini(count, page * 3 + 3), count]
	elif state == LAP_GAIN:
		headline = "%+d POINTS" % int(active.payload.points) if int(frame.mode) == 1 else "RONDEWINST"
		var riders: Array = active.payload.riders
		badge = rider_name(int(riders[0])) + ("  +%d RENNERS" % (riders.size() - 1) if riders.size() > 1 else "")
		rows = classification()
		footer = "BIJGEWERKTE STAND"
	elif state == SPRINT:
		headline = "SPRINT!" if moment == "sprint" else "SPRINTUITSLAG"
		badge = "RONDE %d" % int(active.payload.lap)
		for sprint in frame.get("sprints", []):
			if int(sprint.lap) != int(active.payload.lap): continue
			for rank in mini(4, sprint.order.size()):
				rows.append("%d   %s   +%d PT" % [rank + 1, rider_name(int(sprint.order[rank])), int(sprint.awards[rank])])
		footer = "PUNTEN OP DE LIJN" if moment == "sprint" else "OFFICIËLE JURY-UITSLAG"
	else:
		if moment == "final_lap":
			headline = "FINAL LAP"
			footer = "DUBBELE SPRINTPUNTEN" if int(frame.mode) == 1 else "NOG ÉÉN RONDE"
		elif int(frame.mode) in [4, 5]:
			var gap: Variant = frame.get("gap_seconds", null)
			headline = "GELIJK" if gap != null and absf(float(gap)) < 0.005 else ("%.2f s" % absf(float(gap)) if gap != null else "TIJDMETING")
			badge = "TIJDVERSCHIL • %d m" % int(frame.get("checkpoint_m", 0)) if gap != null else "WACHT OP TUSSENTIJD"
			if gap != null and absf(float(gap)) >= 0.005: badge += "  •  " + rider_name(0 if float(gap) > 0 else 1) + " LEIDT"
			for id in 2:
				var laps: Array = frame.lap_times[id]
				var last: float = float(laps[-1]) if not laps.is_empty() else -1.0
				rows.append("%s\nRONDE %s   •   SPLIT %s" % [rider_name(id), clock_text(last), clock_text(float(frame.split_times[id]))])
			footer = "NOG %d RONDEN   •   %s" % [laps_left(), clock_text(float(frame.clock))]
		else:
			headline = "%d RONDEN" % laps_left()
			badge = "NOG TE RIJDEN"
			rows = classification()
			footer = str(frame.get("breakaway", ""))
			if int(frame.mode) == 1:
				var next: int = frame.get("next_sprint", -1)
				footer = "VOLGENDE SPRINT  RONDE %d   •   %.0f m" % [next, maxf(0.0, next * float(frame.lap_length) - leader_progress())] if next > 0 else "LAATSTE SPRINT"
				var gains: Array = frame.get("gains", [])
				if not gains.is_empty(): footer += "   •   RONDEWINSTEN %d" % int(gains.reduce(func(a: int, b: int) -> int: return a + b, 0))
	return {"state": state, "moment": moment, "title": title, "headline": headline, "badge": badge, "rows": rows, "footer": footer, "page": page}
