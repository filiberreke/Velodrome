# Solo time-trial HUD

Only race mode 7 uses this layout. The left panel shows individual segment
times at each 125 m checkpoint: four rows for 500 m, eight for 1000 m.
Pending checkpoints show a dash. Completed checkpoints show milliseconds.

The selected last ride, recent PR (inclusive 60-day window), or all-time PR
supplies the comparison splits, filtered by distance. Delta is own 125 m segment time
minus the corresponding reference segment time: negative is green, positive is red, zero is neutral.
No reference or missing reference split means no delta. The selected reference
is captured before the ride and does not change when the new result is saved.

The bottom bar contains only elapsed time (mm:ss.t) and estimated total finish
time (mm:ss, no fractional seconds):
elapsed + remaining metres / current speed in metres per second.
Below 1 km/h, or with invalid speed, the estimate is a dash. At the finish,
both clocks use the exact recorded finish time, displayed with one decimal
for elapsed time and whole minutes/seconds for the estimate. Race position, lap count,
leader gap and surrounding riders are hidden in this mode, as is drafting.
Other modes keep their existing layout; switching back restores it.

## Validation — 2 November 2026

Godot 4.7.2 stable on Windows:

| Script | Result |
| --- | --- |
| tests/test_solo_time_trial_hud.gd | 66 checks, 0 failures; exit 0 |
| tests/test_hud.gd | RACE_HUD_OK; exit 0 |
| tests/test_pursuit.gd | PURSUIT_OK; exit 0 |
| tests/test_team_pursuit.gd | TEAM_PURSUIT_OK; exit 0 |
| tests/test_race_rules.gd | 8 checks passed; exit 0 |
| tests/test_points_race.gd | POINTS_RACE_OK; exit 0 |
| tests/test_elimination_rules.gd | Basic tests passed; exit 0 |
| tests/test_menu.gd | 7 existing assertion failures; exit 1 |
| tests/capture_solo_time_trial_hud.gd | OpenGL screenshot generated and visually checked; exit 0 |

The new test covers full simulated 500/1000 m rides, checkpoint/finish
agreement, reference selection and the 60-day boundary, all three reference
labels, individual segment times, signed colours, missing comparisons, low/invalid
speed, finish freezing and restoration of the scratch HUD.

The menu test was also run with main.gd and race_hud.gd restored from the
unchanged branch head 47623947e7cb7066219d1e9ac80f51b5aeffe55e. It has the
same seven failures: assertions treating the implemented time trial as
unsupported (three), plus start-list/start-flow assumptions (four).

The local fresh import could not produce texture caches; existing imported
caches from a local checkout were used for execution and visual inspection.
Godot also reports environment certificate-store errors and existing imported
model UID warnings with path fallback. No live trainer session was tested.

Run tests with a writable, isolated Godot user-data directory to avoid changing
personal ride history. Example: Godot --headless --path game --script
res://tests/test_solo_time_trial_hud.gd. The simulation saves completed rides.
Run the capture script without --headless to write
verification/solo_time_trial/hud.png.

After switching the rows to individual 125 m durations and reducing the bottom
clock precision, test_solo_time_trial_hud.gd was rerun (66 checks, 0 failures,
exit 0), as was test_hud.gd (RACE_HUD_OK, exit 0). Reference deltas now compare
the same individual 125 m segments. Stored cumulative checkpoints are unchanged.
