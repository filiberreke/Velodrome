# Velodrome 250 - Simulator prototype (beta.16.16a)

This is an **offline reference simulator** added alongside the last working beta.16.15.1 project. The gameplay in `main.gd` is deliberately **unchanged**. The Python simulator mirrors the relevant AI power anchors and basic speed law, but simplifies lane-changing, banking and collision logic. **It is NOT the exact same engine as Godot's game loop**. Therefore simulations are useful for balancing hypotheses and regression checks, not proof of in-game results.

## Quick start (Windows with Python 3)
Open a terminal in the extracted Godot project directory:

```bash
python simulator/simulate.py --mode points --laps 25 --riders 8 --races 100 --out simulator/results.csv
python -m unittest discover -s tests -p test_simulator.py -v
```

Options: `--mode scratch|points`, `--laps 15|25|50`, `--riders 6..12`, `--races N`, `--difficulty 80`, `--seed N`. CSV contains all riders, finish times, split times, form variation, points and remaining anaerobic reserve. No KICKR or bridge required.

## Godot race-rule checks
`simulator/race_rules.gd` provides point-race sprint schedule, sub-frame interpolated sprint line crossings, scoring, and finish-placement tie breaks. This module is **prepared for integration**, not currently called from `main.gd`. With a Godot 4.7 executable installed:

```bash
godot --headless --path . --script res://tests/test_race_rules.gd
```

A headless Godot runtime was **not available in the build environment**, so these GDScript tests have not yet been executed. Python unit tests and sample simulator runs were executed successfully.

## Gameplay balancing warning
The reference run with 8 riders, 25 laps and a constant simulated player power of 305 W showed the player winning all 20 sampled runs. The simulation is intentionally simplistic and the AI attacker inherits the game's aggressive fade-to-100 W behavior. This is a **balancing signal, not a verified property of actual gameplay**.

## Next step
Once `race_rules.gd` passes Godot headless tests, migrate race logic from `main.gd` to shared GDScript modules and run the **same code** in both renderer and headless tests. Do that as a separate beta to protect existing functioning Scratch, Strava, animations and display.
