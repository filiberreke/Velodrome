# Strava activity title and description

The export dialog proposes `Velodrome - <discipline>` from the actual race
mode each time it opens. The title remains editable; an empty title falls
back to that race's discipline. A previous race's title cannot carry over.
The dialog previews the description that will be sent with the FIT upload.

- Scratch: `Uitslag: 2/12`, using the official credited-lap classification.
- Points: `Uitslag: 3/16, 12 punten`, including negative scores if applicable.
- Elimination: final placement against the original field, using elimination order.
- Pursuit: placement among the two riders.
- Team pursuit: placement among the two teams, using official team times.
- Solo time trial: own finish time and each completed 250 m lap in seconds
  with three decimal places. Supports both 500 m and 1000 m.

Incomplete classifications say `Uitslag nog niet definitief.` rather than
claiming a final placing. Incomplete time trials include only completed laps.
Title and description are captured together in the dialog and passed through
the existing refresh/OAuth flow to the multipart upload. FIT measurements,
player-only sample selection, VirtualRide type and screenshot handling remain
unchanged.

## Validation (2 November 2026)

Based on main `2700b336f8dc095d1d1a91f801407c2777f2e038`.
Godot 4.7.2: main script parse check passed; `test_strava_metadata.gd`
passed 25 checks, covering official rankings, negative points, teams,
500/1000 m lap descriptions, dialog defaults/preview, empty title fallback,
the FIT upload handoff and actual multipart fields through an offline HTTP
fixture. No real credentials or Strava requests were used.
`test_solo_time_trial_hud.gd` also passed all 66 checks.
A live Strava upload was not performed. The environment's existing root
certificate-store warning is unrelated to these changes.
