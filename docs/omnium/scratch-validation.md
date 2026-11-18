# Omnium Scratch integration

Scratch now starts directly from the omnium detail card. The adapter supplies the
saved identities, format distance and fixed AI strength to the existing main.gd
scratch motor. Standalone starts retain their existing configuration path.

The adapter restores AI Wprime only after the neutral-start reset and strength
scaling. Individual finishing reserves are frozen by stable rider ID. A single
result transaction is committed only after the complete scratch classification.
A race abandoned before a valid result clears its attempt without advancing the
omnium. The existing deadlines remain in force. Results return to omnium details;
Temporace is now integrated through the same lifecycle base; see tempo-validation.md.

The right-hand HUD shows flags, unique initials and provisional omnium totals.
Scratch Strava exports use `Vélodrome - Omnium - Scratch`.

## Validation

Headless tests used Godot 4.6.1. Assets were imported in a temporary project without
Blender source files; repository assets and project engine settings were unchanged.
The user's Godot 4.7 environment and physical trainer were not tested.

Passed:

- `test_omnium_core.gd`: score rules, attempts, persistence, participant limits,
  deadlines and archive idempotency.
- `test_omnium_recovery.gd`: five reserve levels and seven elapsed-time checkpoints.
- `test_omnium_scratch.gd`: adapter contract for 8/12/24 participants, live scores,
  Wprime restoration, per-finisher reserves, complete-only commit, reload and abort.
- `test_omnium_scratch_native.gd`: complete 20-lap scratches through the actual
  main.gd motor with 8/12/24 participants at 30 Hz, with result/energy persistence.
  The runs completed after 516.8, 523.1 and 493.7 simulated seconds respectively.
- `test_omnium_scratch_flow.gd`: actual game/menu initialization, direct start,
  fixed format/strength/IDs, HUD rows, abort, return to details and retry. It also
  injects a final classification to verify the completed-result navigation path.
- `test_omnium_settings.gd`, `test_omnium_catalog.gd`,
  `test_omnium_selection.gd`.
- Existing `test_scratch_large_field.gd` and `test_results_completion.gd`.

The initial validation found three failures in `test_scratch_finish.gd`, also
reproduced before integration. During Tempo integration this was traced to a
fixture setting rider speed to 12 m/s while leaving the separate player baseline
speed at zero. The fixture now initializes both, and Scratch and Tempo finish
regressions pass without changes to race physics or rules.

Manual checks still needed: real trainer start/neutralization, visual HUD layout,
Strava upload, and process shutdown/crash recovery on the user's target build.

## Issue #45: accelerated completion after the player's finish

Verified with `test_omnium_results_completion.gd` under Godot 4.6.1. Fixtures use
real main.gd physics/jury with the player already finished and remaining riders
eight laps down, just beyond a line passage. No additional frame-by-frame
realtime simulation was run by the test; ResultsCompletion drove the remaining race.

| Field | Omnium | Remaining simulated seconds | Wall seconds | Speedup |
|---|---|---:|---:|---:|
| 8 | no | 34.367 | 1.092 | 31.5x |
| 24 | no | 37.000 | 5.212 | 7.1x |
| 24 | yes | 34.883 | 5.278 | 6.6x |

Timing is indicative for this machine, not a performance guarantee. AI behavior
and the finish jury are reused, the player result remains frozen, and repeat
refreshes do not restart the computation. The omnium case also verifies one
committed result containing all 24 riders and 23 AI energy snapshots.

Current trigger: the results overlay must be visible. The normal finish
presentation can therefore run for up to ten seconds before acceleration starts.
Work is bounded to 10 ms CPU batches per frame to keep the UI responsive.

The initial verification covered the existing scratch/points/elimination/keirin
allowlist. Tempo (8) has now been added to the shared accelerator.

`test_results_completion.gd` now passes eight real-motor scenarios: scratch,
points, elimination and tempo with small fields, plus 24-rider points races of
40/80/100 laps and 24-rider tempo over 40 laps. Checks cover automatic triggering,
complete finishing order, unchanged player result and points, complete final
sprint, unchanged sprint calendar, no duplicate restart and cancellation.
The normal results-overlay trigger and frame CPU budget are unchanged.
