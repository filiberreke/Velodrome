# Omnium points race and final classification

Implemented against GitHub issue #30 (read 18 November 2026), with subsequent
conversation decisions taking precedence: 8–24 riders including the player,
settings before start list, the settings stop button, mouse-following focus,
exact sprint-time ties resolved using best earlier places, and combined
simultaneous score notices.

## Integration

`omnium_points_controller.gd` is the fourth thin controller. It uses race mode 1,
`points_race_rules.gd`, `points_ai.gd`, and the shared lifecycle, recovery, CPU
completion and persistence. Menu progression is locked until three valid results.
Distances are 40/100/80 laps for short/men/women formats, independent of roster
category. Identities, individual physical factors and difficulty stay fixed.
An aborted attempt leaves the prior results/energy intact and can be restarted.
AI Wprime is restored after neutral start, using real elapsed time. The player
starts fresh. Existing in-race physiology is retained; no new fatigue model or
additional carried state is introduced.

Sprint awards remain 5/3/2/1 every ten laps; the final sprint is 10/6/4/2.
Lap events contribute +20/-20. Net race points are added directly to the earlier
omnium scores, never converted to placing points. The result stores all rider
IDs, net points, gains/losses, jury lap credits, all sprint passages/awards and
the full final-sprint order and times, including riders outside the first four.

`omnium_scoring.gd` ranks equal final totals by final-sprint time. Only exactly
equal known times use sorted best earlier places. Remaining equality shares a
sporting rank. Missing final passage data stays provisional; it does not invent
a tie-break result. The race's own points order and the overall omnium order are
separate; the final UI displays the latter.

## HUD and results

The compact omnium HUD keeps rank, flag, unique initials, signed lap credits and
omnium total. During the points race a reserved column immediately to the right
shows the latest score delta. Its ten-second lifetime uses monotonic wall time,
not accelerated race time. Simultaneous sprint/lap awards for one rider are
combined; a subsequent event replaces the notice and restarts its lifetime.
Zero notices are blank and losses display a negative delta. Awards are consumed
once, independently of standings order.

`omnium_points_presentation.gd` renders the live result and saved result using the
same expandable rows: place, flagged full name, previous omnium score, sprint
points, lap points, net course points, overall total. Clicking a rider reveals
all sprint places and awards, including the doubled final sprint. Existing FIT
and Strava export actions remain available immediately after the race; the
Strava title is `Vélodrome - Omnium - Puntenkoers`.

CPU completion remains automatic for unfinished riders. Navigation is disabled
until a complete result has been committed (or the omnium has expired). Once
complete, the manager archives the tournament atomically. Continuing opens its
final classification directly. A second continuation button is not added to
results reopened from the tournament page.

`omnium_archive.gd` supplies the 'Gereden toernooien' card/list and a sortable
rider-by-discipline matrix. Points-race cells contain raw net points. Completed
omniums initially use the official overall order. Stopped/expired tournaments
show a provisional classification without declaring a final winner and cannot
resume. Each saved discipline can be opened as a full result page. Sorting and
viewing operate on copies. As with earlier saved results, old finish photographs
and trainer export recordings are not reconstructed from omnium JSON.

## Supplemental AI policy

`omnium_tactics.gd` is an opt-in demand policy attached only when the existing AI
is configured for an omnium. It does not replace a discipline AI, award points,
change speeds directly, or bypass the existing power ceiling/Wprime accounting.
A new standalone AI has no attached policy.

In Scratch it conserves modest draft effort before the finale and considers
close overall rivals for late place gains. In Tempo it considers whether another
point can change the discipline place. Elimination conserves only in a safe
front position, away from the next cut; it does not increase demand behind the
collision-safety planner. Existing attack and sprint demands remain intact.

In the points race, attack inclination uses the score deficit, remaining sprint
opportunities, sprint capability and current Wprime. Leaders/direct challengers
can request an existing chase against a real escape whose potential lap/sprint
points threaten their total. Outsiders are evaluated by score potential rather
than rank. A rider merely at the front of the same bunch is not treated as an
escape. Point events trigger immediate policy recalculation; ordinary decisions
refresh twice per simulated second.

These are initial gameplay heuristics. The pilot simulation set below checks
execution, conservation and profile behavior; it is not statistical proof that
tournament tactics are optimally balanced.

## Executed automated validation

Godot 4.6.1 headless:

- `test_omnium_points_rules.gd`: all 17 field sizes from 8 through 24 across all
  three distances (51 combinations); full sprint orders, every sprint award,
  doubled final sprint, lap gain/loss, direct totals, course winner versus overall
  winner, final-time tie-break, best-earlier-place fallback and unresolved ties.
- `test_omnium_points_flow.gd`: actual game/menu for 8 short, 12 women-distance
  and 24 men-distance riders; sequence lock, fixed settings/IDs, abort/retry,
  one-hour Wprime restoration, fresh player, delta combination/replacement/expiry
  using wall time, negative awards, actual CPU final-sprint completion, all four
  saved results, archive/reload, enabled navigation, sortable read-only matrix,
  expandable saved sprint details, Strava title and standalone isolation. Prior
  three disciplines and earlier points-race sprint records are fixture data.
- `test_omnium_tactics.gd`: threat sensitivity to point gaps with unchanged ranks,
  outsider lap potential, suppression of false escapes inside the bunch,
  reserve-sensitive attack inclination, immediate point-event reaction and real
  Wprime debiting under the existing physical limits.
- `test_omnium_points_native.gd`: full points races through the actual Godot
  engine, with previous disciplines supplied as fixture results. Three paired
  seeds compare the same eight-rider field/physical state/AI personality with the
  policy disabled/enabled over 40 laps; additional 12-rider 80-lap and 24-rider
  100-lap races exercise the longer formats. Checks complete sprint calendars,
  points conservation, bounded Wprime, final classification and persisted reload.
  Per-profile attacks, lap gains, points and finishing reserves are recorded in
  `game/verification/omnium_points/validation.json`.

Existing regressions rerun: `test_points_race.gd`,
`test_points_notifications.gd`, `test_results_completion.gd`,
`test_omnium_core.gd`, `test_omnium_scratch.gd`,
`test_omnium_scratch_flow.gd`,
`test_omnium_presentation.gd`, `test_omnium_tempo_flow.gd`,
`test_omnium_elimination_flow.gd`, `test_omnium_tempo_recovery.gd` and
`test_result_navigation.gd`.

No physical-trainer ride, rendered visual review, real Strava upload or full
four-discipline native balance marathon is claimed. The first three disciplines
have regression coverage and receive the supplemental policy, but the repeated
native balance set here isolates the newly integrated points race.


### Pilot balance observations

All eight native runs completed. In the three paired 8-rider fields, total AI
attacks were 3/3/3 without the policy and 2/3/2 with it; AI lap gains were 2/2/0
and 5/3/0 respectively. The overall winner changed in two of the three pairs.
The longer 12- and 24-rider runs produced 3 and 20 AI lap gains, with 8 and 10
complete sprints respectively. Negative totals from repeated lap losses remain
valid and are not capped or hidden. These observations show that the policy can
change outcomes and still permits lap attacks; three pairs are too few for a
strong conclusion about profile, category or leader/challenger balance.
