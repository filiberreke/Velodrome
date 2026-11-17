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


## Omnium detail cards and reopening saved results

The next discipline has a permanent three-pixel blue border, independent of
interaction. All five cards have separate normal/hover/pressed styles and the
shared focus ring. Mouse entry transfers focus, mouse exit releases it. Future
cards still cannot start a race; they retain muted content and explain the order
in a tooltip. Keyboard activation and focus remain available.

Completed discipline cards open a full read-only results page, rather than an
AcceptDialog. All participants, national flags, placing, finish time/time or lap
gap, earned omnium points, and the player's cumulative score at that discipline
are shown. Tempo additionally shows race points. The blue `← Omnium` button
returns to the detail page without replaying a race or changing the valid result.
There is no duplicate continuation button at the bottom of a reopened result. This page uses persisted data and never restores the
live simulation. Race telemetry/export and a finish photograph are not retained
in the omnium result save, so this view does not reconstruct those elements.

New results persist jury lap credits by stable rider ID. Old saves still show
all riders and their saved times, and explicitly state that lap differences were
not saved; the view never guesses lap deficits from elapsed time.

Additional headless checks in `test_omnium_presentation.gd` cover focus transfer
and release on all cards, distinct hover styling, the persistent next-event
border before and after Scratch, a full 24-rider result reopened after disk
reload, winner/time/lap gaps and points, return navigation, and old-save fallback.
`test_omnium_scratch.gd`, `test_omnium_tempo_flow.gd`,
`test_omnium_elimination_flow.gd` and `test_result_navigation.gd` were rerun.


## Live Temporace race points

The omnium Tempo controller adds `race_points` to each live standings row using
stable rider IDs. The HUD keeps signed lap credits and adds a separate `TEMPO`
column before `OMNIUM`, with column headings. Tempo points include sprint awards
and jury lap awards/penalties; they are never substituted for the provisional
omnium points. Zero and negative totals are displayed. The HUD expands from 280
to 324 logical pixels only during Tempo. Scratch and Elimination retain their
existing columns and width.

Godot 4.6.1 headless validation: `test_omnium_tempo_flow.gd` checks points by rider
ID after virtual standings reorder, +1/-1 lap credits alongside 21/-20 race
points, the independent player omnium total of 80, the 324-pixel layout and an
update from 21 to 22 without any rank/lap/omnium-total change. The Scratch
presentation and Elimination flow tests were also rerun.
