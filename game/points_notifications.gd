extends RefCounted
## Consume jury records once; scoring remains entirely in the jury.
var seen_events := 0
var seen_awards: Dictionary = {}
var warned: Dictionary = {}

func reset() -> void:
	seen_events = 0
	seen_awards.clear()
	warned.clear()

func collect(jury, leader_distance: float) -> Array[String]:
	var messages: Array[String] = []
	for i in range(seen_events, jury.events.size()):
		var event: Dictionary = jury.events[i]
		if int(event.rider) == 0:
			messages.append("+ 20 punten!" if int(event.delta) > 0 else "- 20 punten")
	seen_events = jury.events.size()
	for sprint in jury.sprints:
		var place: int = sprint.order.find(0)
		if place < 0 or seen_awards.has(sprint.lap): continue
		seen_awards[sprint.lap] = true
		if int(sprint.awards[place]) > 0: messages.append("+ %d punten" % int(sprint.awards[place]))
	if jury.finish_clock < 0.0:
		for lap in range(jury.INTERVAL, jury.laps + 1, jury.INTERVAL):
			if not warned.has(lap) and leader_distance >= (lap - 1) * jury.LAP:
				warned[lap] = true
				if leader_distance < lap * jury.LAP:
					messages.append("Eindsprint over 1 ronde!" if lap == jury.laps else "Tussensprint over 1 ronde!")
	return messages
