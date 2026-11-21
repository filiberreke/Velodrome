# EuroMaxCycling booth and race introduction

The provisional booth sits at the finish line, at the back of the second spectator tier. Its current presenters are the rounded-head left_v04 and right_v05 designs; the latter wears a photo-inspired white polo with dark green collar and sleeve bands. Small unreadable photo lettering is approximated graphically.

After confirming any implemented race mode, a 44-second presentation runs before the existing standing-start gate:

- 0–4 s: approach the booth.
- 4–10 s: “Welkom bij Velodrome! Welkom bij de volgende wedstrijd: de [discipline]!” appears as subtitles. The discipline is selected anew at each start: scratch, achtervolging, ploegenachtervolging or puntenkoers. Text is also prepared for ploegkoers and keirin when those modes become playable. The two mouth animations run in turn. No spoken audio is generated.
- 10–28 s: turn away into a continuous counter-clockwise descending flight, round the south bend and along the opposite straight, then into the northern pizza terrace.
- 28–35 s: pass the pizza guests, enter the mixed-zone corridor at x=9.15 m, fly beneath the canopy at y=1.95 m and turn beside the podium.
- 35–44 s: settle behind the human rider at the actual race start. Individual and team pursuit use a shorter final path to their halfway-straight start; they never visit the finish first. Their camera also focuses on the opposing rider/team at 19.5–21 s.
- Flight waypoints use time-scaled cubic Hermite interpolation with shared velocities, so the camera does not stop between route sections. Only departure from the welcome and arrival behind the rider ease to zero speed.
- The normal stop gate and 3–2–1 countdown follow. Real-trainer movement or missing data still blocks starting. Race time, rider distances and recording do not advance during INTRO.

Enter, Space or the on-screen button skip to the existing stop gate. R/Escape during the intro return to setup. Names on render layer 2 are hidden through the cinematic/countdown and the original camera mask is restored at race start or reset. Selected race camera mode is preserved.

## Rider names (V)

V cycles Auto (default), all names, and no names. Auto suppresses labels and floating name/energy cards for riders with at least two other riders within 8 metres; a 10-metre release threshold avoids flicker at the boundary. Isolated riders within 40 metres of the camera stay identifiable. The player's duplicate label is hidden in every V mode because the HUD already identifies them. Physical positions are used, so lapped riders in the same bunch count as neighbours. The choice survives race resets for this session. Team pursuit's tactical leader-power cues are separate from rider names and remain available.

`test_rider_name_visibility.gd` checks dense and isolated riders, badge visibility, actual V key handling, key-repeat suppression, reset preference, cinematic override and unchanged race positions.

## Source and rebuild

`broadcast_intro.gd` owns the presentation; `main.gd` owns start state and race simulation. The controller exposes independent `set_speaking(index, bool)` cues. Run the two `assets/source_blender/commentators/build_*_seated.py` scripts in Blender, then `assets/source_blender/build_commentary_box.py`. The booth GLB and the editable booth Blender file are included. The old portrait atlas is not used.

Automatic LOD generation is disabled for this GLB because simplification makes closely spaced scalp/skin surfaces intersect. The current booth uses 14 meshes, 43 surfaces and 321,212 triangles in Godot. The measured Compatibility-renderer flyby at 1664×936 had a 31.785 ms median versus 31.615 ms with the booth hidden; this is local evidence, not a hardware-independent guarantee.

## Verification

`test_broadcast_intro.gd` covers frozen simulation, exact subtitle, speaker cues, continuous positions and velocities in all three route variants, tent corridor clearance, pursuit start without overshoot, chase handoff, countdown/racing, reset/skip and the live-trainer movement gate. `test_commentary_box.gd` covers placement, seat reservation, geometry budgets and independent mouth deformation. Existing race rules, gameplay, points, peloton feedback, pursuit and team-pursuit regressions pass. HUD and team presentation checks pass. Menu tests exercise intro entry before skipping to their existing checks.

An extra power-meter test reports an existing stale expectation: it requires the ERG help text to contain “nog niet beschikbaar”; the current menu uses different text before intro startup. The intro does not change ERG controls. Physical trainer hardware was not exercised.

Use `tests/capture_broadcast_intro.gd` for deterministic phase captures and 720 review frames at 15 fps. Pass `-- pursuit` for the pursuit route or `-- stills` for snapshots only. Review frames/video are local artifacts, not runtime dependencies.
