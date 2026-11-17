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
