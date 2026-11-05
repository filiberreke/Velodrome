# Team pursuit half-lap sidebar

Built on f25975345490a7ac0d0844ce40daf9a4051f2d6f.

The sidebar uses the existing first-wheel 125 m checkpoint timestamps for both
teams. Each row shows the duration of its own 125 m segment and the cumulative
opponent-minus-own elapsed difference at that checkpoint (+ means ahead).
A pending opponent crossing shows an ellipsis and fills in on its next update.

There are 32 rows with distance labels from 125 m to 4000 m. The list scrolls to
new own crossings and stays above the bottom bar. Full-lap race/result data is
not modified.

Passed: test_team_presentation.gd (3/4 riders, pending/confirmed differences,
segment durations, all 32 rows, sidebar bounds and existing photo checks),
test_team_pursuit.gd, test_team_first_wheel.gd and test_hud.gd.
The actual Godot screenshot 07_team_half_laps.png was inspected for clipping
and overlap. capture_hud_branding.gd reproduces it.
