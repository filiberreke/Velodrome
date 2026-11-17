# Omnium Tempo: integration and specification check

## Implementation

- `omnium_race_controller.gd` owns the shared lifecycle. Scratch and Tempo have
  separate thin controllers; existing race engines, juries and AI are reused.
- Tempo requires exactly one valid prior discipline. It uses mode 8, 20 laps in
  the short format and 40 in either UCI distance format, independent of gender.
- Fixed roster identities/properties and AI strength are supplied from the saved
  tournament. Day-form rerolls are suppressed for omnium.
- AI Wprime is restored after the neutral-start reset, using the last valid
  per-rider snapshot and actual UTC elapsed time. The injected test clock is
  unused in production. Neither repeated restoration nor an aborted attempt
  overwrites the source snapshot. In-race fatigue remains in-race only.
- The player uses the normal fresh-start reset, without carried energy state.
- The live HUD uses previous omnium totals plus provisional placing points from
  the actual tempo jury ranking, including lap gains/losses. The ordinary tempo
  standings panel is suppressed only in omnium; race notices/minimap remain.
- The valid final classification is converted with 40/38/.../2/1 placing points;
  raw tempo points are not directly added to omnium. Raw points and sprint
  orders/times/awards are also archived in the discipline result by stable IDs.
- Result tables now include flags, and Tempo shows earned omnium points and the
  new total. The upload title is `Vélodrome - Omnium - Temporace`.
- Accelerated result completion, existing deadlines and return-to-omnium flow
  are reused. After a completed Tempo the next discipline is elimination.

## Executed validation (Godot 4.6.1, headless)

`test_omnium_tempo_recovery.gd` passes 345 reserve checks: 23 AI riders across
three formats at 0/30/60/120/240 minutes, with initial reserves spanning
0/20/50/80/100 percent. The clock is injected; no four-hour wall-clock wait is
claimed. Assertions cover:

- No recovery at zero elapsed time.
- 55.2786% of the deficit recovered after 30 minutes.
- 80% after one hour, 96% after two hours, full after four hours.
- Actual post-neutral-start AI arrays and capacities at fixed 95% difficulty.
- Mixed rider profiles, reversed local slots, and ID-based matching.
- Equal recovery with the game open versus loading the saved snapshot.
- Repeated application does not compound recovery; aborted Tempo leaves the
  valid Scratch reserve and result intact.
- The player starts fresh and no separate AI fatigue state is carried.

`test_omnium_tempo_native.gd` passes full 20-lap Scratch -> Tempo motor simulations
with 8 and 24 participants, saving/reloading between events and restoring with
one hour of elapsed time. Each Tempo finishes with 16 scoring passages, full
final order, two valid discipline results, correct summed omnium scores and AI
energy snapshots.

`test_omnium_tempo_flow.gd` passes actual menu/game initialization, fixed
format/strength/IDs, Tempo abort/retry, immediate HUD rank changes from a lap gain,
no overlapping standings panel, flags in the result, upload naming and return to
omnium details. Its final classifications are injected; full race physics is
covered separately by the native simulation test.

`test_omnium_tempo_completion.gd` passes accelerated post-player-finish processing,
including full sprint archive, exactly one committed Tempo result and AI Wprime.
Regression checks passed for the omnium core, Scratch adapter/menu flow, settings,
shared HUD, multi-mode CPU completion and standalone Tempo start. Scratch and
Tempo finish tests now pass after correcting their rolling-player-speed fixture;
the same Tempo failures were reproduced before this integration. No production
race physics or rules were altered to make those assertions pass.

Manual visual review, actual trainer and real Strava upload remain untested.

## Issue #30 cross-check and remaining scope

The full issue was reread. The Tempo-specific requirements above are implemented.
The shared manager retains the 14-day inter-event and 28-day total deadlines,
one active tournament, valid-result-only progression and stop/expiry archiving.

The following remain planned work, not claimed complete:

- Elimination and points-race omnium controllers.
- Additional omnium-aware AI decisions/rivalries across disciplines (phase 5).
  Existing Tempo AI is retained in this integration.
- Final points-race tie-break and 10-second event column (points-race phase).
- Full sortable archive matrix/history UI and final balance simulations.

Later user decisions supersede the issue's older wording: 8–24 participants
including the player, settings before roster construction, and the stop button
in the settings panel. These differences are intentional. A female 3D base model
remains outside scope and is not a dependency.
