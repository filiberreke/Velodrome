# Omnium HUD and Scratch results presentation

The compact live panel is 280 logical pixels wide (previously 378), right aligned
under the minimap. Its fill and border alpha match the ordinary HUD panels
(0.75/0.65). Rows contain displayed place, flag, unique initials, optional signed
lap credits and current virtual omnium points. Zero lap credits remain blank.
Lap credits come from the actual discipline jury; no scoring is changed.

Omnium Scratch results use four columns: place, rider, time/gap, earned omnium
points. The winner's time is m:ss.mmm. Other riders show a time gap if on the same
lap credit, otherwise a signed lap gap. Pending results remain explicitly pending.
The old separate difference column is removed only for Omnium Scratch.

Other supported omnium results also get the shared navigation labels. The primary
button says `Ga verder met omnium`; the blue back button says `← Omnium`. Both
return to the omnium detail page and cannot replay the valid discipline. They are
disabled while the complete result is still being computed/saved. Ordinary race
results retain replay/main-menu actions and their existing time columns.

Validation used Godot 4.6.1 headless:

- `test_omnium_presentation.gd`: real 24-rider game initialization, actual HUD
  minimum width/opacity/column order, positive/negative laps, all result point
  rows (40 through 1), millisecond rounding/carry, time/lap gaps, navigation labels,
  pending-result guards, both button destinations and standalone label recovery.
- `test_omnium_scratch.gd`, `test_omnium_tempo_flow.gd`,
  `test_omnium_elimination_flow.gd`, `test_results_completion.gd` and
  `test_result_navigation.gd` also pass.

No render screenshot or physical-trainer test is claimed for this presentation
change. The user's screenshots provided the visual reference.
