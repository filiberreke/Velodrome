# Omnium elimination integration

Elimination is the third discipline and starts directly from the omnium card only
after valid Scratch and Tempo results. The thin controller reuses the existing
elimination jury, fixed-timestep motor, AI and shared omnium lifecycle.

## Behavior

- Short format: one elimination per 250 m lap. Both UCI formats: every 500 m.
- Jury crossings, retained future crossings and AI positioning cycles use the
  same configured interval. Two-lap standalone behavior remains the default.
- The final pair retains the existing two-lap finish. Total laps are therefore
  `(participants - 2) * interval_laps + 2`, including the player in participants.
- Saved identities, physical factors and AI strength remain fixed. AI Wprime is
  restored from the valid Tempo snapshot after the neutral-start reset; the
  player starts fresh. No new fatigue model or artificial speed floor is added.
- The virtual omnium HUD uses current active order plus fixed places for riders
  already eliminated. The ordinary eliminated-rider panel is suppressed in
  omnium to avoid overlap. A notice gives the next cut distance or final pair.
- Results include flags, earned and total omnium points, stable-ID elimination
  order and interval metadata. First eliminated ranks last, independent of the
  recorded elimination time or later infield animation position.
- When the player is eliminated, existing CPU completion computes the remaining
  race and commits one complete result plus per-AI finishing Wprime snapshots.
- Aborting an invalid attempt preserves Tempo results/energy and allows retry.
  A valid finish returns to omnium details with points race next.
- Upload title: `Vélodrome - Omnium - Afvalling`.

## Executed tests (Godot 4.6.1 headless)

`test_omnium_elimination_intervals.gd`: both intervals for every field size 8–24,
all cuts down to the final pair, future-crossing retention, default/short AI
urgency and format lap counts.

`test_omnium_elimination_native.gd`: full elimination races through the real
120 Hz motor. Prior Scratch/Tempo results and starting energy are fixture data;
the elimination race itself is simulated from start through the final pair.
All fixtures use mixed rosters and verify Wprime restoration, every elimination,
final order, cumulative omnium points and saved AI energy.

| Participants | Format | Laps | Simulated seconds | Eliminated |
|---:|---|---:|---:|---:|
| 8 | Short | 8 | 199.4 | 6 |
| 8 | Men distances | 14 | 352.7 | 6 |
| 24 | Short | 24 | 607.9 | 22 |
| 24 | Women distances | 46 | 1178.5 | 22 |

`test_omnium_elimination_flow.gd`: actual game/menu initialization, sequence lock,
load from disk, fixed settings/IDs, one-hour recovery (20% remaining becomes 84%),
fresh player, fixed placing for an eliminated AI, HUD visibility, abort/retry,
player first eliminated, real CPU completion of the remaining race, points,
flags, upload title, return navigation, default-interval restoration and reload
of all three valid discipline results.

Existing regressions passed: elimination rules, native core, positioning and
standalone small-field gameplay; omnium core and Scratch adapter; shared result
completion and HUD; Tempo recovery (345 checks) and Tempo menu flow.

No manual visual review, physical-trainer ride or real Strava upload is claimed.
Points-race omnium integration, cross-event AI tactics and the full archive UI
remain later phases; the female 3D model is still outside scope.


## 24-rider result-completion performance regression

The original result worker continued the actual race, but only received a 10 ms
CPU slice per rendered frame. In a 24-rider Elimination race, repeated result
layout and live HUD/3D updates consumed time outside that slice, so the race
could appear to keep running near normal speed. The earlier eight-rider fixture
did not measure this case.

Elimination completion now uses a 40 ms CPU slice and refreshes intermediate
result tables at most five times per second. Final results refresh immediately.
While the worker owns the race, normal live HUD/rider-pose updates are skipped;
bridge input and trainer release still run. Geometry evaluations are memoized
by their exact distance and lane arguments within each physics step. No lookup
quantization, larger simulation timestep, AI shortcut, scoring change or forced
finish is used. The active lane's already computed path metric is also reused.
The pending result shows the accelerated computation status and classified count.

`test_omnium_elimination_completion.gd` reproduces a 24-rider men's-distance race
with the player eliminated in 19th after six cuts. Prior Scratch/Tempo results
and the state at elimination are fixture data; the remaining 16 cuts and final
pair use the real race motor. It checks complete persistence, all 23 AI energy
snapshots, frozen player distance/time, enabled result buttons, reload and return
to the omnium. A second run disables geometry memoization and checks identical
classification, finish times and remaining Wprime. Its time source is fixed so
real test duration cannot change recovered starting energy.

On this headless Godot 4.6.1 environment, the original reproduction took 138.4 s
for about 795 s of remaining race time. The optimized run took 39.8 s (about
20 times race speed). These timings depend on hardware and rendering load;
there is no promise of an instantaneous result or a fixed wall-time limit.
