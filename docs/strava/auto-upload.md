# Activity archive and automatic Strava uploads (issue #82)

Enable **Automatically upload to Strava** under Settings → Strava. It defaults to
Off and is saved across restarts. Connect or reconnect there to grant
`activity:write` and `activity:read_all`; the latter lets the game verify an
upload whose POST response was lost. Connecting from Settings does not upload
an old temporary FIT file.

Every completed real race, including each omnium discipline, and finished
training session writes an immutable FIT and a separate atomic JSON receipt in
`user://activities`. Training sessions also retain their original JSON history.
A receipt contains the original start time, title, description, GPS metadata,
omnium tournament/attempt/discipline where relevant, upload ID, status and
Strava activity ID. Turning automatic upload off does not disable local saving.
The current v0.4 stadium uses the existing fictional 53N/30W track. Explicit
`location` latitude/longitude metadata is supported and frozen into the FIT;
this change does not introduce additional stadiums or change their coordinates.

The player's finish or elimination ends recording before AI results are
accelerated. Aborted races and simulated rides are never queued automatically.
Stopping an open-ended training session completes and saves that training.
Training checkpoints remain recoverable through the existing training history.

Both active and archived omniums expose FIT export and upload controls for each
saved event, including its full result page. An uploaded event instead shows a
Strava link. Older results without a saved activity reference explicitly show
that FIT export is unavailable; no reconstructed samples are fabricated.

The queue lives outside the race scene. It processes one request at a time,
checks pending uploads every 30 seconds, backs off transient failures and rate
limits, and resumes when automatic upload is enabled. Manual upload also works
when automatic upload is off. Enabling automatic upload includes pending locally
saved activities. Local saving and tournament progress never await the network.

Before POST, the receipt is persisted as `submitting`; an interrupted submission
becomes `uncertain`. The returned upload ID is saved before polling. Known upload
IDs are always polled rather than submitted again. Unknown outcomes are checked
against the athlete's complete activity window using the stable external ID;
there is a ten-minute processing grace period before an identical FIT can be
retried. Failed verification never permits a new POST. Strava's duplicate-FIT
response is resolved to the existing activity ID. Upload receipts remain local
after successful upload, and previously submitted activities are not uploaded
to a different linked account. No automatic success/confirmation window opens.

## Verification

Run from `game` with Godot:

```
godot --headless --path . --script tests/test_activity_uploads.gd
godot --headless --path . --script tests/test_activity_lifecycle.gd
godot --headless --path . --script tests/test_strava_metadata.gd
godot --headless --path . --script tests/test_heart_rate_export.gd
godot --headless --path . --script tests/test_omnium_core.gd
godot --headless --path . --script tests/test_localization.gd
```

The new tests use a fake Strava transport and temporary activity directories.
They cover default-off, persistent settings, local FIT and receipts, immutable
recapture/export, all race and training types, omnium linkage, simulated and
aborted races, elimination cutoff, legacy results, uploaded-result controls,
processing polls, network loss, POST ambiguity, restart/reconnect reconciliation,
duplicate detection, rate limiting, missing read permission and GPS coordinates.
No live athlete activity is created by the tests. A live OAuth/upload check still
requires a configured Strava application and a rider's explicit account consent.

Validation here used Godot 4.5.1 headlessly: all six commands above passed.
The additional existing FTP twenty-minute and workout-library suites report
respectively 14 and 1 failures on both this change and the unchanged v0.4 base
(`13c9523`). The existing omnium presentation suite also has a Dutch-label
assertion against the default English locale. These are separate baseline
issues; they are not counted among the passing checks above.
