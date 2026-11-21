# Natural-pace Python elimination research

This folder preserves the tested Python investigation from 9 November 2026.
The playable Godot port is in `game/elimination_ai.gd` and `game/elimination_motion.gd`.
Godot measurements are kept separately in `game/verification/elimination_native`.

The Python model is an approximation, not a replacement for the game's banked-track
physics. Its AI has no minimum-speed demand: wheel tracking, gap closing and
earlier position-taking create the pace, subject to CP, W-prime, Pmax and fatigue.

## Run (Python 3.12, standard library only)

From this folder:

```sh
python source/elimination_v2.py --seed 17 --dt 0.4 --lap-csv round_speeds.csv
python source/validate.py
python source/clock_probes.py
python source/no_override_probe.py
```

`dt` is the caller/frame interval. `--integration-dt` controls the actual physics
step; the default is 0.05 seconds, with decisions at 0.20 seconds. Frame invariance
and actual integration refinement are distinct tests.

`baseline/` contains the previously delivered fix. `source/` also includes the
historical candidate scripts and their frozen source snapshots so those probes
can be reproduced. The historical reports describe the investigation before this
publication; their statement that main was unchanged refers to that research stage.

## Results

- `RAPPORT.txt`: methods, causes, limitations and numerical comparisons.
- `RONDESNELHEDEN.txt`: average speed of every round, including start and final.
- `results/before_after.csv`: 60 paired races (seeds 17-76).
- `results/lap_speed_summary.csv` and `lap_speeds.csv`: round averages and each race.
- `results/frame_sensitivity.csv`: external frame-interval comparisons.
- `results/internal_step_exploration.csv`: actual physics-step refinement.
- `results/tests.json`: assertions, including the tested source SHA-256.

Large per-rider traces and intermediate generated snapshots are not committed.
Running the scripts regenerates the detailed tables and representative traces.
The portable archive's local smoke test is recorded in `results/package_smoke.json`.

On the same 60 races, mean spread fell from 41.94 to 10.34 m. Ordinary cut laps
averaged 40.28 km/h versus 39.61 km/h in intervening laps. These Python numbers
must not be presented as Godot test results. The native port additionally fixes
near-equal track sorting and adapts positional danger to small fields.
