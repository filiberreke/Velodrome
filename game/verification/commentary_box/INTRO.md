# EuroMaxCycling booth and race introduction

The provisional booth sits at the finish line, at the back of the second spectator tier. Its current presenters are the rounded-head left_v04 and right_v05 designs; the latter wears a photo-inspired white polo with dark green collar and sleeve bands. Small unreadable photo lettering is approximated graphically.

After confirming any implemented race mode, a 36-second presentation runs before the existing standing-start gate:

- 0–4 s: approach the booth.
- 4–10 s: “Welkom bij Velodrome! We maken ons klaar voor de volgende wedstrijd.” appears as subtitles. The two mouth animations run in turn. No spoken audio is generated.
- 10–14 s: leave the stand and move above the track.
- 14–32 s: one complete counter-clockwise lap, descending from 12 to 7 metres.
- 32–36 s: settle behind the human rider.
- The normal stop gate and 3–2–1 countdown follow. Real-trainer movement or missing data still blocks starting. Race time, rider distances and recording do not advance during INTRO.

Enter, Space or the on-screen button skip to the existing stop gate. R/Escape during the intro return to setup. Names on render layer 2 are hidden through the cinematic/countdown and the original camera mask is restored at race start or reset. Selected race camera mode is preserved.

## Rider names (V)

V cycles Auto (default), all names, and no names. Auto suppresses labels and floating name/energy cards for riders with at least two other riders within 8 metres; a 10-metre release threshold avoids flicker at the boundary. Isolated riders within 40 metres of the camera stay identifiable. The player's duplicate label is hidden in Auto because the HUD already identifies them. Physical positions are used, so lapped riders in the same bunch count as neighbours. The choice survives race resets for this session. Team pursuit's tactical leader-power cues are separate from rider names and remain available.

`test_rider_name_visibility.gd` checks dense and isolated riders, badge visibility, actual V key handling, key-repeat suppression, reset preference, cinematic override and unchanged race positions.

## Source and rebuild

`broadcast_intro.gd` owns the presentation; `main.gd` owns start state and race simulation. The controller exposes independent `set_speaking(index, bool)` cues. Run the two `assets/source_blender/commentators/build_*_seated.py` scripts in Blender, then `assets/source_blender/build_commentary_box.py`. The booth GLB and the editable booth Blender file are included. The old portrait atlas is not used.

Automatic LOD generation is disabled for this GLB because simplification makes closely spaced scalp/skin surfaces intersect. The current booth uses 14 meshes, 43 surfaces and 321,212 triangles in Godot. The measured Compatibility-renderer flyby at 1664×936 had a 31.785 ms median versus 31.615 ms with the booth hidden; this is local evidence, not a hardware-independent guarantee.

## Verification

`test_broadcast_intro.gd` covers frozen simulation, exact subtitle, speaker cues, continuous camera joins, one CCW lap with banking clearance, chase handoff, countdown/racing, reset/skip and the live-trainer movement gate. `test_commentary_box.gd` covers placement, seat reservation, geometry budgets and independent mouth deformation. Existing race rules, gameplay, points, peloton feedback, pursuit and team-pursuit regressions pass. HUD and team presentation checks pass. Menu tests exercise intro entry before skipping to their existing checks.

An extra power-meter test reports an existing stale expectation: it requires the ERG help text to contain “nog niet beschikbaar”; the current menu uses different text before intro startup. The intro does not change ERG controls. Physical trainer hardware was not exercised.

Use `tests/capture_broadcast_intro.gd` for deterministic phase captures and 600 review frames at 15 fps. Review frames/video are local artifacts, not runtime dependencies.
