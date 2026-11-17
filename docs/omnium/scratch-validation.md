# Omnium Scratch integration

Scratch now starts directly from the omnium detail card. The adapter supplies the
saved identities, format distance and fixed AI strength to the existing main.gd
scratch motor. Standalone starts retain their existing configuration path.

The adapter restores AI Wprime only after the neutral-start reset and strength
scaling. Individual finishing reserves are frozen by stable rider ID. A single
result transaction is committed only after the complete scratch classification.
A race abandoned before a valid result clears its attempt without advancing the
omnium. The existing deadlines remain in force. Results return to omnium details;
Temporace is the next discipline but its race adapter is not implemented yet.

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

Existing `test_scratch_finish.gd` reports three failing assertions. The identical
three failures were reproduced with the pre-integration main.gd, so this is not
reported as a passing regression test or silently changed in this integration.

Manual checks still needed: real trainer start/neutralization, visual HUD layout,
Strava upload, and process shutdown/crash recovery on the user's target build.
