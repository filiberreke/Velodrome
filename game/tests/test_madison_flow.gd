extends SceneTree
## MadisonDemoExchange flow: states/signals, Easy + Advanced, scenarios A-D, early release, grab failures, clean-up,
## player-receiver never steered, momentum transfer. Writes timelines/summary when MADISON_WRITE_DOCS=1.
var failures := 0
const CONTACT_LIMIT_MM := 5.0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")

func _frames(r: MadisonScenarioRunner, n: int, a: bool, gap: float = 1.2, ahead: float = 0.0) -> void:
	for i in n:
		r.ex.a_held = a
		r.ex.set_gameplay(gap, ahead)
		r.ex.tick(1.0 / 60.0)
		r.giver.pedal(1.0 / 60.0, 70.0, 250.0)
		r.receiver.pedal(1.0 / 60.0, 70.0, 250.0)
		await process_frame

func run_test() -> void:
	var r := MadisonScenarioRunner.new()
	await r.build(self)
	var write_docs := OS.get_environment("MADISON_WRITE_DOCS") == "1"
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/madison/measurements")
	DirAccess.make_dir_recursive_absolute(dir)
	var summary := "scenario,gap_m,mode,release_sling_t,release_efficiency,release_reason,max_contact_err_mm,max_stretch,visual_gap_min,visual_gap_max,visual_shift_m,max_lean_deg,approach_end_stretch,events\n"
	var order := ["approach_started", "grab_window_opened", "grabbed", "sling_peak", "released", "separated"]
	var results := {}
	for sc in [["A", 1.2], ["B", 1.2], ["C", 1.2], ["E", 1.2], ["D", 0.6], ["D", 1.2], ["D", 1.8]]:
		var m: Dictionary = await r.run(sc[0], sc[1], write_docs)
		var tag := "%s@%.2f" % [sc[0], sc[1]]
		results[tag] = m
		var ev: Array = m["events"]
		check(m["grab_ok"] and m["separated"], "%s: grabbed and separated (events %s)" % [tag, str(ev)])
		var idx := -1
		for name in order:
			var found := -1
			for i in ev.size():
				if str(ev[i]).begins_with(name):
					found = i
					break
			if name == "sling_peak" and sc[0] == "B":
				continue
			check(found > idx or (found == 0 and idx == -1), "%s: signal order %s" % [tag, name])
			idx = maxi(idx, found)
		check(m["max_err_mm"] < CONTACT_LIMIT_MM, "%s: hands within %.0f mm of HandContact during GRAB+SLING (%.2f mm)" % [tag, CONTACT_LIMIT_MM, m["max_err_mm"]])
		check(m["max_stretch"] < MadisonDemoExchange.STRETCH_EARLY_RELEASE, "%s: arm never needs to stretch (%.2f)" % [tag, m["max_stretch"]])
		check(m["cleaned_up"], "%s: everything cleaned up after SEPARATE (no overlay left on the riders)" % tag)
		var evs := " ".join(PackedStringArray(ev.map(func(e): return str(e))))
		summary += "%s,%.2f,%s,%.3f,%.3f,%s,%.2f,%.3f,%.2f,%.2f,%.2f,%.1f,%.3f,\"%s\"\n" % [sc[0], sc[1], "easy" if sc[0] in ["D", "E"] else "advanced", m["release_sling_t"],
			m["release_efficiency"], m["release_reason"], m["max_err_mm"], m["max_stretch"], m["min_visual_gap"], m["max_visual_gap"], m["max_visual_shift_m"], m["max_lean_deg"], m["approach_end_stretch"], evs]
		if write_docs:
			var f := FileAccess.open(dir.path_join("timeline_%s_gap%.2f.json" % [sc[0], sc[1]]), FileAccess.WRITE)
			f.store_string(JSON.stringify({"fps": 60, "scenario": sc[0], "gap": sc[1], "timeline": m["timeline"]}))
		print("scenario %s gap %.2f: release at sling_t %.3f eff %.3f (%s), contact err %.2f mm, stretch %.2f, visual gap %.2f..%.2f" % [sc[0], sc[1], m["release_sling_t"], m["release_efficiency"], m["release_reason"], m["max_err_mm"], m["max_stretch"], m["min_visual_gap"], m["max_visual_gap"]])
	check(results["A@1.20"]["release_efficiency"] > 0.99, "A: perfect release at maximum momentum")
	check(results["B@1.20"]["release_sling_t"] < 0.25 and results["B@1.20"]["release_efficiency"] < 0.3, "B: early release gives low efficiency")
	check(results["C@1.20"]["release_sling_t"] > 0.93 and results["C@1.20"]["release_efficiency"] < 0.5, "C: over-holding lowers efficiency (%.2f)" % results["C@1.20"]["release_efficiency"])
	check(results["E@1.20"]["release_reason"] == "auto" and results["E@1.20"]["release_efficiency"] > 0.99, "Easy: automatic release at the peak")
	check(results["D@0.60"]["min_visual_gap"] >= 0.75 and results["D@0.60"]["min_visual_gap"] >= MadisonDemoExchange.VISUAL_GAP_MIN - 1e-6, "D 0.60 m: visual model is moved out to >= 0.75 m (controller uses %.2f)" % MadisonDemoExchange.VISUAL_GAP_MIN)
	check(results["D@1.80"]["max_visual_gap"] <= 1.40 + 1e-6, "D 1.80 m: visual distance reduced to <= 1.40 m")
	check(results["D@1.20"]["max_visual_shift_m"] < 1e-6, "D 1.20 m: no visual correction needed")
	# gameplay distance runs away during the sling -> controlled early release instead of stretching
	var m2: Dictionary = await r.run("E", 1.2, false, 0.9)
	check(m2["release_reason"] == "reach", "drift beyond reach -> early release with reason reach (got %s)" % m2["release_reason"])
	check(m2["max_err_mm"] < CONTACT_LIMIT_MM, "early release happens before the hand loses contact (%.2f mm)" % m2["max_err_mm"])
	print("reach early release at sling_t ", m2["release_sling_t"], " err ", m2["max_err_mm"])
	# grab failures
	var m3: Dictionary = await r.run("E", 2.0, false)
	check("grab_failed:too_far" in m3["events"] and not m3["grab_ok"] and m3["separated"] and m3["cleaned_up"], "gap 2.0 m: grab_failed(too_far), clean abort (%s)" % str(m3["events"]))
	var got := []
	var cb := func(x: String) -> void: got.append(x)
	r.ex.grab_failed.connect(cb)
	r.ex.start(r.giver, r.receiver, MadisonDemoExchange.Mode.ADVANCED)
	await _frames(r, 5, false)
	await _frames(r, 1, true)
	check(got == ["too_early"], "Advanced: A before the window -> grab_failed(too_early) (%s)" % str(got))
	await _frames(r, 80, false)
	check(r.ex.state == MadisonDemoExchange.State.IDLE and r.giver.get("exchange_overlay") == null, "failed grab ends in IDLE with clean riders")
	got.clear()
	r.ex.start(r.giver, r.receiver, MadisonDemoExchange.Mode.ADVANCED)
	await _frames(r, 120, false)
	check("missed" in got, "Advanced: window passes without A -> grab_failed(missed) (%s)" % str(got))
	await _frames(r, 40, false)
	r.ex.grab_failed.disconnect(cb)
	# steering / speed outputs
	for pr in ["", "giver", "receiver"]:
		r.ex.cancel()
		r.ex.start(r.giver, r.receiver, MadisonDemoExchange.Mode.EASY, pr, 16.0, 14.0)
		for i in 400:
			r.giver.position = Vector3.ZERO
			r.receiver.position = Vector3(-1.2, 0, MadisonProfile.delta_f(r.ex.sling_t))
			r.ex.set_gameplay(1.2, MadisonProfile.delta_f(r.ex.sling_t))
			r.ex.tick(1.0 / 60.0)
			r.giver.pedal(1.0 / 60.0, 70.0, 250.0)
			r.receiver.pedal(1.0 / 60.0, 70.0, 250.0)
			await process_frame
		check(r.ex.speed_receiver > 14.0 + 2.5 and r.ex.speed_giver < 16.0 - 2.0, "speed transfer: receiver %.2f faster, giver %.2f slower" % [r.ex.speed_receiver, r.ex.speed_giver])
		check(r.ex.outward_role != "receiver", "player-receiver is never steered automatically")
		check((pr == "giver" and r.ex.outward_role == "") or (pr != "giver" and r.ex.outward_role == "giver" and r.ex.outward_progress > 0.99), "slowed AI giver steers outward gradually (player=%s, role=%s, progress %.2f)" % [pr, r.ex.outward_role, r.ex.outward_progress])
	if write_docs:
		var f2 := FileAccess.open(dir.path_join("scenarios_summary.csv"), FileAccess.WRITE)
		f2.store_string(summary)
	print(summary)
	print("flow test: failures=", failures)
	r.ex.cancel()
	r.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
