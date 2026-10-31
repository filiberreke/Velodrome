# Dynamic Infinity Screen

The existing 14 × 35.28 m ring and 13 m underside are unchanged. Both faces
use one shared 1536 × 512 **2D** SubViewportTexture. The ring's physical UVs
place the broadcast tile at exactly four fixed locations: the centre of each
straight and each curved end. Both faces align at those same world positions.
The spaces between those scoreboards show the existing Velodrome logo, rather
than adjacent copies of the same standings. Inner traversal remains reversed.
No new Camera3D, Light3D, shadow map, video feed or race rule is introduced.
The actual boarding-logo texture is retained in the opening and corner brand.

## Components

- `infinity_race_feed.gd`: read-only adapter to the current game and jury.
- `infinity_scoreboard_model.gd`: five states, event cursors, priority and pages.
- `infinity_scoreboard_canvas.gd`: stadium broadcast graphics, typography and
  bounded 2D chevron, sweep and confetti animations; no second player HUD.
- `infinity_scoreboard.gd`: polling, rendering budget and synchronization cues.
- `infinity_screen.gd`: existing ring construction and shared display binding.

`INTRO` shows the original logo, selected discipline and actual race distance.
`RACE` shows the leader's laps remaining, official top three and breakaway or
sprint information. Pursuit replaces this with teams/riders, latest actual lap
and split times, and the difference at the latest checkpoint completed by both.
`SPRINT` briefly opens within 125 m of a non-final points sprint, then shows
the real jury order and awarded points after the line. `LAP_GAIN` shows the
actual points award and rider(s), then the updated classification. Scratch
correctly displays RONDEWINST without inventing points. `FINISH` preempts all
other moments, marks incomplete results as provisional and updates the winner
as the official classification develops. Confirmed results trigger the victory
animation; after nine seconds, six-second pages expose the complete field.

FINAL LAP is a short `RACE` moment, keeping the five-state contract. Presentation
priority is finish > lap gain > sprint > final lap. Transitions crossfade over
0.45 s. A bounded backlog coalesces simultaneous lap gains. Race reset, mode
switch and restart clear old messages. Event arrays and points are never consumed
or modified. Late sprint entries continue updating visible results.

## Authoritative sources

Scratch classification: `_race_better`, `scratch_rules.events` and peloton state.
Points: `points_rules.events`, `sprints`, `awards`, `points`, `gains`,
`next_sprint_lap()` and its official classification comparator. Laps remaining
use `_race_positions()`, preserving the existing lap-credit convention.
Pursuit uses `lap_times` and `pursuit_half_crossings`; a 250 m checkpoint is
never compared against an opponent's 375 m checkpoint. Team pursuit reads
`team_race.progress`, `times`, `better()` and replay/team names, rather than
individual formation positions. Finish remains provisional until all finish
records (or the points jury's final sprint) are complete.

## Stadium synchronization / future camera input

Connect to `InfinityScreen.stadium_cue(kind, payload)`. The model emits `sprint`,
`sprint_result`, `lap_gain`, `final_lap`, `finish` and `winner_confirmed` once
per occurrence. Lap payloads contain rider IDs and actual awarded points;
sprint payloads identify the jury lap. `finish` includes a provisional flag;
`winner_confirmed` identifies the final winner. Future lighting and crowd
systems can subscribe without polling or duplicating scoring. This phase only
pulses the existing turquoise emissive edge for 1.4 s; it adds no stadium
light show and does not change the existing crowd/wave systems.

The existing `InfinityScreen.set_content(Texture2D)` still accepts a future
camera's SubViewportTexture. Call `screen.scoreboard.suspend_scoreboard()`
before external content; `resume_scoreboard()` restores the broadcast tile.
`screen.set_side_content(Texture2D)` can independently replace the four brand
panels with future footage, retaining the four live scoreboards. It preserves
the incoming texture's aspect ratio. Side panels use the original logo now.
No live 3D camera is implemented in this phase.

## Rendering and checks

Data sampling is capped at 10 Hz. One 2D render target updates at up to 8 Hz
for steady information and up to 30 Hz during short animation/crossfade windows.
The viewport uses UPDATE_ONCE and is disabled between requested frames. The
renderer reuses one canvas, texture and two existing display materials.
No readback occurs during gameplay. Full-size captures are offline test tools.

See `verification/dynamic_screen/VALIDATION.md`, `results.json` and
`benchmark.json`. Reproduce with Godot `--headless --script` for the two new
tests, or run the capture/benchmark scripts with the real Compatibility renderer.
