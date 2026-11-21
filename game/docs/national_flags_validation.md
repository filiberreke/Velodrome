# National flags validation — 2026-11-16

Base: `v0.3`, including `4a3ad4d`. Engine: Godot 4.7.2 stable, Windows,
headless. No trainer connection is required; integration tests use an ephemeral
UDP port and isolated application-data directories.

## Changes

- `assets/flags/`: 25 unchanged original medium PNGs from Countryflags.com,
  imported-resource metadata, per-file provenance/checksums, licence link and
  retrieved licence snapshot. Source images were visually reviewed together.
- `national_flags.gd`: explicit shared texture registry; unknown IDs have no flag.
- `rider_passport.gd`: aspect-preserving PNG rendering in full and compact
  passports. The existing `pursuit_choice_card.gd` uses this same Emblem class,
  so national team opponent selection receives the same correction.
- `arena_flags.gd`, integrated through `arena.gd`: 25 infield-facing flags at
  offset 31.6, beyond the upper seating footprint (ending at offset 29.61).
  Their top edges follow the stadium's banking-dependent rim height at +11.55.
  Rails and paired hangers connect them to the sloping outer canopy. Flag height
  is at most 1.65 m and width at most 3.3 m, preserving each source ratio.
- `tests/test_national_flags.gd`: integration checks and optional GPU capture mode.
- `tools/download_country_flags.py`: reproducible downloads with provenance.

## Results

| Check | Result |
| --- | --- |
| PNG headers, 25 unique images and SHA-256 provenance | PASS |
| All 25 countries in full and compact passports (50 cards) | PASS |
| Actual team-pursuit carousel, all 25 national opponents | PASS |
| 25 stadium textures identical to the menu registry | PASS |
| Infield orientation, positive basis determinant, original aspect ratios | PASS |
| Height follows rim; geometry stays behind seating; flag separation >4 m | PASS |
| Existing `test_arena_roof.gd` | PASS, zero failures |
| Existing `test_pursuit_flow.gd` | PASS, zero assertion failures |
| Existing `test_team_pursuit.gd` | 1 existing failure: result-table width |
| Whitespace check with Windows CRLF accounted for | PASS |

The result-table assertion (`Team result table wraps lap times within available
width`) also fails in the checkout **without the flag changes**. The existing
pursuit-flow test emits dummy-renderer `Parameter "material" is null` messages
while disposing rider previews, both with and without the flag changes; its
assertion count remains zero. These existing issues were left outside this change.

**Visual stadium/menu rendering remains unverified.** The requested GPU Godot
launch was denied. Headless checks verify geometry, integration and UI card
bounds, but cannot establish final rendered occlusion, colour or readability.
No stadium screenshots are claimed as completed validation.

## Re-run

From `game/`, using a Godot 4.7.2 executable:

```powershell
godot --headless --path . --script res://tests/test_national_flags.gd
godot --headless --path . --script res://tests/test_arena_roof.gd
godot --headless --path . --script res://tests/test_pursuit_flow.gd
godot --headless --path . --script res://tests/test_team_pursuit.gd
```

When GPU execution is allowed, the following captures representative full menu
cards, three stadium angles, and a sheet of all 25 rendered Emblems to
`verification/national_flags/` for visual review:

```powershell
godot --path . --resolution 1600x1000 --script res://tests/test_national_flags.gd -- --capture
```
