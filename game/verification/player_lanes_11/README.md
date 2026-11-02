# Eleven selectable player lanes

Based on GitHub `main` commit `ab11e2919a83b6bdf43c7b76492c16f0be4e9ace` (2 November 2026).

The player selects eleven offsets from 1.18 to 7.18 m in 0.60 m increments. The six-metre span, track surface and bank geometry are unchanged. Fresh keyboard presses and paddle gestures select one adjacent lane. A held paddle cannot repeat or reverse without returning to neutral; countdown, menu and finished-race input cannot steer.

Scratch, points, elimination, individual pursuit and solo time trial use this selection. Elimination no longer invokes automatic player lane requests, snaps the player's selection to an assist target, or offers an assist toggle. Existing elimination traffic safety and blockage feedback remain. Team pursuit retains automatic formation: a fresh right press requests an exchange, with no free lane selection.

Six-lane audit:

- `main.gd`: split the original six-abreast starting grid from player selection. Using eleven half-width starting slots would overlap bicycles. Preserve the elimination two-abreast launch.
- HUD: replace the fixed `/6` denominator with the selectable lane count; test `11/11`.
- `team_race.gd` and `team_finish_photo.gd`: replace old lane index 2 with physical 3.58 m, preserving formation and photo geometry.
- Finish camera: replace old lane index 1 with physical 2.38 m.
- Tests: update the six-lane assertion and positional upper bound. Add all-lane traversal, boundaries, input gating, smooth motion, continuous AI targets, intermediate-position drafting and team exchange coverage. Replace gameplay expectations that enabled automatic elimination positioning.
- Safety fixture: two new 0.60 m clicks request the original 2.38 m merge. The first-wheel suite's upload spy also accepts the description argument already passed by current `main`; its obsolete two-argument signature otherwise aborts this regression test before completion.
- AI tactical corridors and passing clearances remain independent physical metre values. AI source, drafting equations and rider animation code are unchanged. Six nearby HUD rows, six national boxes and archived simulator snapshots are unrelated to player selection.

Run a suite with:

```sh
godot --headless --path game --script res://tests/test_player_lanes.gd
```

`validation.json` records the completed Godot 4.7.2 headless suites. Full elimination races cover 4/12/16 starters; scratch covers 6–12 starters and a 60 Hz run; points includes sixteen riders at 60 Hz. No physical trainer or paddle was connected: input tests exercise the game handlers and actual local UDP packets.

The restricted Windows test account emits `Failed to read the root certificate store` on startup. This host TLS message was recorded separately from test failures; script errors, assertion failures, missing resources and other engine errors were treated as failures. Asset imports were prepared with Blender source-file importing disabled for the local run; the committed project settings remain unchanged.
