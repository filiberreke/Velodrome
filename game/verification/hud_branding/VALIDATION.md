# Ivory and course-blue race HUD

Implemented on main b179d570282a476255261b17936de58dc1155cd5.

The race HUD shares the menu palette, italic headings and wordmark. Ivory panels
use 75% opacity. The power meter remains a standalone coloured fill with watts
centered inside; its existing scale, zones and team targets are preserved.
The personal lap counter sits inside the miniature track. Time and the ESC/F10
shortcuts are in the bottom bar; the top settings button only appears in menus.

Race cues use screen coordinates in all camera modes. The new golden bell has
no lettering, rope or long handle, swings for 2.8 seconds on the player's final
lap, fades out and cannot repeat until a new race. Finish/setup clear the cue.
The imagegen prompt and texture import settings accompany the 512px alpha PNG.

## Verification

Godot 4.7.2, Windows. All ten suites passed:

- test_hud_branding.gd (new surface, lap placement, footer, countdown and bell lifecycle checks)
- test_hud.gd
- test_power_meter.gd
- test_solo_time_trial_hud.gd (66 checks)
- test_neutral_start.gd
- test_exit_pause.gd
- test_flying_time_trial.gd (9189 checks)
- test_pursuit_start.gd
- test_team_pursuit.gd
- test_points_notifications.gd

Existing visual assertions were updated for the new palette and screen-space
countdown. The power-meter harness uses an ephemeral UDP port and the current
menu confirmation step/ERG wording, avoiding live hardware and stale UI assumptions.

capture_hud_branding.gd rendered actual 1920x1080 Godot screenshots of standard
racing, stop-pedalling notice, countdown, bell, pursuit and solo time trial. All
six were inspected for appearance, clipping and overlap. Screenshots and logs
remain in the local task workspace rather than adding large captures to the repo.

Final editor import completed. Godot's existing Windows certificate-store warning
remains; first asset import also reported existing model tangent/UV warnings.
No script parse errors or failed assertions remain. Physical trainer hardware
was not exercised; race and trainer calculations were not changed by this work.
