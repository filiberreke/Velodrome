# Native Godot elimination: natural positioning

Port of the Python natural-pace tactic, tested against actual Godot curved-track physics. No minimum-speed controller. Riders protect their position and close a selected wheel using power; urgency starts 50 m before the bell and reaches full strength 200 m before elimination. CP, W-prime, fatigue and physical power limits remain active.

Physics runs at 60 Hz; tactical decisions at 5 Hz. Predictive traffic constraints use the same path metric, banking, draft and speed integration as the real game. Feasible power is limited before energy is spent; a safety speed cap handles insufficient coasting clearance. Continuous lane departures and merges are checked. Physical ordering uses an absolute tolerance: Godot's relative approximate equality previously classified nearby distinct distances as tied, creating a false 250 m wrap gap. Wheel lookup also considers the immediate upstream rider before deciding whether a gap exists. In fields of at most five riders, only the last position triggers danger.

## Paired native races

Identical forms, seeds, inputs and fixtures before/after. Baseline main: `15612b57e1d7118bb80801415d2a805c5ec224e5`. Eight complete races; player supplies 300 W, or requests 650 W at 35–60 seconds then 250 W. Span includes all active riders, including the player; these are native Godot results, separate from the Python study.

| Riders | Seed | Player | Mean span before m | After m | Maximum before m | After m |
|---|---|---|---:|---:|---:|---:|
| 4 | 17 | 300 W | 11.64 | 9.76 | 25.96 | 19.56 |
| 4 | 23 | 300 W | 14.67 | 10.91 | 34.22 | 24.08 |
| 12 | 17 | 300 W | 230.82 | 11.21 | 325.36 | 38.95 |
| 12 | 23 | 300 W | 154.52 | 10.21 | 223.03 | 43.34 |
| 16 | 17 | 300 W | 138.85 | 14.68 | 200.96 | 50.15 |
| 16 | 23 | 300 W | 238.83 | 17.59 | 298.54 | 54.87 |
| 16 | 17 | 650 W attack | 243.06 | 14.04 | 293.75 | 61.27 |
| 16 | 23 | 650 W attack | 66.62 | 16.64 | 217.93 | 65.89 |

Every per-lap speed is exported in `lap_speeds.csv`: time-weighted average physical speed of active riders, plus leader reference speed calculated from interpolated lap boundaries. Even laps end at elimination; odd laps are recovery laps. In the two regular 16-rider races, paired laps 5–28 average 39.30 km/h in recovery and 38.61 km/h before elimination (7/24 pairs faster). This is an observed tendency, not a hard imposed speed alternation; attacks, field size and energy can alter individual laps.

## Headless validation

All ten listed suites and the eight-race measurement completed without script errors/assertions. The real-track safety test checked 91,853 same-corridor pairs, minimum clearance 1.999999999975 m (2 m within floating-point tolerance). Frame intervals 0.1, 0.4 and 0.13 seconds preserve distances, speeds, energy, finish times and elimination order within 1e-6 for both tested seeds. A stationary player is passed in fields of 4, 12 and 16.

Existing elimination rules, gameplay, corrections, peloton quality, shared traffic, scratch gameplay and points-race tests also passed. Scratch gameplay snapshots exactly match baseline. The standing-start gameplay assertion now measures progress from each rider's starting grid distance; the former absolute-distance assertion already failed on unchanged main. Shared scratch/points motion identity checks remain; elimination has its own predictive safety tests. Small-field shelter quality is measured during recovery, because last-place defence intentionally leaves the wheel during positioning.

Run from `game`: `python tests/run_elimination_headless.py --godot /path/to/godot`. Use Godot 4.7.2 or compatible, import the project first on a clean checkout. `tests/measure_elimination_native.gd` reproduces the after measurement. Exact before/after data, comparison, lap speeds and validation hashes are committed here. Large generated logs and import caches are excluded. Known local messages about Windows certificates and cached asset UIDs are recorded in validation.json and were also present before changes.
